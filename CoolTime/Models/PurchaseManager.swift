//
//  PurchaseManager.swift
//  CoolTime
//
//  쿨타임 Plus · Pro 를 파는 자리. **속은 전부 `LeeoStore` 다.**
//  여기서 하는 일은 LeeoKit 의 값을 SwiftUI `@Observable` 로 옮기고, 그것을 칸(`ProTier`)으로 읽는 것뿐이다.
//  상품 로드 · 구매 · 복원 · 거래 리스너(다른 기기, 가족 공유, 환불, 구독 만료)는 LeeoStore 안에 있다.
//

import Foundation
import Combine
import StoreKit
import SwiftUI
import WidgetKit
import LeeoKit

@MainActor
@Observable
final class PurchaseManager {

    static let shared = PurchaseManager()

    @ObservationIgnored let store: LeeoStore

    /// 언제나 평생 패스. **팔지는 않는다**(포트폴리오 전체에서 판매를 멈췄다). 이미 산 사람은 Pro 로 연다.
    @ObservationIgnored let foreverPass = LeeoForeverPass(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub")

    /// 팁(응원). 권한과 상관없다. 결제 리스너를 스토어와 하나로 두려고 스토어가 쥔 것을 꺼내 쓴다.
    var tipJar: LeeoTipJar { store.tipJar! }

    /// 지금 쓰는 칸. 화면은 이 값(과 `allows`)만 본다.
    private(set) var tier: ProTier = .free

    /// 이번 실행에서 영수증을 실제로 읽었는가. 읽기 전에는 위젯에 칸을 적지 않는다(산 사람이 잠기지 않게).
    @ObservationIgnored private var entitlementsChecked = false

    /// 팔기 시작했는가. 아니면 아무것도 막지 않는다 (→ WidgetDataStore.isSelling).
    private(set) var isSelling = WidgetDataStore.isSelling

    private(set) var products: [Product] = []
    private(set) var ownedProductIDs: Set<String> = []
    /// 지금 살아 있는 구독. 있으면 설정에 '평생으로 바꾸기' 가 선다.
    private(set) var subscription: LeeoGraduation.Subscription?
    private(set) var isWorking = false
    /// 사다가 막혔을 때 화면에 그대로 보일 말.
    private(set) var failureMessage: String?

    @ObservationIgnored private var observations: [AnyCancellable] = []

    private init() {
        guard let config = CoolTimeSpec.paywall else {
            preconditionFailure("계약에 페이월이 없다. CoolTimeSpec.monetization 을 확인할 것")
        }
        store = LeeoStore(config: config, grandfather: {
            // 페이월 전 빌드를 받은 사람은 Pro. 실제 App Store 결제만 믿는다 — 샌드박스(TestFlight · 심사)의
            // originalAppVersion 은 늘 "1.0" 이라, 믿으면 모두가 Pro 가 되어 페이월을 시험할 수 없다.
            guard let result = try? await AppTransaction.shared, case .verified(let app) = result,
                  app.environment == .production else { return false }
            return ProEntitlement.isBeforePaywall(originalAppVersion: app.originalAppVersion)
        })
        // objectWillChange 는 바뀌기 **직전**에 온다. 다음 차례로 미뤄 새 값을 읽는다.
        observations = [store.objectWillChange.eraseToAnyPublisher(),
                        foreverPass.objectWillChange.eraseToAnyPublisher()].map {
            $0.sink { [weak self] _ in Task { @MainActor in self?.pull() } }
        }
        tier = ProEntitlement.tier(owning: store.purchasedProductIDs, grandfathered: store.isGrandfathered,
                                   foreverPass: foreverPass.isActive)
    }

    func allows(_ feature: ProFeature) -> Bool { !isSelling || tier >= feature.tier }

    /// 무료 한도 안에서 하나 더 걸 수 있는가.
    func canAddItem(currentCount: Int) -> Bool {
        allows(.unlimitedItems) || currentCount < ProFeature.freeItemLimit
    }

    func ownsLifetime(_ tier: ProTier) -> Bool { ProEntitlement.ownsLifetime(tier, in: ownedProductIDs) }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    // MARK: - 상태 맞추기

    /// 영수증을 다시 읽어 칸을 정한다. 앱이 켜질 때와 활성화될 때마다 부른다.
    func refresh() async {
        await store.refreshEntitlements()
        await foreverPass.refresh()
        await store.loadProducts()
        entitlementsChecked = true
        subscription = await LeeoGraduation.currentSubscription(among: ProEntitlement.subscriptionIDs)
        pull()
    }

    func loadProducts() async {
        await store.loadProducts()
        pull()
    }

    /// 구독 졸업을 제안할 때인가. 6개월째와 갱신 7일 전에 한 번씩. 띄운 쪽이 `markGraduationOffered()` 를 부른다.
    var graduationIsDue: Bool {
        guard let subscription, product(ProEntitlement.graduateID) != nil else { return false }
        return LeeoGraduation.isDue(subscription, lastOffered: LeeoGraduation.lastOffered())
    }

    func markGraduationOffered() { LeeoGraduation.markOffered() }

    // MARK: - 사기 / 되찾기

    /// ⚠️ `action` 은 화면의 `@Environment(\.purchase)` 다. 아이패드에서 결제 시트가 엉뚱한 창에 뜨지 않게.
    func purchase(_ product: Product, using action: PurchaseAction) async {
        _ = await store.purchase(product) { try await action($0) }
        entitlementsChecked = true
        subscription = await LeeoGraduation.currentSubscription(among: ProEntitlement.subscriptionIDs)
        pull()
    }

    /// 구독 졸업 평생을 산 뒤.
    func didGraduate() async {
        await store.refreshEntitlements()
        entitlementsChecked = true
        subscription = await LeeoGraduation.currentSubscription(among: ProEntitlement.subscriptionIDs)
        pull()
    }

    func restore() async {
        await store.restore()
        await foreverPass.refresh()
        entitlementsChecked = true
        pull()
        if tier == .free, failureMessage == nil {
            failureMessage = String(localized: "이 Apple 계정에서 구매한 기록을 찾지 못했어요.", comment: "Paywall: restore found nothing")
        }
    }

    // MARK: -

    private func pull() {
        let before = tier
        tier = ProEntitlement.tier(owning: store.purchasedProductIDs, grandfathered: store.isGrandfathered,
                                   foreverPass: foreverPass.isActive)
        products = store.products
        ownedProductIDs = store.purchasedProductIDs
        isWorking = store.purchasingProductID != nil || store.isRestoring
        failureMessage = store.lastError
        if !isSelling, products.contains(where: { ProEntitlement.productIDs.contains($0.id) }) {
            WidgetDataStore.markSelling()
            isSelling = true
            #if !os(visionOS)   // visionOS 2 에는 위젯이 없다 — 위젯 확장은 iOS 에만 묶여 있다
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }

        // 위젯은 App Group 의 그 한 줄만 읽는다. 영수증을 읽은 뒤에만 적고, 칸이 바뀐 판에만 다시 그린다.
        if entitlementsChecked {
            WidgetDataStore.saveTier(tier.rawValue)
            #if !os(visionOS)   // visionOS 2 에는 위젯이 없다 — 위젯 확장은 iOS 에만 묶여 있다
            if before != tier { WidgetCenter.shared.reloadAllTimelines() }
            #endif
        }
    }
}
