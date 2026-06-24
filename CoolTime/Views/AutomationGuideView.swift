//
//  AutomationGuideView.swift
//  CoolTime
//
//  "배달앱 열 때 자동으로 멈추기" — 단축어 개인용 자동화 설치 가이드.
//  iOS는 자동화를 코드로 못 만들므로, 단계 안내 + 단축어 앱 바로 열기로 채택을 돕는다.
//

import SwiftUI

struct AutomationGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let steps: [(num: String, text: LocalizedStringKey)] = [
        ("1", "아래 ‘단축어 앱 열기’를 눌러요"),
        ("2", "‘자동화’ 탭 → ➕ → ‘개인용 자동화 생성’"),
        ("3", "‘앱’ 선택 → 자주 지르는 앱(배달·쇼핑)을 고르고 ‘열릴 때’"),
        ("4", "‘동작 추가’ → ‘지금 사도 돼?’ 검색해서 추가"),
        ("5", "‘실행 전 확인’ 끄고 → ‘완료’")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(steps, id: \.num) { step in
                            stepRow(step.num, step.text)
                        }
                    }
                    openButton
                    siriNote
                }
                .padding(20)
            }
            .navigationTitle("자동으로 멈추기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.waitingStrong)
                .accessibilityHidden(true)
            Text("지를 때 폰이 먼저 말려줘요")
                .font(.title2).fontWeight(.bold)
            Text("배달·쇼핑 앱을 열 때마다 CoolTime이 먼저\n‘아직이에요’라고 물어보게 만들어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func stepRow(_ num: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(num)
                .font(.headline).fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(AppTheme.waitingStrong))
            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var openButton: some View {
        Button {
            if let url = URL(string: "shortcuts://") {
                openURL(url)
            }
        } label: {
            Label("단축어 앱 열기", systemImage: "arrow.up.forward.app.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.readyStrong))
        }
        .padding(.top, 4)
        .accessibilityHint("단축어 앱이 열려요. 거기서 자동화를 만들어요")
    }

    private var siriNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.fill").foregroundStyle(.secondary)
            Text("또는 Siri에게 “쿨타임 사도 돼?”라고 말해보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AutomationGuideView()
}
