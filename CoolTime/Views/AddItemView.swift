import SwiftUI

/// 쿨타임 추가 화면 — 인지 부담 최소화.
/// 필수는 "이름"과 "주기"뿐. 아이콘/비용은 접어둔 선택 항목.
struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseManager.self) private var purchaseManager
    var manager: CooldownManager

    /// nil이면 추가, 값이 있으면 그 항목을 수정
    var editingItem: CooldownItem? = nil

    @State private var didLoad = false
    @State private var showingPaywall = false
    @State private var showingTemplates = false

    private var isEditing: Bool { editingItem != nil }

    @State private var name = ""
    @State private var emoji = "⭐"
    @State private var estimatedCost = ""

    // 쿨타임 주기 (초). 프리셋 또는 직접 설정으로 채움.
    @State private var cooldownDuration: TimeInterval = .days(3)
    @State private var showCustom = false
    @State private var showMore = false

    // 직접 설정용
    @State private var customValue = 3
    @State private var customUnit: CooldownUnit = .days

    enum CooldownUnit: String, CaseIterable, Identifiable {
        case hours = "시간"
        case days = "일"
        case weeks = "주"
        case months = "개월"
        var id: String { rawValue }

        func toSeconds(_ value: Int) -> TimeInterval {
            switch self {
            case .hours:  return TimeInterval(value) * 3600
            case .days:   return TimeInterval(value) * 86400
            case .weeks:  return TimeInterval(value) * 7 * 86400
            case .months: return TimeInterval(value) * 30 * 86400
            }
        }
    }

    private struct Preset: Identifiable {
        let id = UUID()
        let label: LocalizedStringKey
        let duration: TimeInterval
    }

    private let presets: [Preset] = [
        Preset(label: "1일", duration: .days(1)),
        Preset(label: "3일", duration: .days(3)),
        Preset(label: "1주", duration: .weeks(1)),
        Preset(label: "2주", duration: .weeks(2)),
        Preset(label: "1달", duration: .months(1))
    ]

    private let popularEmojis = ["⭐", "☕️", "🍔", "🛍️", "✈️", "🎮", "🍺", "🚕", "💳", "📱", "🍕", "💆"]

    var body: some View {
        NavigationStack {
            Form {
                // 추천에서 고르기 (추가할 때만)
                if !isEditing {
                    Section {
                        Button { showingTemplates = true } label: {
                            Label("추천에서 고르기", systemImage: "sparkles")
                                .font(.headline)
                        }
                        .accessibilityHint("자주 쓰는 쿨타임을 목록에서 바로 추가해요")
                    }
                }

                // 이름
                Section("이름") {
                    TextField("예: 배달음식, 커피", text: $name)
                        .font(.body)
                        .accessibilityLabel("이름")
                }

                // 쿨타임 주기
                Section {
                    presetGrid

                    Toggle("직접 설정", isOn: $showCustom.animation())
                        .font(.headline)

                    if showCustom {
                        Stepper(value: $customValue, in: 1...60) {
                            Text("\(customValue) \(customUnit.rawValue)")
                                .font(.body)
                        }
                        .onChange(of: customValue) { applyCustom() }
                        .accessibilityLabel("주기 값 \(customValue) \(customUnit.rawValue)")

                        Picker("단위", selection: $customUnit) {
                            ForEach(CooldownUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: customUnit) { applyCustom() }
                    }
                } header: {
                    Text("얼마나 참을까요?")
                } footer: {
                    Text("선택한 주기: \(cooldownDuration.cooldownFormatted)")
                        .font(.subheadline)
                }

                // 더보기 (선택): 아이콘 + 예상 비용
                Section {
                    Toggle("아이콘·비용 추가", isOn: $showMore.animation())
                        .font(.headline)

                    if showMore {
                        emojiPicker

                        HStack {
                            Text("예상 비용")
                            Spacer()
                            Text("₩")
                                .foregroundStyle(.secondary)
                            TextField("0", text: $estimatedCost)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 120)
                                .accessibilityLabel("예상 비용, 원")
                        }
                    }
                } footer: {
                    if showMore {
                        Text("비용을 적으면 아낀 돈을 기록에서 보여드려요")
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle(isEditing ? "쿨타임 수정" : "쿨타임 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "저장" : "추가") { handleSave() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.bold)
                }
            }
            .onAppear(perform: prefillIfEditing)
            .sheet(isPresented: $showingTemplates) {
                TemplatesView(manager: manager).environment(purchaseManager)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(trigger: .itemLimit).environment(purchaseManager)
            }
        }
    }

    // MARK: - Preset Grid

    private var presetGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
            ForEach(presets) { preset in
                let selected = !showCustom && cooldownDuration == preset.duration
                Button {
                    withAnimation {
                        showCustom = false
                        cooldownDuration = preset.duration
                    }
                } label: {
                    Text(preset.label)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(selected ? .white : .primary)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selected ? AppTheme.waitingStrong : Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? AppTheme.waitingStrong : Color(.separator), lineWidth: selected ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Emoji Picker

    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("아이콘")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                ForEach(popularEmojis, id: \.self) { e in
                    Button { emoji = e } label: {
                        Text(e)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(emoji == e ? AppTheme.readyStrong.opacity(0.2) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(emoji == e ? AppTheme.readyStrong : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("아이콘 \(e)")
                    .accessibilityAddTraits(emoji == e ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func applyCustom() {
        cooldownDuration = customUnit.toSeconds(customValue)
    }

    /// 수정 모드면 기존 값으로 폼을 채운다 (한 번만)
    private func prefillIfEditing() {
        guard !didLoad else { return }
        didLoad = true
        guard let item = editingItem else { return }
        name = item.name
        emoji = item.emoji
        estimatedCost = item.estimatedCost.map(String.init) ?? ""
        cooldownDuration = item.cooldownDuration
        showMore = item.estimatedCost != nil || item.emoji != "⭐"

        // 주기가 프리셋과 다르면 '직접 설정'으로 펼치고 값/단위를 역산
        if !presets.contains(where: { $0.duration == item.cooldownDuration }) {
            showCustom = true
            let (value, unit) = decompose(item.cooldownDuration)
            customValue = value
            customUnit = unit
        }
    }

    /// 초 → (값, 단위) 가장 큰 딱 떨어지는 단위로
    private func decompose(_ seconds: TimeInterval) -> (Int, CooldownUnit) {
        let s = Int(seconds)
        if s % (30 * 86400) == 0 { return (max(1, s / (30 * 86400)), .months) }
        if s % (7 * 86400) == 0 { return (max(1, s / (7 * 86400)), .weeks) }
        if s % 86400 == 0 { return (max(1, s / 86400), .days) }
        return (max(1, s / 3600), .hours)
    }

    private func handleSave() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)

        if let item = editingItem {
            // 수정
            item.name = trimmed
            item.emoji = emoji
            item.cooldownDuration = cooldownDuration
            item.estimatedCost = Int(estimatedCost)
            manager.updateItem(item)
            UIAccessibility.post(notification: .announcement, argument: "\(trimmed) 수정했어요")
            dismiss()
            return
        }

        // 추가
        guard manager.canAddItem else {
            showingPaywall = true
            return
        }
        let item = CooldownItem(
            name: trimmed,
            emoji: emoji,
            cooldownDuration: cooldownDuration,
            estimatedCost: Int(estimatedCost)
        )
        manager.addItem(item)
        UIAccessibility.post(notification: .announcement, argument: "\(trimmed) 추가했어요")
        dismiss()
    }
}

#Preview {
    AddItemView(manager: CooldownManager())
        .environment(PurchaseManager.shared)
}
