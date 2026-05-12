//
//  UseItemSheet.swift
//  CoolTime
//
//  아이템 사용 시트
//

import SwiftUI

/// 아이템 사용 확인 시트
struct UseItemSheet: View {
    let item: CooldownItem
    @Binding var isPresented: Bool
    let onUse: (String?, Int?) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var note: String = ""
    @State private var actualCost: String = ""
    @State private var showConfirmationAlert = false
    @FocusState private var isNoteFocused: Bool

    private var isOnCooldown: Bool {
        item.isOnCooldown
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 아이템 정보
                    itemHeader

                    // 쿨타임 경고 (쿨타임 중일 때)
                    if isOnCooldown {
                        cooldownWarning
                    }

                    // 메모 입력
                    noteSection

                    // 실제 비용 입력 (예상 비용이 있을 때)
                    if item.estimatedCost != nil {
                        costSection
                    }

                    // 사용 버튼
                    useButton
                }
                .padding()
            }
            .background(AppTheme.pageBackground(for: colorScheme))
            .navigationTitle(isOnCooldown ? "쿨타임 깨기" : "사용하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        isPresented = false
                    }
                }
            }
            .alert("쿨타임 깨기", isPresented: $showConfirmationAlert) {
                Button("취소", role: .cancel) { }
                Button("쿨타임 깨기", role: .destructive) { executeUse() }
            } message: {
                Text("정말 지금 사용하시겠어요?\n쿨타임이 처음부터 다시 시작되고, 준수율에 기록됩니다.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Item Header

    private var itemHeader: some View {
        VStack(spacing: 12) {
            Text(item.emoji)
                .font(.system(size: 60))

            Text(item.name)
                .font(.title2)
                .fontWeight(.bold)

            if isOnCooldown {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                    Text(String(format: NSLocalizedString("남은 시간: %@", comment: ""), item.remainingCooldown.cooldownFormatted))
                }
                .font(.subheadline)
                .foregroundStyle(AppTheme.cooldown)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("사용 가능")
                }
                .font(.subheadline)
                .foregroundStyle(AppTheme.ready)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.cardBackground(for: colorScheme))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isOnCooldown
            ? String(format: NSLocalizedString("%@ %@, 쿨타임 %@ 남음", comment: ""), item.emoji, item.name, item.remainingCooldown.cooldownFormatted)
            : String(format: NSLocalizedString("%@ %@, 사용 가능", comment: ""), item.emoji, item.name))
    }

    // MARK: - Cooldown Warning

    private var cooldownWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text("쿨타임 중입니다!")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("지금 사용하면 준수율이 낮아집니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.warning.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.warning.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("경고: 쿨타임 중입니다. 지금 사용하면 준수율이 낮아집니다")
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("메모 (선택)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            TextField("왜 사용하나요?", text: $note, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.cardBackground(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.borderColor(for: colorScheme), lineWidth: 1)
                )
                .focused($isNoteFocused)
                .lineLimit(3...5)
        }
    }

    // MARK: - Cost Section

    private var costSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("실제 비용 (선택)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                if let estimated = item.estimatedCost {
                    Text(String(format: NSLocalizedString("예상: ₩%@", comment: ""), estimated.formatted()))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack {
                Text("₩")
                    .foregroundStyle(.secondary)

                TextField("0", text: $actualCost)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.cardBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.borderColor(for: colorScheme), lineWidth: 1)
            )
        }
    }

    // MARK: - Use Button

    private var useButton: some View {
        Button(action: {
            if isOnCooldown {
                showConfirmationAlert = true
            } else {
                executeUse()
            }
        }) {
            HStack {
                Image(systemName: isOnCooldown ? "bolt.fill" : "checkmark")
                Text(isOnCooldown ? "쿨타임 깨기" : "사용 완료")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isOnCooldown ? AppTheme.warningGradient : AppTheme.readyGradient)
            )
        }
        .accessibilityLabel(isOnCooldown ? "쿨타임 깨고 사용하기" : "사용 완료")
    }
    
    // MARK: - Execute Use
    
    private func executeUse() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(isOnCooldown ? .warning : .success)
        
        let cost = Int(actualCost)
        onUse(note.isEmpty ? nil : note, cost)
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    UseItemSheet(
        item: CooldownItem(
            name: "커피",
            emoji: "☕️",
            cooldownDuration: .hours(6),
            estimatedCost: 5000,
            category: "음료"
        ),
        isPresented: .constant(true)
    ) { note, cost in
        print("Used with note: \(note ?? "none"), cost: \(cost ?? 0)")
    }
}
