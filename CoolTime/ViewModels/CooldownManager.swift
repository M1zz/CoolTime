import Foundation
import SwiftUI
import SwiftData
import Combine
import UserNotifications
import WidgetKit

/// 쿨타임 관리 매니저
@Observable
final class CooldownManager {

    // MARK: - Properties

    var items: [CooldownItem] = []
    var selectedItem: CooldownItem?
    var showingAddSheet = false
    var showingTemplates = false
    var showingStats = false
    var showingSettings = false
    var searchText = ""

    /// 알림 권한 상태
    var notificationPermissionGranted = false
    var notificationPermissionDenied = false

    private var modelContext: ModelContext?
    private var timerCancellable: AnyCancellable?
    private var isAppActive = true

    // MARK: - Computed Properties

    /// 쿨타임 중인 아이템들
    var onCooldownItems: [CooldownItem] {
        items.filter { $0.isOnCooldown && $0.isActive }
    }

    /// 사용 가능한 아이템들
    var availableItems: [CooldownItem] {
        items.filter { !$0.isOnCooldown && $0.isActive }
    }

    /// 검색 필터링된 아이템
    var filteredItems: [CooldownItem] {
        if searchText.isEmpty {
            return items.filter { $0.isActive }
        }
        return items.filter {
            $0.isActive &&
            ($0.name.localizedCaseInsensitiveContains(searchText) ||
             $0.category.localizedCaseInsensitiveContains(searchText))
        }
    }

    /// 검색된 사용 가능 아이템
    var filteredAvailableItems: [CooldownItem] {
        filteredItems.filter { !$0.isOnCooldown }
    }

    /// 검색된 쿨타임 중 아이템
    var filteredOnCooldownItems: [CooldownItem] {
        filteredItems.filter { $0.isOnCooldown }
    }

    /// 이번 달 예상 절약 금액
    var monthlySavings: Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        var savings = 0
        for item in items {
            guard let cost = item.estimatedCost else { continue }

            // 이번 달에 쿨타임으로 인해 사용 안 한 횟수 추정
            let expectedUsesPerMonth = 30.0 / (item.cooldownDuration / 86400)
            let actualUses = item.usageHistory.filter {
                $0.date >= startOfMonth
            }.count

            let savedUses = max(0, Int(expectedUsesPerMonth) - actualUses - 1)
            savings += savedUses * cost
        }

        return savings
    }

    /// 전체 준수율
    var overallComplianceRate: Double {
        let activeItems = items.filter { $0.totalUseCount > 0 }
        guard !activeItems.isEmpty else { return 1.0 }

        let totalRate = activeItems.reduce(0.0) { $0 + $1.complianceRate }
        return totalRate / Double(activeItems.count)
    }

    // MARK: - Initialization

    init() {
        setupTimer()
        setupNotificationObservers()
        checkNotificationPermission()
    }

    deinit {
        timerCancellable?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchItems()
    }

    // MARK: - App Lifecycle

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppBecameActive()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillResignActive()
        }
    }

    private func handleAppBecameActive() {
        isAppActive = true
        startTimer()
        checkNotificationPermission()
    }

    private func handleAppWillResignActive() {
        isAppActive = false
        stopTimer()
        syncWidgetData()
    }

    // MARK: - Timer for UI Updates (배터리 최적화)

    private func setupTimer() {
        startTimer()
    }

    private func startTimer() {
        guard timerCancellable == nil else { return }

        // 앱이 활성화 상태일 때만 타이머 실행
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isAppActive else { return }
                self.updateCooldowns()
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func updateCooldowns() {
        // 쿨타임 중인 아이템이 있을 때만 업데이트
        guard !onCooldownItems.isEmpty else { return }

        // @Observable이 자동으로 변경 감지
        for item in items where item.isOnCooldown {
            if item.remainingCooldown <= 0 {
                // 쿨타임 완료됨 - UI 자동 갱신
            }
        }
    }

    // MARK: - CRUD Operations

    func fetchItems() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<CooldownItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            items = try context.fetch(descriptor)
            syncWidgetData()
        } catch {
            print("Failed to fetch items: \(error)")
        }
    }

    func addItem(_ item: CooldownItem) {
        guard let context = modelContext else { return }

        context.insert(item)
        saveContext()
        fetchItems()
    }

    func addFromTemplate(_ template: CooldownTemplate) {
        let item = template.toItem()
        addItem(item)
    }

    func deleteItem(_ item: CooldownItem) {
        guard let context = modelContext else { return }

        // 알림 취소
        cancelNotifications(for: item)

        context.delete(item)
        saveContext()
        fetchItems()
    }

    func updateItem(_ item: CooldownItem) {
        saveContext()
        fetchItems()
    }

    // MARK: - Cooldown Actions

    /// 아이템 사용 (쿨타임 시작)
    func useItem(_ item: CooldownItem, note: String? = nil, actualCost: Int? = nil) {
        let brokeCooldown = item.isOnCooldown
        item.use(note: note, actualCost: actualCost, brokeRule: brokeCooldown)

        // 쿨타임 종료 알림 예약
        if notificationPermissionGranted {
            scheduleCooldownEndNotification(for: item)
        }

        saveContext()
        fetchItems()
    }

    /// 쿨타임 깨기 (쿨타임 중에 사용)
    func breakCooldown(_ item: CooldownItem, note: String? = nil) {
        useItem(item, note: "⚠️ 쿨타임 중 사용: \(note ?? "")")
    }

    /// 쿨타임 리셋
    func resetCooldown(_ item: CooldownItem) {
        cancelNotifications(for: item)
        item.resetCooldown()
        saveContext()
        fetchItems()
    }

    // MARK: - Notifications

    func checkNotificationPermission() {
        NotificationManager.shared.checkPermissionStatus { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.notificationPermissionGranted = true
                    self?.notificationPermissionDenied = false
                case .denied:
                    self?.notificationPermissionGranted = false
                    self?.notificationPermissionDenied = true
                case .notDetermined:
                    self?.notificationPermissionGranted = false
                    self?.notificationPermissionDenied = false
                default:
                    break
                }
            }
        }
    }

    func requestNotificationPermission() {
        NotificationManager.shared.requestPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.notificationPermissionGranted = granted
                self?.notificationPermissionDenied = !granted
                if granted {
                    NotificationManager.shared.setupNotificationCategories()
                }
            }
        }
    }

    private func scheduleCooldownEndNotification(for item: CooldownItem) {
        NotificationManager.shared.scheduleNotificationsForItem(
            itemId: item.id,
            name: item.name,
            emoji: item.emoji,
            cooldownDuration: item.cooldownDuration,
            enableHalfwayNotification: item.cooldownDuration >= 86400
        )
    }

    private func cancelNotifications(for item: CooldownItem) {
        NotificationManager.shared.cancelNotifications(for: item.id)
    }

    /// 설정 앱으로 이동 (알림 권한)
    func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Persistence

    private func saveContext() {
        guard let context = modelContext else { return }

        do {
            try context.save()
            syncWidgetData()
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    // MARK: - Widget Data Sync

    func syncWidgetData() {
        let widgetItems = items.map { item in
            WidgetCooldownItem(
                id: item.id,
                name: item.name,
                emoji: item.emoji,
                cooldownDuration: item.cooldownDuration,
                lastUsedDate: item.lastUsedDate,
                estimatedCost: item.estimatedCost,
                category: item.category
            )
        }
        WidgetDataStore.saveItems(widgetItems)

        let stats = WidgetStats(
            totalItems: items.count,
            availableCount: availableItems.count,
            onCooldownCount: onCooldownItems.count,
            complianceRate: overallComplianceRate,
            monthlySavings: monthlySavings
        )
        WidgetDataStore.saveStats(stats)

        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Statistics Helper

extension CooldownManager {

    /// 카테고리별 통계
    func statsByCategory() -> [(category: String, items: Int, compliance: Double)] {
        let grouped = Dictionary(grouping: items) { $0.category }

        return grouped.map { category, categoryItems in
            let avgCompliance = categoryItems.isEmpty ? 1.0 :
                categoryItems.reduce(0.0) { $0 + $1.complianceRate } / Double(categoryItems.count)

            return (category, categoryItems.count, avgCompliance)
        }.sorted { $0.category < $1.category }
    }

    /// 최근 7일 사용 기록
    func recentActivity() -> [Date: Int] {
        var activity: [Date: Int] = [:]
        let calendar = Calendar.current

        for item in items {
            for record in item.usageHistory {
                let day = calendar.startOfDay(for: record.date)
                activity[day, default: 0] += 1
            }
        }

        return activity
    }
}
