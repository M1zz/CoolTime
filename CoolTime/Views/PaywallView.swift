//
//  PaywallView.swift
//  CoolTime
//
//  쿨타임 Plus · Pro 를 파는 한 장. 머리말 → 비교표 → 칸 카드(연 구독 · 평생, 주 · 월은 펼쳐서) → 약관.
//
//  **무료로 되는 것을 비교표 맨 위에 먼저 보인다.** 이 화면을 닫고 나서도 앱은 그대로 쓴다.
//  첫 해 할인(App Store 첫 구독 할인)과 "연 구독 N년치" 한 줄은 `LeeoTermPicker` 가 알아서 보인다.
//  스토어에 아직 없는 상품은 불러오지 못하므로 그 단추가 서지 않는다(빈 단추를 누르게 두지 않는다).
//

import SwiftUI
import StoreKit
import LeeoKit

struct PaywallView: View {
    /// 어디서 들어왔는가. 그 칸을 위에 세우고 테두리로 짚는다.
    var highlight: ProTier?

    @State private var purchases = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// 결제 시트를 **이 페이월이 떠 있는 창**에 띄운다.
    @Environment(\.purchase) private var purchaseAction

    /// 칸마다 고른 길. 처음엔 연 구독.
    @State private var terms: [ProTier: LeeoPlanTerm] = [:]
    /// 칸마다 고른 주 · 월 구독. 있으면 `terms` 보다 앞선다.
    @State private var shortPlans: [ProTier: String] = [:]
    @State private var loadingProducts = true
    @State private var redeemingCode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    comparison
                    plansStatus
                    ForEach(cardOrder) { tierCard($0) }
                    if let message = purchases.failureMessage, !purchases.products.isEmpty {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.body)
                            .foregroundStyle(AppTheme.warning)
                    }
                    legal
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Text("요금제", comment: "Paywall: navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("나중에") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await purchases.restore()
                            if purchases.tier > .free { dismiss() }
                        }
                    } label: {
                        Text("구매 복원", comment: "Paywall: restore purchases button")
                    }
                    .disabled(purchases.isWorking)
                }
            }
            // 코드를 넣고 돌아오면 영수증을 다시 읽는다.
            .offerCodeRedemption(isPresented: $redeemingCode) { _ in
                Task {
                    await purchases.refresh()
                    if purchases.tier > .free { dismiss() }
                }
            }
            .task {
                LeeoAnalyticsCenter.track(.paywallShown(reason: highlight.map { "\($0)" } ?? "settings"))
                await loadPlans()
            }
        }
    }

    // MARK: 머리

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("쿨타임 Plus · Pro", comment: "Paywall: title")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Text("참은 만큼 더 잘 보이게. 연 구독이나 평생 중에 고르세요.", comment: "Paywall: subtitle")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 비교표

    private var comparison: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                ForEach(ProTier.allCases) { tier in
                    Text(verbatim: tier.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(tier == highlight ? AppTheme.ready : .primary)
                        .gridColumnAlignment(.center)
                }
            }
            .accessibilityHidden(true)
            Divider()
            ForEach(PlanComparisonRow.all) { row in
                GridRow {
                    Text(row.title)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    cell(row.free)
                    cell(row.plus)
                    cell(row.pro)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.title)
                .accessibilityValue(accessibilityValue(row))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    @ViewBuilder
    private func cell(_ cell: PlanComparisonRow.Cell) -> some View {
        switch cell {
        case .yes:
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.ready)
        case .no:
            Text(verbatim: "–")
                .font(.body)
                .foregroundStyle(.tertiary)
        case .text(let text):
            Text(text)
                .font(.body)
                .monospacedDigit()
        }
    }

    private func accessibilityValue(_ row: PlanComparisonRow) -> String {
        zip(ProTier.allCases, [row.free, row.plus, row.pro]).map { tier, cell in
            let value: String = switch cell {
            case .yes: String(localized: "포함", comment: "Paywall comparison (VoiceOver): the plan includes this")
            case .no: String(localized: "없음", comment: "Paywall comparison (VoiceOver): the plan does not include this")
            case .text(let text): text
            }
            return "\(tier.title) \(value)"
        }.joined(separator: ", ")
    }

    // MARK: 유료 칸

    /// 누른 자리의 칸을 위에. 그 밖에는 Plus → Pro.
    private var cardOrder: [ProTier] {
        highlight == .pro ? [.pro, .plus] : ProTier.paid
    }

    private func tierCard(_ tier: ProTier) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(verbatim: tier.title)
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                if purchases.tier == tier {
                    Text("지금 쓰는 칸", comment: "Paywall: badge on the plan the person already has")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.ready)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.ready.opacity(0.12), in: Capsule())
                }
                Spacer(minLength: 0)
            }
            Text(tier.tagline)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // 이미 이 칸 이상이면 살 것이 없다. 구독을 평생으로 바꾸는 길은 설정에 있다.
            if purchases.tier < tier {
                LeeoTermPicker(term: termBinding(tier), yearly: purchases.product(ProEntitlement.yearlyID(tier)),
                               lifetime: lifetimeProduct(tier))
                shortPlanOptions(tier)
                buyButton(tier)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            shape.fill(Color(.secondarySystemGroupedBackground))
            shape.strokeBorder(highlight == tier && purchases.tier < tier ? AppTheme.ready : .clear, lineWidth: 1.5)
        }
    }

    /// 고른 길. 처음엔 연 구독 — 스토어에 연 구독이 아직 없고 평생만 있으면 평생.
    private func term(_ tier: ProTier) -> LeeoPlanTerm {
        if let chosen = terms[tier] { return chosen }
        let hasYearly = purchases.product(ProEntitlement.yearlyID(tier)) != nil
        return !hasYearly && lifetimeProduct(tier) != nil ? .lifetime : .yearly
    }

    private func termBinding(_ tier: ProTier) -> Binding<LeeoPlanTerm> {
        Binding(get: { term(tier) },
                set: { terms[tier] = $0; shortPlans[tier] = nil })
    }

    /// 칸의 평생. **Plus 평생을 이미 산 사람에게는 Pro 평생 자리에 올리기 상품을 세운다.**
    private func lifetimeProduct(_ tier: ProTier) -> Product? {
        if tier == .plus { return purchases.product(ProEntitlement.plusLifetimeID) }
        return purchases.product(upgradesToPro ? ProEntitlement.upgradeID : ProEntitlement.proLifetimeID)
    }

    private var upgradesToPro: Bool { purchases.ownsLifetime(.plus) }

    /// 주 · 월 구독. 접어 두고, 펼치면 고른다.
    @ViewBuilder
    private func shortPlanOptions(_ tier: ProTier) -> some View {
        let weekly = purchases.product(ProEntitlement.weeklyID(tier))
        let monthly = purchases.product(ProEntitlement.monthlyID(tier))
        if weekly != nil || monthly != nil {
            DisclosureGroup {
                VStack(spacing: 8) {
                    if let monthly {
                        shortPlanRow(tier, monthly, title: String(localized: "월 구독 · \(monthly.displayPrice)",
                                                                  comment: "Paywall: monthly plan option. Argument is the price"))
                    }
                    if let weekly {
                        shortPlanRow(tier, weekly, title: String(localized: "주 구독 · \(weekly.displayPrice)",
                                                                 comment: "Paywall: weekly plan option. Argument is the price"))
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("주 · 월 구독으로 보기", comment: "Paywall: expand weekly and monthly plans")
                    .font(.body)
            }
            .tint(.secondary)
        }
    }

    private func shortPlanRow(_ tier: ProTier, _ product: Product, title: String) -> some View {
        let selected = shortPlans[tier] == product.id
        return Button {
            shortPlans[tier] = selected ? nil : product.id
        } label: {
            HStack {
                Text(title)
                    .font(.body)
                    .monospacedDigit()
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? AppTheme.ready : .secondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// 지금 고른 상품과 단추 글.
    private func choice(_ tier: ProTier) -> (Product?, String) {
        if let id = shortPlans[tier], let product = purchases.product(id) {
            let title = id == ProEntitlement.weeklyID(tier)
                ? String(localized: "주 구독 시작", comment: "Paywall: buy weekly subscription button")
                : String(localized: "월 구독 시작", comment: "Paywall: buy monthly subscription button")
            return (product, title)
        }
        switch term(tier) {
        case .yearly:
            return (purchases.product(ProEntitlement.yearlyID(tier)),
                    String(localized: "연 구독 시작", comment: "Paywall: buy yearly subscription button"))
        case .lifetime:
            let title = tier == .pro && upgradesToPro
                ? String(localized: "Pro 평생으로 올리기", comment: "Paywall: upgrade Plus Lifetime to Pro Lifetime button")
                : String(localized: "평생으로 사기", comment: "Paywall: buy lifetime button")
            return (lifetimeProduct(tier), title)
        }
    }

    private func buyButton(_ tier: ProTier) -> some View {
        let (product, title) = choice(tier)
        return Button {
            guard let product else { return }
            Task {
                await purchases.purchase(product, using: purchaseAction)
                if purchases.tier >= tier { dismiss() }
            }
        } label: {
            Group {
                if purchases.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.body.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.ready)
        .controlSize(.large)
        .disabled(purchases.isWorking || product == nil)
    }

    // MARK: 요금제를 못 불러왔을 때

    @ViewBuilder
    private var plansStatus: some View {
        if purchases.products.isEmpty && loadingProducts {
            HStack(spacing: 10) {
                ProgressView()
                Text("값을 불러오는 중…", comment: "Paywall: loading prices")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } else if purchases.products.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("요금제를 불러오지 못했어요. 인터넷 연결을 확인하고 다시 불러와 주세요.", comment: "Paywall: prices failed to load")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await loadPlans() }
                } label: {
                    Label {
                        Text("다시 불러오기", comment: "Paywall: retry loading prices")
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .font(.body.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// 첫 조회가 비어 오면 한 번 더 청한다. 샌드박스(심사 환경)는 첫 조회가 빈손으로 오는 일이 잦다.
    private func loadPlans() async {
        loadingProducts = true
        await purchases.loadProducts()
        if purchases.products.isEmpty {
            try? await Task.sleep(for: .seconds(1.5))
            await purchases.loadProducts()
        }
        loadingProducts = false
    }

    // MARK: 약관 (구독을 파는 앱의 심사 필수 항목)

    private var legal: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("구독은 기간이 끝나기 24시간 전까지 해지하지 않으면 같은 요금으로 자동 갱신되고, Apple 계정으로 결제됩니다. 연 구독을 처음 시작하면 첫 해는 할인된 값으로 결제되고 그 뒤에는 정가로 갱신됩니다. 해지와 관리는 App Store 계정 설정에서 할 수 있어요. 평생은 구독이 아니라 한 번만 결제합니다.",
                 comment: "Paywall: auto-renewal terms")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                if let terms = CoolTimeSpec.monetization.subscriptionTermsURL {
                    Button { openURL(terms) } label: { Text("이용약관", comment: "Paywall: terms of use link") }
                }
                Button { openURL(CoolTimeSpec.legal.privacyURL) } label: {
                    Text("개인정보 처리방침", comment: "Paywall: privacy policy link")
                }
            }
            .font(.footnote)
            Button {
                redeemingCode = true
            } label: {
                Label {
                    Text("코드 사용", comment: "Paywall: redeem an offer code")
                } icon: {
                    Image(systemName: "ticket")
                }
            }
            .font(.footnote)
            .disabled(purchases.isWorking)
        }
    }
}

// MARK: - 잠긴 자리

/// 잠긴 영역 위 덮개. 아래 내용은 흐리게 미리 보이고, 누르면 그 칸의 페이월이 뜬다.
struct ProLockedOverlay: View {
    let tier: ProTier
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(tier == .pro ? String(localized: "Pro에서 열려요", comment: "Locked area: opens with Pro")
                                  : String(localized: "Plus에서 열려요", comment: "Locked area: opens with Plus"))
            } icon: {
                Image(systemName: "lock.fill")
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(AppTheme.onFill)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(AppTheme.cooldown))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

extension View {
    /// 무료에서는 흐리게 미리 보이고 덮개를 얹는다. 열려 있으면 그대로.
    @ViewBuilder
    func proLocked(_ locked: Bool, tier: ProTier, action: @escaping () -> Void) -> some View {
        if locked {
            self
                .blur(radius: 6)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .overlay { ProLockedOverlay(tier: tier, action: action) }
        } else {
            self
        }
    }
}
