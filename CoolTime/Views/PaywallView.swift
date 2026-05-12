import SwiftUI
import StoreKit

// MARK: - Trigger Context

enum PaywallTrigger {
    case itemLimit, statsHistory, widget, breakFeedback, general

    var emoji: String {
        switch self {
        case .itemLimit: return "📦"
        case .statsHistory: return "📊"
        case .widget: return "🏠"
        case .breakFeedback: return "💪"
        case .general: return "⚡"
        }
    }

    var heading: String {
        switch self {
        case .itemLimit: return "아이템을 더 추가하려면"
        case .statsHistory: return "전체 기록을 확인하려면"
        case .widget: return "위젯을 사용하려면"
        case .breakFeedback: return "더 강력한 의지력이 필요해요"
        case .general: return "자기절제의 다음 단계"
        }
    }

    var subheading: String {
        switch self {
        case .itemLimit: return "무료 플랜은 아이템 3개까지 지원해요.\nPro로 업그레이드해 무제한 추가하세요."
        case .statsHistory: return "7일 이전의 기록과 심층 통계는\nPro에서 확인할 수 있어요."
        case .widget: return "홈·잠금화면 위젯으로 쿨타임을\n언제나 한눈에 확인하세요."
        case .breakFeedback: return "쿨타임을 자주 깨고 있어요.\nPro의 강화된 도구로 습관을 바꿔보세요."
        case .general: return "더 많은 기능으로 진짜 변화를\n만들어보세요."
        }
    }
}

// MARK: - PaywallView

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseManager.self) private var pm
    @State private var isPurchasing = false
    @State private var errorMsg: String?

    let trigger: PaywallTrigger

    private let features: [(icon: String, color: Color, title: String, detail: String)] = [
        ("infinity",           AppTheme.ready,         "무제한 아이템",       "원하는 만큼 쿨타임을 등록하세요"),
        ("chart.xyaxis.line",  AppTheme.cooldown,      "전체 통계 & 이력",   "나의 모든 습관 변화를 추적하세요"),
        ("rectangle.stack.fill", AppTheme.cooldownAccent, "홈·잠금화면 위젯", "언제 어디서든 쿨타임을 확인하세요"),
        ("bell.badge.fill",    AppTheme.warning,       "스마트 알림",        "쿨타임 종료 전 미리 알림을 받으세요"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    heroSection
                    featureSection
                    pricingSection
                    ctaSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color(.tertiaryLabel))
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .alert("오류", isPresented: Binding(
                get: { errorMsg != nil },
                set: { if !$0 { errorMsg = nil } }
            )) {
                Button("확인", role: .cancel) { errorMsg = nil }
            } message: {
                Text(errorMsg ?? "")
            }
            .onChange(of: pm.purchaseError) { _, new in
                if let new { errorMsg = new }
            }
            .onChange(of: pm.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.readyGradient)
                    .frame(width: 96, height: 96)
                    .shadow(color: AppTheme.ready.opacity(0.35), radius: 16, y: 8)

                Text(trigger.emoji)
                    .font(.system(size: 44))
            }
            .padding(.top, 16)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text("CoolTime")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("PRO")
                        .font(.caption)
                        .fontWeight(.heavy)
                        .kerning(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppTheme.readyGradient))
                }

                Text(trigger.heading)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(trigger.subheading)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Features

    private var featureSection: some View {
        VStack(spacing: 10) {
            ForEach(features, id: \.title) { f in
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(f.color.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: f.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(f.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(f.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.ready)
                        .font(.title3)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        Group {
            if pm.isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 32)
            } else {
                lifetimePricingCard
            }
        }
    }

    private var lifetimePricingCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("평생 이용권")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("한 번만 결제")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppTheme.ready))
                }

                Text(pm.product?.displayPrice ?? "$5.99")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.ready)

                Text("개발자를 응원하고 평생 Pro를 누리세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "crown.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.warning)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.ready, lineWidth: 2)
                )
        )
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 14) {
            Button {
                Task { await doPurchase() }
            } label: {
                ZStack {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else if let product = pm.product {
                        Text(verbatim: product.displayPrice + " ") + Text("평생 이용권 구매")
                    } else {
                        Text("$5.99 평생 이용권 구매")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(.white)
                .background(AppTheme.readyGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: AppTheme.ready.opacity(0.35), radius: 10, y: 4)
            }
            .disabled(isPurchasing)

            Button {
                Task { await pm.restore() }
            } label: {
                Text("구매 복원")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("결제는 Apple ID 계정으로 청구되며,\n한 번만 결제하면 평생 이용할 수 있어요.")
                .font(.caption2)
                .foregroundStyle(Color(.tertiaryLabel))
                .multilineTextAlignment(.center)
        }
    }

    private func doPurchase() async {
        isPurchasing = true
        await pm.purchase()
        isPurchasing = false
    }
}

#Preview {
    PaywallView(trigger: .itemLimit)
        .environment(PurchaseManager.shared)
}
