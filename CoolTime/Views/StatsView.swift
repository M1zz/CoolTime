import SwiftUI

/// 기록 화면 — "내가 이걸 얼마나, 언제 했나"에만 답하는 단순한 거울.
/// 준수율·차트·카테고리 같은 판단/장식 요소는 두지 않는다.
struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseManager.self) private var purchaseManager
    var manager: CooldownManager

    @State private var showingPaywall = false
    @State private var showingAutomation = false

    var body: some View {
        NavigationStack {
            Group {
                if manager.items.isEmpty {
                    emptyState
                } else {
                    List {
                        savingsHero

                        Section {
                            Button { showingAutomation = true } label: {
                                Label("지를 때 자동으로 멈추기", systemImage: "hand.raised.fill")
                                    .font(.headline)
                            }
                            .accessibilityHint("배달·쇼핑 앱 열 때 자동으로 묻게 설정해요")
                        }

                        Section {
                            ForEach(sortedItems) { item in
                                recordRow(item)
                            }
                        } header: {
                            Text("지금까지 한 기록")
                                .textCase(nil)
                        }

                        #if DEBUG
                        Section("디버그 (위젯 동기화)") {
                            Text("앱 항목: \(manager.items.count)개")
                            Text("공유 저장소: \(WidgetDataStore.loadItems().count)개")
                                .foregroundStyle(WidgetDataStore.loadItems().count == manager.items.count ? .green : .red)
                            Button("위젯 강제 동기화") {
                                manager.syncWidgetData()
                            }
                        }
                        #endif

                        if purchaseManager.isPro {
                            if !allRecords.isEmpty {
                                Section("전체 내역") {
                                    ForEach(allRecords, id: \.record.id) { entry in
                                        timelineRow(entry)
                                    }
                                }
                            }
                        } else {
                            Section {
                                Button { showingPaywall = true } label: {
                                    Label("Pro에서 전체 사용 내역 보기", systemImage: "lock.fill")
                                        .font(.headline)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(trigger: .statsHistory).environment(purchaseManager)
            }
            .sheet(isPresented: $showingAutomation) {
                AutomationGuideView()
            }
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-OpenGuide") {
                    showingAutomation = true
                }
                #endif
            }
        }
    }

    // MARK: - Savings Hero (돈 후크)

    @ViewBuilder
    private var savingsHero: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("이번 달 아낀 돈")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("₩\(manager.monthlySavings.formatted())")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.readyStrong)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.readyStrong)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("이번 달 아낀 돈 \(manager.monthlySavings)원")

                // 스트릭
                Label {
                    if manager.streakDays > 0 {
                        Text("\(manager.streakDays)일째 충동 없이")
                            .font(.subheadline).fontWeight(.semibold)
                    } else {
                        Text("오늘부터 다시")
                            .font(.subheadline).fontWeight(.semibold)
                    }
                } icon: {
                    Image(systemName: "flame.fill")
                }
                .foregroundStyle(AppTheme.warning)
                .accessibilityLabel(manager.streakDays > 0
                    ? "\(manager.streakDays)일째 충동 없이 이어가는 중"
                    : "오늘부터 다시 시작")
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Per-item Record Row

    private func recordRow(_ item: CooldownItem) -> some View {
        HStack(spacing: 14) {
            Text(item.emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.headline)

                if let last = item.lastUsedDate {
                    Text(String(format: NSLocalizedString("마지막 %@", comment: ""), relativeText(last)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("아직 한 번도 안 했어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(String(format: NSLocalizedString("%lld번", comment: ""), item.totalUseCount))
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(item.totalUseCount > 0 ? AppTheme.readyStrong : .secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(recordAccessibilityLabel(item))
    }

    private func recordAccessibilityLabel(_ item: CooldownItem) -> Text {
        let count = Text(String(format: NSLocalizedString("%lld번", comment: ""), item.totalUseCount))
        if let last = item.lastUsedDate {
            return Text(verbatim: item.name) + Text(verbatim: ", ") + count
                + Text(verbatim: ", ")
                + Text(String(format: NSLocalizedString("마지막 %@", comment: ""), relativeText(last)))
        } else {
            return Text(verbatim: item.name) + Text(verbatim: ", ") + Text("아직 한 번도 안 했어요")
        }
    }

    // MARK: - Pro Timeline Row

    private func timelineRow(_ entry: (emoji: String, name: String, record: UsageRecord)) -> some View {
        HStack(spacing: 12) {
            Text(entry.emoji)
                .font(.title3)
            Text(entry.name)
                .font(.subheadline)
            Spacer()
            Text(relativeText(entry.record.date))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: entry.name) + Text(verbatim: ", ") + Text(relativeText(entry.record.date)))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("아직 기록이 없어요")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("아직 기록이 없어요")
    }

    // MARK: - Data

    /// 최근에 한 순서(한 번도 안 한 항목은 뒤로)
    private var sortedItems: [CooldownItem] {
        manager.items.sorted {
            ($0.lastUsedDate ?? .distantPast) > ($1.lastUsedDate ?? .distantPast)
        }
    }

    /// 전체 사용 내역(최신순)
    private var allRecords: [(emoji: String, name: String, record: UsageRecord)] {
        manager.items
            .flatMap { item in item.usageHistory.map { (item.emoji, item.name, $0) } }
            .sorted { $0.record.date > $1.record.date }
    }

    private func relativeText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    StatsView(manager: CooldownManager())
        .environment(PurchaseManager.shared)
}
