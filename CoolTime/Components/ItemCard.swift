import SwiftUI

/// 아이템 카드 컴포넌트
struct ItemCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let item: CooldownItem
    var onUse: (() -> Void)?
    var onBreak: (() -> Void)?

    private var isReady: Bool {
        !item.isOnCooldown
    }

    // MARK: - Colors (AppTheme 사용)

    var body: some View {
        HStack(spacing: 16) {
            // 쿨타임 서클
            CooldownCircle(item: item, size: 64, showTime: false)

            // 정보
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                if isReady {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("사용 가능")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(AppTheme.ready)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text(item.remainingCooldown.cooldownFormatted)
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(AppTheme.cooldown)
                }

                if let cost = item.estimatedCost {
                    Text("₩\(cost.formatted())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // 액션 버튼
            if isReady {
                Button(action: { onUse?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                        Text("사용")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(AppTheme.readyGradient)
                    )
                }
            } else {
                Button(action: { onBreak?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                        Text("깨기")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(AppTheme.warningGradient)
                    )
                }
            }
        }
        .padding(16)
        .appCardStyle(colorScheme: colorScheme, isActive: isReady, activeColor: AppTheme.ready)
    }
}


// MARK: - Preview

#Preview("Item Cards") {
    VStack(spacing: 16) {
        // 사용 가능
        ItemCard(
            item: CooldownItem(
                name: "커피",
                emoji: "☕",
                cooldownDuration: .days(2),
                estimatedCost: 6000,
                category: "음식"
            )
        )

        // 쿨타임 중
        let cooldownItem = {
            let item = CooldownItem(
                name: "해외여행",
                emoji: "✈️",
                cooldownDuration: .days(60),
                estimatedCost: 1500000,
                category: "여행"
            )
            item.lastUsedDate = Date().addingTimeInterval(-86400 * 30)
            return item
        }()

        ItemCard(item: cooldownItem)
    }
    .padding()
}
