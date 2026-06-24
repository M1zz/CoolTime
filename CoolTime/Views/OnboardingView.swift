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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            emoji: "💸",
            title: "또 지르고\n후회했나요?",
            description: "배달·쇼핑·구독에 ‘쿨타임’을 걸어\n충동을 한 박자 멈춰요",
            color: AppTheme.waitingStrong
        ),
        OnboardingPage(
            emoji: "✋",
            title: "지를 땐\n‘아직이에요’",
            description: "참았으면 ‘참았어요’, 샀으면 ‘샀어요’.\n참은 만큼 아낀 돈이 쌓여요",
            color: AppTheme.readyStrong
        ),
        OnboardingPage(
            emoji: "📲",
            title: "지를 때\n폰이 먼저 말려줘요",
            description: "배달·쇼핑 앱을 열면 CoolTime이 먼저\n‘아직이에요’라고 물어보게 할 수 있어요",
            color: AppTheme.waitingStrong
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 페이지 인디케이터
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? pages[currentPage].color : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                        .scaleEffect(reduceMotion ? 1.0 : (index == currentPage ? 1.2 : 1.0))
                        .animation(reduceMotion ? nil : .spring(response: 0.3), value: currentPage)
                }
            }
            .padding(.top, 20)
            .accessibilityElement()
            .accessibilityLabel("\(pages.count)페이지 중 \(currentPage + 1)페이지")

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
        // 온보딩 직후 자동화 가이드를 한 번 노출 (채택률)
        UserDefaults.standard.set(true, forKey: "pendingAutomationGuide")
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
