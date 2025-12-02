//
//  ItemCardCompact.swift
//  CoolTime
//
//  사용 가능한 아이템용 컴팩트 카드
//

import SwiftUI

/// 사용 가능한 아이템을 위한 컴팩트 카드
struct ItemCardCompact: View {
    let item: CooldownItem
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // 이모지
                Text(item.emoji)
                    .font(.system(size: 36))

                // 이름
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                // 예상 비용 (있을 때만)
                if let cost = item.estimatedCost {
                    Text("₩\(cost.formatted())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 사용 버튼
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.caption)
                    Text("사용")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(AppTheme.readyGradient)
                )
            }
            .padding(16)
            .frame(width: 120)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppTheme.cardBackground(for: colorScheme))
                    .shadow(
                        color: AppTheme.shadowColor(for: colorScheme, isActive: true, activeColor: AppTheme.ready),
                        radius: 8,
                        y: 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.ready.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 12) {
        ItemCardCompact(
            item: CooldownItem(
                name: "커피",
                emoji: "☕️",
                cooldownDuration: .hours(6),
                estimatedCost: 5000,
                category: "음료"
            )
        ) {
            print("Tapped")
        }

        ItemCardCompact(
            item: CooldownItem(
                name: "배달음식",
                emoji: "🍕",
                cooldownDuration: .days(3),
                estimatedCost: 25000,
                category: "음식"
            )
        ) {
            print("Tapped")
        }
    }
    .padding()
}
