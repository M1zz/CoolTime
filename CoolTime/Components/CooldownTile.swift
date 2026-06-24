//
//  CooldownTile.swift
//  CoolTime
//
//  게임 스킬 쿨타임 아이콘 스타일 타일.
//  - 사용 가능: 밝게 활성화(풀컬러 + 빛나는 테두리)
//  - 사용 직후: 어둡게 비활성화 + 시계 방향 라디얼 와이프로 차오름 + 남은 시간 숫자
//  저시력/시각장애 대응: 큰 글씨, 고대비, 색+심볼+텍스트 3중 표기, 상태 먼저 읽는 단일 요소.
//

import SwiftUI

struct CooldownTile: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: CooldownItem
    var onUse: () -> Void = {}
    var onResist: () -> Void = {}

    private let iconSize: CGFloat = 96
    private let iconCorner: CGFloat = 18

    private var isReady: Bool { !item.isOnCooldown }

    private var style: AppTheme.StatusStyle {
        AppTheme.status(isOnCooldown: item.isOnCooldown,
                        remainingText: item.remainingCooldown.cooldownFormatted)
    }

    /// "N일 N시간 남음" — 접근성/하단 라벨용 (전체 표기)
    private var remainingString: String {
        String(format: NSLocalizedString("%@ 남음", comment: ""),
               item.remainingCooldown.cooldownFormatted)
    }

    var body: some View {
        VStack(spacing: 10) {
            skillIcon
                .accessibilityHidden(true)

            Text(item.name)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            actionButtons
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.cardBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        if isReady {
            pillButton("했어요", systemImage: "checkmark",
                       color: AppTheme.readyStrong, action: onUse)
                .accessibilityLabel("\(item.name) 했어요")
        } else {
            HStack(spacing: 8) {
                pillButton("참았어요", systemImage: "hand.raised.fill",
                           color: AppTheme.readyStrong, action: onResist)
                    .accessibilityLabel("\(item.name) 참았어요")
                pillButton("샀어요", systemImage: "cart.fill",
                           color: AppTheme.danger, action: onUse)
                    .accessibilityLabel("\(item.name) 그냥 샀어요")
            }
        }
    }

    private func pillButton(_ title: LocalizedStringKey, systemImage: String,
                            color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption).fontWeight(.bold)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .foregroundStyle(.white)
                .background(Capsule().fill(color))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Skill Icon

    private var skillIcon: some View {
        ZStack {
            // 어두운 슬롯 배경 (게임 아이콘 느낌)
            RoundedRectangle(cornerRadius: iconCorner)
                .fill(slotBackground)

            // 1) 비활성화 베이스 — 거의 꺼진 상태(대비 강화)
            Text(item.emoji)
                .font(.system(size: 46))
                .saturation(0)
                .opacity(0.14)

            // 2) 활성화 레이어 — 경과한 만큼 시계 방향으로 밝게 차오름
            Text(item.emoji)
                .font(.system(size: 46))
                .clipShape(ActivationWedge(progress: isReady ? 1 : item.cooldownProgress))
                .animation(reduceMotion ? nil : .linear(duration: 1.0), value: item.cooldownProgress)

            // 3) 시계방향 진행 링 — "얼마나 찼는지"를 명확히 (쿨타임 중)
            if !isReady {
                Circle()
                    .trim(from: 0, to: item.cooldownProgress)
                    .stroke(style.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)
                    .animation(reduceMotion ? nil : .linear(duration: 1.0), value: item.cooldownProgress)
            }

            // 남은 시간 — 중앙 아래쪽(이모지 가림 최소화)
            if !isReady {
                Text(item.remainingCooldown.compactCooldownFormatted)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .offset(y: iconSize * 0.22)
            }

            // 테두리
            RoundedRectangle(cornerRadius: iconCorner)
                .stroke(style.color.opacity(isReady ? 1.0 : 0.25),
                        lineWidth: isReady ? 3 : 1.5)
        }
        .frame(width: iconSize, height: iconSize)
        .accessibilityHidden(true)
    }

    private var slotBackground: Color {
        // 어두운 슬레이트 슬롯 — 밝은 이모지가 대비되어 활성/비활성이 명확
        colorScheme == .dark
            ? Color(red: 0.10, green: 0.10, blue: 0.13)
            : Color(red: 0.16, green: 0.17, blue: 0.22)
    }

    @ViewBuilder
    private var statusText: some View {
        // 사용 가능: "사용 가능" / 대기: "아직이에요" — 정확한 남은 시간은 아이콘 숫자 + VoiceOver로 전달
        Text(style.text)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: Text {
        if isReady {
            return Text(style.text) + Text(verbatim: ", ") + Text(verbatim: item.name)
        } else {
            return Text(style.text)
                + Text(verbatim: ", ")
                + Text(verbatim: remainingString)
                + Text(verbatim: ", ")
                + Text(verbatim: item.name)
        }
    }
}

// MARK: - Activation Wedge (시계 방향으로 차오르는 부채꼴)

/// 게임 스킬 쿨타임처럼, 12시 방향에서 시작해 경과한 만큼 시계 방향으로 밝게 차오르는 부채꼴.
/// 이 모양으로 "밝은 이모지"를 잘라내면, 꺼진 상태에서 시계 방향으로 활성화되는 효과가 난다.
/// progress: 0(막 사용함, 아무것도 안 보임) → 1(준비됨, 전체가 보임)
/// Shape로 만들어 progress 변화 시 부드럽게 보간된다.
struct ActivationWedge: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // 모서리까지 덮도록 대각선 절반 반지름
        let radius = (rect.width * rect.width + rect.height * rect.height).squareRoot() / 2 + 2

        var path = Path()
        path.move(to: center)
        // 12시(-90°)에서 시계 방향으로 progress 만큼
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * progress),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            CooldownTile(item: CooldownItem(name: "커피", emoji: "☕️", cooldownDuration: .days(2)))

            CooldownTile(item: {
                let item = CooldownItem(name: "배달음식", emoji: "🍕", cooldownDuration: .days(3))
                item.lastUsedDate = Date().addingTimeInterval(-86400)
                return item
            }())

            CooldownTile(item: {
                let item = CooldownItem(name: "온라인 쇼핑", emoji: "🛍️", cooldownDuration: .hours(6))
                item.lastUsedDate = Date().addingTimeInterval(-3600)
                return item
            }())
        }
        .padding()
    }
}
