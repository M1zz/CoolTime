//
//  CooldownRow.swift
//  CoolTime
//
//  단일 리스트 행 — 사용 가능/기다리는 중을 하나의 행으로 통일.
//  저시력/시각장애인 대응: 큰 글씨, 고대비, 색+심볼+텍스트 3중 표기,
//  상태를 먼저 읽는 단일 접근성 요소.
//

import SwiftUI

struct CooldownRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: CooldownItem

    private var isReady: Bool { !item.isOnCooldown }

    private var style: AppTheme.StatusStyle {
        AppTheme.status(isOnCooldown: item.isOnCooldown,
                        remainingText: item.remainingCooldown.cooldownFormatted)
    }

    /// "N일 N시간 남음" — 단위 자체는 cooldownFormatted가 로컬라이즈
    private var remainingString: String {
        String(format: NSLocalizedString("%@ 남음", comment: ""),
               item.remainingCooldown.cooldownFormatted)
    }

    @ViewBuilder
    private var statusText: some View {
        if isReady {
            Text(style.text)
        } else {
            Text(remainingString)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // 좌측 상태 표시: 이모지 + 진행 표시(기다릴 때만)
            statusIndicator

            // 이름 + 상태 텍스트(심볼 동반)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Label {
                    statusText
                        .font(.headline)
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: style.symbol)
                        .font(.headline)
                }
                .foregroundStyle(style.color)
                .labelStyle(.titleAndIcon)
            }

            Spacer(minLength: 8)

            // 진행 방향을 암시하는 셰브론(탭 가능 힌트) — 색 단독 의존 회피용 보조
            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        // 행 전체를 하나의 접근성 요소로, 상태를 먼저 읽도록 구성
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("두 번 탭하면 했어요로 기록해요")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(style.color.opacity(colorScheme == .dark ? 0.22 : 0.12))
                .frame(width: 56, height: 56)

            // 기다리는 중이면 진행 링(정적), 사용 가능이면 강한 테두리
            Circle()
                .stroke(style.color, lineWidth: isReady ? 3 : 2)
                .frame(width: 56, height: 56)

            if !isReady {
                Circle()
                    .trim(from: 0, to: item.cooldownProgress)
                    .stroke(style.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
            }

            Text(item.emoji)
                .font(.system(size: 26))
        }
        .accessibilityHidden(true)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: Text {
        if isReady {
            // "사용 가능, 커피"
            return Text(style.text) + Text(verbatim: ", ") + Text(verbatim: item.name)
        } else {
            // "기다리는 중, 2일 남음, 커피"
            return Text(style.text)
                + Text(verbatim: ", ")
                + Text(verbatim: remainingString)
                + Text(verbatim: ", ")
                + Text(verbatim: item.name)
        }
    }
}

// MARK: - Preview

#Preview {
    List {
        CooldownRow(item: CooldownItem(name: "커피", emoji: "☕️", cooldownDuration: .days(2)))

        let waiting: CooldownItem = {
            let item = CooldownItem(name: "배달음식", emoji: "🍕", cooldownDuration: .days(3))
            item.lastUsedDate = Date().addingTimeInterval(-86400)
            return item
        }()
        CooldownRow(item: waiting)
    }
    .listStyle(.insetGrouped)
}
