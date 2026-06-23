//
//  SharedData.swift
//  CoolTime Widget
//
//  앱과 위젯 간 데이터 공유를 위한 구조체
//

import Foundation

/// 위젯에서 표시할 쿨타임 아이템 데이터
struct WidgetCooldownItem: Codable, Identifiable {
    var id: UUID
    var name: String
    var emoji: String
    var cooldownDuration: TimeInterval
    var lastUsedDate: Date?
    var estimatedCost: Int?
    var category: String

    /// 현재 쿨타임 중인지
    var isOnCooldown: Bool {
        guard let lastUsed = lastUsedDate else { return false }
        return Date() < lastUsed.addingTimeInterval(cooldownDuration)
    }

    /// 남은 쿨타임 (초)
    var remainingCooldown: TimeInterval {
        guard let lastUsed = lastUsedDate else { return 0 }
        let endTime = lastUsed.addingTimeInterval(cooldownDuration)
        return max(0, endTime.timeIntervalSince(Date()))
    }

    /// 쿨타임 진행률 (0.0 ~ 1.0)
    var cooldownProgress: Double {
        guard let lastUsed = lastUsedDate else { return 1.0 }
        let elapsed = Date().timeIntervalSince(lastUsed)
        return min(1.0, elapsed / cooldownDuration)
    }

    /// 쿨타임 종료 예정 시각
    var cooldownEndDate: Date? {
        guard let lastUsed = lastUsedDate else { return nil }
        return lastUsed.addingTimeInterval(cooldownDuration)
    }
}

/// 위젯 데이터 저장소
struct WidgetDataStore {
    // App Group ID - Xcode Signing & Capabilities에서 동일하게 설정 필요
    static let appGroupID = "group.com.Ysoup.CoolTime.shared"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static let itemsKey = "widget_cooldown_items"
    private static let statsKey = "widget_stats"
    private static let isProKey = "widget_isPro"

    // MARK: - Items

    /// 위젯용 아이템 저장
    static func saveItems(_ items: [WidgetCooldownItem]) {
        guard let defaults = sharedDefaults else { return }

        if let encoded = try? JSONEncoder().encode(items) {
            defaults.set(encoded, forKey: itemsKey)
        }
    }

    /// 위젯용 아이템 로드
    static func loadItems() -> [WidgetCooldownItem] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: itemsKey),
              let items = try? JSONDecoder().decode([WidgetCooldownItem].self, from: data) else {
            return []
        }
        return items
    }

    // MARK: - Stats

    /// 위젯용 통계 저장
    static func saveStats(_ stats: WidgetStats) {
        guard let defaults = sharedDefaults else { return }

        if let encoded = try? JSONEncoder().encode(stats) {
            defaults.set(encoded, forKey: statsKey)
        }
    }

    /// 위젯용 통계 로드
    static func loadStats() -> WidgetStats {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: statsKey),
              let stats = try? JSONDecoder().decode(WidgetStats.self, from: data) else {
            return WidgetStats()
        }
        return stats
    }

    // MARK: - Pro Status

    static func saveIsPro(_ isPro: Bool) {
        sharedDefaults?.set(isPro, forKey: isProKey)
    }

    static func loadIsPro() -> Bool {
        sharedDefaults?.bool(forKey: isProKey) ?? false
    }
}

/// 위젯용 통계 데이터
struct WidgetStats: Codable {
    var totalItems: Int = 0
    var availableCount: Int = 0
    var onCooldownCount: Int = 0
    var complianceRate: Double = 1.0
    var monthlySavings: Int = 0
    var isPro: Bool = false
    var streakDays: Int = 0          // 충동 없이 이어온 연속 일수
    var lastSync: Date? = nil        // 앱이 마지막으로 위젯 데이터를 쓴 시각 (진단용)
}

// MARK: - TimeInterval Extension for Widget

extension TimeInterval {
    /// 위젯용 짧은 포맷
    var widgetFormatted: String {
        let totalSeconds = Int(self)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        if days > 0 {
            return "\(days)일"
        } else if hours > 0 {
            return "\(hours)시간"
        } else if minutes > 0 {
            return "\(minutes)분"
        } else {
            return "곧!"
        }
    }
}
