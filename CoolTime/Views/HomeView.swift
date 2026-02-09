import SwiftUI
import SwiftData

/// 메인 홈 화면
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var manager = CooldownManager()
    @State private var selectedItem: CooldownItem?
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 알림 권한 배너
                    if manager.notificationPermissionDenied {
                        notificationPermissionBanner
                    }

                    // 요약 카드
                    summarySection

                    // 검색 바 (아이템이 있을 때만)
                    if !manager.items.isEmpty {
                        searchBar
                    }

                    // 사용 가능한 아이템들
                    if !displayedAvailableItems.isEmpty {
                        availableSection
                    }

                    // 쿨타임 중인 아이템들
                    if !displayedOnCooldownItems.isEmpty {
                        cooldownSection
                    }

                    // 검색 결과 없음
                    if !manager.searchText.isEmpty && displayedAvailableItems.isEmpty && displayedOnCooldownItems.isEmpty {
                        noSearchResultsView
                    }

                    // 빈 상태
                    if manager.items.isEmpty {
                        emptyState
                    }
                }
                .padding()
            }
            .background(AppTheme.pageBackground(for: colorScheme))
            .navigationTitle("쿨타임")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { manager.showingStats = true }) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(AppTheme.cooldown)
                    }
                    .accessibilityLabel("통계 보기")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: { manager.showingTemplates = true }) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(AppTheme.warning)
                    }
                    .accessibilityLabel("템플릿에서 추가")

                    Button(action: { manager.showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppTheme.ready)
                    }
                    .accessibilityLabel("새 쿨타임 추가")
                }
            }
            .sheet(isPresented: $manager.showingAddSheet) {
                AddItemView(manager: manager)
            }
            .sheet(isPresented: $manager.showingTemplates) {
                TemplatesView(manager: manager)
            }
            .sheet(isPresented: $manager.showingStats) {
                StatsView(manager: manager)
            }
            .sheet(item: $selectedItem) { item in
                UseItemSheet(item: item, isPresented: .init(
                    get: { selectedItem != nil },
                    set: { if !$0 { selectedItem = nil } }
                )) { note, cost in
                    manager.useItem(item, note: note, actualCost: cost)
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
        }
        .onAppear {
            manager.setModelContext(modelContext)
        }
    }

    // MARK: - Computed Properties

    private var displayedAvailableItems: [CooldownItem] {
        manager.searchText.isEmpty ? manager.availableItems : manager.filteredAvailableItems
    }

    private var displayedOnCooldownItems: [CooldownItem] {
        manager.searchText.isEmpty ? manager.onCooldownItems : manager.filteredOnCooldownItems
    }

    // MARK: - Notification Permission Banner

    private var notificationPermissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text("알림이 꺼져있어요")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("쿨타임 종료 알림을 받으려면 설정에서 켜주세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { manager.openNotificationSettings() }) {
                Text("설정")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppTheme.warning))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.warning.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("알림이 꺼져있습니다. 설정 버튼을 눌러 알림을 켜세요")
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("아이템 검색...", text: $manager.searchText)
                .textFieldStyle(.plain)

            if !manager.searchText.isEmpty {
                Button(action: { manager.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("검색어 지우기")
            }
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

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SummaryCard(
                    title: "준수율",
                    value: "\(Int(manager.overallComplianceRate * 100))%",
                    icon: "checkmark.shield.fill",
                    color: AppTheme.complianceColor(for: manager.overallComplianceRate),
                    colorScheme: colorScheme
                )
                .accessibilityLabel("준수율 \(Int(manager.overallComplianceRate * 100))퍼센트")

                SummaryCard(
                    title: "예상 절약",
                    value: "₩\(manager.monthlySavings.formatted())",
                    icon: "wonsign.circle.fill",
                    color: AppTheme.ready,
                    colorScheme: colorScheme
                )
                .accessibilityLabel("이번 달 예상 절약 금액 \(manager.monthlySavings)원")
            }

            HStack(spacing: 12) {
                SummaryCard(
                    title: "사용 가능",
                    value: "\(manager.availableItems.count)개",
                    icon: "checkmark.circle.fill",
                    color: AppTheme.ready,
                    colorScheme: colorScheme
                )
                .accessibilityLabel("사용 가능한 아이템 \(manager.availableItems.count)개")

                SummaryCard(
                    title: "쿨타임 중",
                    value: "\(manager.onCooldownItems.count)개",
                    icon: "clock.fill",
                    color: AppTheme.cooldown,
                    colorScheme: colorScheme
                )
                .accessibilityLabel("쿨타임 중인 아이템 \(manager.onCooldownItems.count)개")
            }
        }
    }

    // MARK: - Available Section

    private var availableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ready)
                Text("사용 가능")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Text("\(displayedAvailableItems.count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.ready))
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("사용 가능 \(displayedAvailableItems.count)개")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(displayedAvailableItems) { item in
                        ItemCardCompact(item: item) {
                            selectedItem = item
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation {
                                    manager.deleteItem(item)
                                }
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                        .accessibilityLabel("\(item.emoji) \(item.name), 사용 가능")
                        .accessibilityHint("탭하여 사용하기")
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Cooldown Section

    private var cooldownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.cooldown)
                Text("쿨타임 중")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Text("\(displayedOnCooldownItems.count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.cooldown))
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("쿨타임 중 \(displayedOnCooldownItems.count)개")

            LazyVStack(spacing: 12) {
                ForEach(displayedOnCooldownItems) { item in
                    ItemCard(
                        item: item,
                        onUse: { selectedItem = item },
                        onBreak: { selectedItem = item }
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            manager.deleteItem(item)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }

                        Button {
                            manager.resetCooldown(item)
                        } label: {
                            Label("쿨타임 리셋", systemImage: "arrow.counterclockwise")
                        }
                    }
                    .accessibilityLabel("\(item.emoji) \(item.name), 쿨타임 \(item.remainingCooldown.cooldownFormatted) 남음")
                    .accessibilityHint("탭하여 쿨타임 깨기, 길게 눌러 더 많은 옵션")
                }
            }
        }
    }

    // MARK: - No Search Results

    private var noSearchResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("'\(manager.searchText)' 검색 결과 없음")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("다른 키워드로 검색해보세요")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("검색 결과 없음")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 70))
                .foregroundStyle(AppTheme.readyGradient)

            Text("아직 쿨타임이 없어요")
                .font(.title2)
                .fontWeight(.bold)

            Text("템플릿에서 추가하거나\n직접 만들어보세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button(action: { manager.showingTemplates = true }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("템플릿")
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.warning)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .stroke(AppTheme.warning, lineWidth: 2)
                    )
                }

                Button(action: { manager.showingAddSheet = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("직접 추가")
                    }
                    .appGradientButtonStyle()
                }
            }
        }
        .padding(.vertical, 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("아직 쿨타임이 없습니다. 템플릿에서 추가하거나 직접 만들어보세요")
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Image(systemName: icon)
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardBackground(for: colorScheme))
                .shadow(
                    color: AppTheme.shadowColor(for: colorScheme),
                    radius: 8,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.4), lineWidth: 1.5)
        )
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .modelContainer(for: CooldownItem.self, inMemory: true)
}
