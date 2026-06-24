//
//  AutomationGuideView.swift
//  CoolTime
//
//  "지를 때 자동으로 멈추기" 설정 가이드.
//  iOS는 "앱 열 때" 자동화를 코드로 생성/딥링크하지 못하므로,
//  ① 설정 0인 Siri 경로를 앞세우고 ② 자동화 경로의 마찰(동작 검색 등)을 최대한 줄인다.
//

import SwiftUI
import UIKit

struct AutomationGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var copied = false

    private let actionName = "지금 사도 돼?"
    /// 개발자가 iCloud 공유 단축어 링크를 넣으면 '원탭 추가' 버튼이 켜진다.
    /// (단축어 앱에서 만든 단축어 → 공유 → iCloud 링크 복사 → 여기 붙여넣기)
    private let sharedShortcutURL: String? = nil

    private let steps: [LocalizedStringKey] = [
        "‘자동화’ 탭 → ➕ → ‘개인용 자동화 생성’",
        "‘앱’ 선택 → 자주 지르는 앱(배달·쇼핑) 고르고 ‘열릴 때’",
        "‘동작 추가’ → 검색창에 붙여넣기(아래 복사) → 추가",
        "‘실행 전 확인’ 끄고 → ‘완료’"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    siriCard          // 가장 쉬운 길
                    automationCard    // 자동 개입(1분 설정)
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.waitingStrong)
                .accessibilityHidden(true)
            Text("지를 때 폰이 먼저 말려줘요")
                .font(.title2).fontWeight(.bold)
            Text("충동이 올라올 때 CoolTime이 먼저 ‘아직이에요’라고 물어봐요.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Siri (설정 0)

    private var siriCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("가장 쉬운 방법 · 설정 필요 없음", systemImage: "bolt.fill")
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(AppTheme.readyStrong)
            Text("Siri에게 이렇게 말해보세요:")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("“쿨타임 사도 돼?”")
                .font(.title3).fontWeight(.bold)
            Text("지금 바로 됩니다. Spotlight 검색창에 ‘사도 돼’를 쳐도 떠요.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.readyStrong.opacity(0.10)))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Automation (1분 설정)

    private var automationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("앱 열 때 자동으로 · 1분 설정", systemImage: "wand.and.stars")
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(AppTheme.waitingStrong)

            // 동작 이름 복사 (검색 마찰 제거)
            Button {
                UIPasteboard.general.string = actionName
                withAnimation { copied = true }
            } label: {
                HStack {
                    Text("‘\(actionName)’")
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Label(copied ? "복사됨" : "복사", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(copied ? AppTheme.readyStrong : AppTheme.waitingStrong)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemBackground)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copied ? "동작 이름 복사됨" : "동작 이름 ‘\(actionName)’ 복사")

            // 단계
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, text in
                    stepRow("\(idx + 1)", text)
                }
            }

            // 단축어 앱 열기 (+ iCloud 원탭이 있으면 우선)
            if let link = sharedShortcutURL, let url = URL(string: link) {
                primaryButton("원탭으로 추가하기", systemImage: "square.and.arrow.down.fill") {
                    openURL(url)
                }
            }
            primaryButton("단축어 앱 열기", systemImage: "arrow.up.forward.app.fill") {
                if let url = URL(string: "shortcuts://") { openURL(url) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func stepRow(_ num: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(num)
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(AppTheme.waitingStrong))
            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func primaryButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.readyStrong))
        }
    }
}

#Preview {
    AutomationGuideView()
}
