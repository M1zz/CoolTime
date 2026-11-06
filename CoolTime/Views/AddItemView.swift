import SwiftUI

/// 커스텀 아이템 추가 화면
struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    var manager: CooldownManager
    
    @State private var name = ""
    @State private var emoji = "⭐"
    @State private var category = "기타"
    @State private var estimatedCost = ""
    
    // 쿨타임 설정
    @State private var cooldownValue = 3
    @State private var cooldownUnit: CooldownUnit = .days
    
    @State private var showEmojiPicker = false
    @State private var purchases = PurchaseManager.shared
    /// 무료 한도에 닿았거나 Plus 기능을 눌렀을 때 띄우는 페이월.
    @State private var paywallTier: ProTier?
    /// 한도에 막혀 페이월을 띄웠다. 닫고 왔을 때 열렸으면 하던 추가를 마친다.
    @State private var addAfterPaywall = false
    
    enum CooldownUnit: String, CaseIterable {
        case hours = "시간"
        case days = "일"
        case weeks = "주"
        case months = "개월"
        
        var label: String {
            switch self {
            case .hours: return String(localized: "시간")
            case .days: return String(localized: "일")
            case .weeks: return String(localized: "주")
            case .months: return String(localized: "개월")
            }
        }

        func toSeconds(_ value: Int) -> TimeInterval {
            switch self {
            case .hours: return TimeInterval(value * 3600)
            case .days: return TimeInterval(value * 86400)
            case .weeks: return TimeInterval(value * 7 * 86400)
            case .months: return TimeInterval(value * 30 * 86400)
            }
        }
    }
    
    private let categories = [
        "🌏 여행", "🛍️ 쇼핑", "🍔 음식", "🎮 엔터테인먼트",
        "💅 라이프스타일", "🏃 건강", "💰 금융", "기타"
    ]
    
    private let popularEmojis = [
        "✈️", "🛍️", "🍔", "☕", "🍺", "🎮", "🚕", "💳",
        "🍕", "🎬", "💅", "💆", "🏨", "🎤", "📱", "👕",
        "🍰", "🌙", "😴", "🍖", "📈", "🎰", "⭐", "🔥"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                // 미리보기
                Section {
                    HStack {
                        Spacer()
                        previewCircle
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                // 기본 정보
                Section("기본 정보") {
                    // 이름
                    TextField("이름", text: $name)
                    
                    // 이모지 선택
                    HStack {
                        Text("아이콘")
                        Spacer()
                        Button(action: { showEmojiPicker.toggle() }) {
                            Text(emoji)
                                .font(.title)
                        }
                    }
                    
                    if showEmojiPicker {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                            ForEach(popularEmojis, id: \.self) { e in
                                Button(action: {
                                    emoji = e
                                    showEmojiPicker = false
                                }) {
                                    Text(e)
                                        .font(.title2)
                                        .padding(4)
                                        .background(
                                            emoji == e ?
                                            Color.blue.opacity(0.2) :
                                            Color.clear
                                        )
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // 카테고리
                    Picker("카테고리", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(CategoryName.localized(cat)).tag(cat)
                        }
                    }
                }
                
                // 쿨타임 설정
                Section("쿨타임 주기") {
                    HStack {
                        Picker("값", selection: $cooldownValue) {
                            ForEach(1...60, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()
                        
                        Picker("단위", selection: $cooldownUnit) {
                            ForEach(CooldownUnit.allCases, id: \.self) { unit in
                                Text(unit.label).tag(unit)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 100)
                        .clipped()
                    }
                    
                    // 빠른 선택
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            QuickSelectButton(label: String(localized: "3일")) {
                                cooldownValue = 3
                                cooldownUnit = .days
                            }
                            QuickSelectButton(label: String(localized: "1주")) {
                                cooldownValue = 1
                                cooldownUnit = .weeks
                            }
                            QuickSelectButton(label: String(localized: "2주")) {
                                cooldownValue = 2
                                cooldownUnit = .weeks
                            }
                            QuickSelectButton(label: String(localized: "1개월")) {
                                cooldownValue = 1
                                cooldownUnit = .months
                            }
                            QuickSelectButton(label: String(localized: "2개월")) {
                                cooldownValue = 2
                                cooldownUnit = .months
                            }
                        }
                    }
                }
                
                // 절반 응원 알림 — 하루 이상 쿨타임에만 (Plus)
                if cooldownUnit.toSeconds(cooldownValue) >= 86400 {
                    halfwayCheerSection
                }

                // 비용 (선택)
                Section("예상 비용 (선택)") {
                    HStack {
                        Text("₩")
                        TextField("0", text: $estimatedCost)
                            .keyboardType(.numberPad)
                    }
                    
                    Text("비용을 입력하면 절약 금액을 계산해드려요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(item: $paywallTier, onDismiss: {
                if addAfterPaywall, manager.canAddItem { addItem() }
                addAfterPaywall = false
            }) { tier in
                PaywallView(highlight: tier)
            }
            .navigationTitle("새 쿨타임")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", systemImage: "xmark") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가", systemImage: "checkmark") {
                        addItem()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private var previewCircle: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 80, height: 80)
                
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 74, height: 74)
                
                Text(emoji)
                    .font(.system(size: 36))
            }
            
            Text(name.isEmpty ? String(localized: "이름") : name)
                .font(.caption)
                .foregroundStyle(name.isEmpty ? .secondary : .primary)
            
            Text(everyLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private var everyLabel: String {
        switch cooldownUnit {
        case .hours: return String(localized: "\(cooldownValue)시간마다")
        case .days: return String(localized: "\(cooldownValue)일마다")
        case .weeks: return String(localized: "\(cooldownValue)주마다")
        case .months: return String(localized: "\(cooldownValue)개월마다")
        }
    }

    private var halfwayCheerSection: some View {
        Section {
            if purchases.allows(.halfwayCheer) {
                HStack {
                    Label {
                        Text("절반 응원 알림")
                    } icon: {
                        Image(systemName: "hands.clap.fill")
                    }
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppTheme.ready)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(Text("켜짐", comment: "Add item: the halfway cheer notification is on"))
            } else {
                Button {
                    paywallTier = .plus
                } label: {
                    HStack {
                        Label {
                            Text("절반 응원 알림")
                        } icon: {
                            Image(systemName: "hands.clap")
                        }
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(verbatim: "Plus")
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityHint(Text("Plus에서 열려요"))
            }
        } footer: {
            Text("쿨타임이 반 지나면 \"반 왔어요\" 하고 응원해 드려요.", comment: "Add item: what the halfway cheer notification does")
        }
    }

    private func addItem() {
        // 무료는 다섯 개까지. 여섯 번째는 Plus 페이월을 띄우고, 사고 돌아오면 그대로 추가한다.
        guard manager.canAddItem else {
            addAfterPaywall = true
            paywallTier = .plus
            return
        }
        let duration = cooldownUnit.toSeconds(cooldownValue)
        let cost = Int(estimatedCost)
        
        let item = CooldownItem(
            name: name,
            emoji: emoji,
            cooldownDuration: duration,
            estimatedCost: cost,
            category: category
        )
        
        manager.addItem(item)
        dismiss()
    }
}

struct QuickSelectButton: View {
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
        }
    }
}

#Preview {
    AddItemView(manager: CooldownManager())
}
