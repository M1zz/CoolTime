import SwiftUI

/// 게임 스킬 쿨다운 스타일의 원형 프로그레스
struct CooldownCircle: View {
    let item: CooldownItem
    let size: CGFloat
    var showTime: Bool = true
    var onTap: (() -> Void)?

    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        item.cooldownProgress
    }

    private var isReady: Bool {
        !item.isOnCooldown
    }

    // MARK: - Colors (AppTheme 사용)

    private var circleBackground: Color {
        AppTheme.circleBackground(for: colorScheme)
    }

    private var overlayColor: Color {
        AppTheme.overlayColor(for: colorScheme)
    }

    var body: some View {
        ZStack {
            // 배경 원
            Circle()
                .fill(circleBackground)
                .frame(width: size, height: size)

            // 쿨타임 오버레이 (어두운 부분)
            if !isReady {
                CooldownOverlay(progress: progress, overlayColor: overlayColor)
                    .frame(width: size, height: size)
            }

            // 이모지
            Text(item.emoji)
                .font(.system(size: size * 0.45))
                .opacity(isReady ? 1.0 : 0.6)
                .saturation(isReady ? 1.0 : 0.5)

            // 외곽 링
            Circle()
                .stroke(
                    isReady
                        ? AppTheme.readyGradient
                        : LinearGradient(
                            colors: [
                                colorScheme == .dark ? Color.gray.opacity(0.4) : Color.gray.opacity(0.5),
                                colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    lineWidth: 4
                )
                .frame(width: size - 4, height: size - 4)

            // 쿨타임 진행 링
            if !isReady {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AppTheme.cooldownGradient,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: size - 4, height: size - 4)
                    .rotationEffect(.degrees(-90))
            }

            // 준비됨 글로우 효과
            if isReady {
                Circle()
                    .stroke(AppTheme.ready, lineWidth: 3)
                    .frame(width: size + 6, height: size + 6)
                    .blur(radius: 6)
                    .opacity(isAnimating ? 0.8 : 0.3)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }

            // 남은 시간 텍스트
            if !isReady && showTime {
                VStack {
                    Spacer()
                    Text(item.remainingCooldown.cooldownFormatted)
                        .font(.system(size: size * 0.13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(AppTheme.cooldownGradient)
                        )
                        .offset(y: size * 0.18)
                }
            }
        }
        .frame(width: size, height: size + (showTime && !isReady ? 24 : 0))
        .contentShape(Circle())
        .onTapGesture {
            onTap?()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

/// 쿨타임 오버레이 (시계 방향으로 채워지는 어두운 영역)
struct CooldownOverlay: View {
    let progress: Double
    var overlayColor: Color = Color.black.opacity(0.5)

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2

            Path { path in
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(-90 + 360 * progress),
                    endAngle: .degrees(-90 + 360),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(overlayColor)
        }
        .clipShape(Circle())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
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

        CooldownCircle(item: cooldownItem, size: 100)

        // 사용 가능
        let readyItem = CooldownItem(
            name: "커피",
            emoji: "☕",
            cooldownDuration: .days(2),
            estimatedCost: 6000,
            category: "음식"
        )

        CooldownCircle(item: readyItem, size: 100)
    }
    .padding()
    .background(Color(.systemBackground))
}
