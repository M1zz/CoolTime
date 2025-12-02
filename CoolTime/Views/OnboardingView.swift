//
//  OnboardingView.swift
//  CoolTime
//
//  첫 실행 시 온보딩 화면
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            emoji: "⏰",
            title: "쿨타임으로\n충동을 관리하세요",
            description: "게임의 스킬 쿨타임처럼\n소비와 행동에 대기 시간을 설정해요",
            color: AppTheme.cooldown
        ),
        OnboardingPage(
            emoji: "💰",
            title: "절약 금액을\n확인하세요",
            description: "쿨타임을 지킬 때마다\n얼마나 절약했는지 알려드려요",
            color: AppTheme.ready
        ),
        OnboardingPage(
            emoji: "📊",
            title: "나만의 통계로\n습관을 분석하세요",
            description: "준수율과 카테고리별 통계로\n더 나은 습관을 만들어가요",
            color: AppTheme.cooldownAccent
        ),
        OnboardingPage(
            emoji: "🔔",
            title: "알림으로\n놓치지 마세요",
            description: "쿨타임이 끝나면 알려드릴게요\n위젯으로도 확인할 수 있어요",
            color: AppTheme.warning
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 페이지 인디케이터
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? pages[currentPage].color : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentPage ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }
            .padding(.top, 20)

            // 페이지 컨텐츠
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // 버튼
            VStack(spacing: 12) {
                if currentPage == pages.count - 1 {
                    Button(action: completeOnboarding) {
                        Text("시작하기")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .appGradientButtonStyle()
                    }
                } else {
                    Button(action: nextPage) {
                        Text("다음")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .appButtonStyle(color: pages[currentPage].color)
                    }
                }

                if currentPage < pages.count - 1 {
                    Button(action: completeOnboarding) {
                        Text("건너뛰기")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }

    private func nextPage() {
        withAnimation {
            currentPage = min(currentPage + 1, pages.count - 1)
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        isPresented = false
    }
}

struct OnboardingPage {
    let emoji: String
    let title: String
    let description: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 이모지
            Text(page.emoji)
                .font(.system(size: 100))

            // 제목
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // 설명
            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(isPresented: .constant(true))
}
