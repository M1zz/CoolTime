import SwiftUI
import SwiftData

/// 메인 홈 화면 — 섹션 구분 없는 단일 그리드(사용 가능 → 대기 순).
/// 타일 모양만으로 상태를 알 수 있어 헤더를 두지 않는다. 인지 부담 최소화.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PurchaseManager.self) private var purchaseManager
    @State private var manager = CooldownManager()

    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showingAutomationGuide = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIcon = "bolt.fill"
    @State private var toastColor = AppTheme.warning
    @State private var showingPaywall = false
    @State private var paywallTrigger: PaywallTrigger = .general

    // 통합 액션: 타일을 탭하면 "했어요?" 확인
    @State private var pendingItem: CooldownItem?
    // 길게 눌러 "수정" → 편집 시트
    @State private var editingItem: CooldownItem?

    // 1초마다 화면 갱신(카운트다운/와이프) + 사용 가능 전환 감지(햅틱)
    @State private var now = Date()
    @State private var knownReadyIDs: Set<UUID> = []
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // 고정 2열 그리드
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            NavigationStack {
                content
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
                    .safeAreaInset(edge: .bottom) { bottomBar }
                    .sheet(isPresented: $manager.showingAddSheet) {
                        AddItemView(manager: manager).environment(purchaseManager)
                    }
                    .sheet(item: $editingItem) { item in
                        AddItemView(manager: manager, editingItem: item).environment(purchaseManager)
                    }
                    .sheet(isPresented: $manager.showingStats) {
                        StatsView(manager: manager).environment(purchaseManager)
                    }
                    .sheet(isPresented: $showingPaywall) {
                        PaywallView(trigger: paywallTrigger).environment(purchaseManager)
                    }
                    .confirmationDialog(
                        confirmTitle,
                        isPresented: confirmBinding,
                        titleVisibility: .visible
                    ) {
                        if let item = pendingItem, item.isOnCooldown {
                            Button("참았어요 ✊") { performResist() }
                            Button("그냥 샀어요", role: .destructive) { performUse() }
                            Button("취소", role: .cancel) { pendingItem = nil }
                        } else {
                            Button("했어요") { performUse() }
                            Button("취소", role: .cancel) { pendingItem = nil }
                        }
                    } message: {
                        if let item = pendingItem, item.isOnCooldown {
                            Text("아직 \(item.remainingCooldown.cooldownFormatted) 남았어요. 여기서 참으면 충동을 이긴 걸로 기록돼요.")
                        }
                    }
                    .fullScreenCover(isPresented: $showOnboarding) {
                        OnboardingView(isPresented: $showOnboarding)
                    }
                    .sheet(isPresented: $showingAutomationGuide) {
                        AutomationGuideView()
                    }
                    .onChange(of: showOnboarding) { _, isShowing in
                        // 온보딩이 막 끝났으면 자동화 가이드를 한 번 띄운다
                        if !isShowing, UserDefaults.standard.bool(forKey: "pendingAutomationGuide") {
                            UserDefaults.standard.set(false, forKey: "pendingAutomationGuide")
                            showingAutomationGuide = true
                        }
                    }
            }
            .onAppear {
                manager.setModelContext(modelContext)
                knownReadyIDs = Set(manager.readyItems.map(\.id))
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-OpenStats") {
                    manager.showingStats = true
                }
                if ProcessInfo.processInfo.arguments.contains("-OpenEdit") {
                    editingItem = manager.waitingItems.first ?? manager.readyItems.first
                }
                #endif
            }
            .onReceive(ticker) { date in
                let current = Set(manager.readyItems.map(\.id))
                let newlyReady = current.subtracting(knownReadyIDs)
                // 쿨타임이 끝나 새로 사용 가능해진 아이템이 있으면 햅틱 + 부드러운 재배치
                withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8)) {
                    now = date
                }
                if !newlyReady.isEmpty {
                    Haptics.notify(.success)
                }
                knownReadyIDs = current
            }

            if showToast {
                ToastView(message: toastMessage, icon: toastIcon, color: toastColor)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
                    .zIndex(1)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if manager.items.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if manager.notificationPermissionDenied {
                        notificationPermissionRow
                    }

                    // 섹션 구분 없이 단일 그리드 — 타일 모양만으로 상태를 알 수 있다.
                    // 정렬: 사용 가능한 것 먼저, 그다음 곧 풀리는 순서.
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(displayItems) { item in
                            tileButton(for: item)
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    // 사용 가능 → 대기(곧 풀리는 순) 순으로 한 줄에 합친 목록
    private var displayItems: [CooldownItem] {
        manager.readyItems + manager.waitingItems
    }

    // MARK: - Grid Tile

    private func tileButton(for item: CooldownItem) -> some View {
        Button {
            Haptics.impact(.light)
            pendingItem = item
        } label: {
            CooldownTile(item: item)
        }
        .buttonStyle(PressableTileStyle(reduceMotion: reduceMotion))
        .contextMenu {
            Button {
                Haptics.impact(.light)
                editingItem = item
            } label: {
                Label("수정", systemImage: "pencil")
            }

            if item.isOnCooldown {
                Button {
                    Haptics.impact(.rigid)
                    withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8)) {
                        manager.resetCooldown(item)
                    }
                    knownReadyIDs = Set(manager.readyItems.map(\.id))
                    announce("\(item.name) 쿨타임을 초기화했어요")
                } label: {
                    Label("쿨타임 리셋", systemImage: "arrow.counterclockwise")
                }
            }

            Button(role: .destructive) {
                deleteWithAnnounce(item)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }


    // MARK: - Bottom Bar (상단 버튼들을 하단으로 이동)

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { manager.showingStats = true } label: {
                Label("기록", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(AppTheme.waitingStrong)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.waitingStrong.opacity(0.12))
                    )
            }
            .buttonStyle(PressableTileStyle(reduceMotion: reduceMotion))
            .accessibilityLabel("기록 보기")

            Button { handleAddButtonTap() } label: {
                Label("추가", systemImage: "plus")
                    .font(.headline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.readyStrong)
                    )
            }
            .buttonStyle(PressableTileStyle(reduceMotion: reduceMotion))
            .accessibilityLabel("쿨타임 추가")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.bar)
    }

    // MARK: - Notification Row

    private var notificationPermissionRow: some View {
        Button { manager.openNotificationSettings() } label: {
            HStack(spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("알림이 꺼져 있어요")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("쿨타임이 끝나면 알려드리도록 설정에서 켜주세요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.cardBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.warning.opacity(0.4), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("알림이 꺼져 있어요. 두 번 탭하면 설정으로 이동해요")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        // 추가 방법은 하단 '추가' 버튼 하나뿐이므로, 빈 화면은 그곳을 가리키기만 한다.
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("아래 ‘추가’로\n첫 쿨타임을 만들어 보세요")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("쿨타임이 없어요. 아래 추가 버튼으로 첫 쿨타임을 만들어 보세요")
    }

    // MARK: - Actions

    private var confirmTitle: Text {
        guard let item = pendingItem else { return Text("") }
        return item.isOnCooldown ? Text("\(item.name), 지금 어떻게 할까요?")
                                 : Text("\(item.name), 했어요?")
    }

    private func performResist() {
        guard let item = pendingItem else { return }
        Haptics.notify(.success)
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8)) {
            manager.resistItem(item)
        }
        let name = item.name
        pendingItem = nil
        toastMessage = String(format: NSLocalizedString("'%@' 참았어요. 잘했어요!", comment: ""), name)
        toastIcon = "hand.raised.fill"
        toastColor = AppTheme.readyStrong
        withAnimation { showToast = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { withAnimation { showToast = false } }
        }
    }

    private var confirmBinding: Binding<Bool> {
        Binding(get: { pendingItem != nil }, set: { if !$0 { pendingItem = nil } })
    }

    private func performUse() {
        guard let item = pendingItem else { return }
        let wasCooldown = item.isOnCooldown
        // 쿨타임 중 사용(깸)이면 경고 햅틱, 평소 사용이면 성공 햅틱
        Haptics.notify(wasCooldown ? .warning : .success)
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8)) {
            manager.useItem(item)
        }
        knownReadyIDs = Set(manager.readyItems.map(\.id))
        pendingItem = nil

        if wasCooldown {
            toastMessage = String(format: NSLocalizedString("'%@' 쿨타임을 다시 시작했어요", comment: ""), item.name)
            toastIcon = "bolt.fill"
            toastColor = AppTheme.warning
            withAnimation { showToast = true } // ToastView가 음성 안내까지 처리
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    withAnimation { showToast = false }
                    if item.breakCount >= 3 && !purchaseManager.isPro {
                        paywallTrigger = .breakFeedback
                        showingPaywall = true
                    }
                }
            }
        } else {
            announce(String(format: NSLocalizedString("'%@' 사용을 기록했어요", comment: ""), item.name))
        }
    }

    private func deleteWithAnnounce(_ item: CooldownItem) {
        let name = item.name
        Haptics.impact(.medium)
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8)) {
            manager.deleteItem(item)
        }
        knownReadyIDs = Set(manager.readyItems.map(\.id))
        announce("\(name) 삭제했어요")
    }

    private func handleAddButtonTap() {
        if manager.canAddItem {
            manager.showingAddSheet = true
        } else {
            paywallTrigger = .itemLimit
            showingPaywall = true
        }
    }

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .modelContainer(for: CooldownItem.self, inMemory: true)
        .environment(PurchaseManager.shared)
}
