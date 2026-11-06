import Foundation
import LeeoKit

enum CoolTimeSpec: LeeoAppSpec {
    static let appName = "쿨타임"
    static let developerEmail = "leeo@kakao.com"
    static let feedback = LeeoFeedbackConfig(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub", appIdentifier: "com.Ysoup.CoolTime")

    /// 개인정보 처리방침·지원·소개 페이지 (docs/ 를 GitHub Pages 로 서빙).
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/CoolTime/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/CoolTime/support.html")!,
        marketingURL: URL(string: "https://m1zz.github.io/CoolTime/")!
    )

    /// 무료 · Plus · Pro. 칸마다 주 · 월 · 연 구독과 평생 (→ Models/ProPlan.swift, Models/PurchaseManager.swift).
    static let monetization = LeeoMonetization.freemiumSubscription(
        LeeoSubscriptionConfig(
            productIDs: ProEntitlement.productIDs,
            // 자체 약관이 없으므로 애플 표준 사용권 계약(EULA)을 건다. 구독을 파는 앱의 심사 필수 항목이다.
            termsURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!,
            entitlementIDs: ProEntitlement.entitlementIDs,
            gate: LeeoGatePolicy(
                freeLimits: [Gate.items: ProFeature.freeItemLimit],
                // 칸(Plus · Pro)마다 무엇이 열리는지는 `ProFeature.tier` 가 정한다(→ Models/ProPlan.swift).
                proOnly: Set(ProFeature.allCases.filter { $0 != .unlimitedItems }.map(\.rawValue))),
            // 위젯과 함께 쓰는 통. 권한 캐시가 여기 산다.
            cacheSuiteName: WidgetDataStore.appGroupID,
            // 개발자 응원 팁. 아무것도 열지 않는다. ⚠️ productIDs · entitlementIDs 에 넣지 않는다.
            tipJar: LeeoTipJarConfig(productIDs: ProEntitlement.tipProductIDs)))

    /// 게이트 열쇠말.
    enum Gate {
        static let items = "items"
    }

    /// App Store 앱 ID — 리뷰 링크 · 친구에게 소개하기에 쓴다.
    static var appStoreID: String? { "6755988507" }

    /// 익명 사용 통계 → FeedbackHub. 없으면 bootstrap 이 스냅샷·app_open 을 건너뛴다.
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: CoolTimeSpec.self)
}

// MARK: - 팁 (개발자 응원하기)

/// 팁 엔진은 `LeeoStore` 가 쥔다(결제 리스너를 하나로). 응원 부탁은 이미 Pro 를 가진 사람에게만 한다.
@MainActor
enum CoolTimeTip {
    static var tipJar: LeeoTipJar { PurchaseManager.shared.tipJar }
}

/// 팁을 부탁할 만한 순간 — 쿨타임을 **깨지 않고** 기다렸다 쓴 횟수(아이템마다 첫 사용은 기다린 게 아니라 뺀다). 큰 것부터.
enum CoolTimeTipMoments {
    static let kept = [100, 30, 10]

    static func reached(keptCount n: Int) -> [LeeoTipMoment] {
        kept.filter { n >= $0 }.map { threshold in
            LeeoTipMoment(id: "kept.\(threshold)",
                          message: String(localized: "지금까지 쿨타임을 \(n)번 지켜 냈어요",
                                          comment: "Tip ask card: how many times the person waited out a cooldown before using again"))
        }
    }

    static func reachedNow(in items: [CooldownItem]) -> [LeeoTipMoment] {
        reached(keptCount: items.reduce(0) { $0 + max(0, $1.totalUseCount - $1.breakCount - 1) })
    }
}
