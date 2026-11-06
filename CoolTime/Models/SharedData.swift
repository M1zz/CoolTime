//
//  SharedData.swift
//  CoolTime
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
    private static let tierKey = "pro_tier"

    // MARK: - 칸 (무료 0 · Plus 1 · Pro 2)

    /// 앱이 영수증을 확인하고 적는다(`PurchaseManager`). 위젯은 결제를 조회하지 않고 이것만 읽는다.
    static func saveTier(_ rawValue: Int) {
        guard let defaults = sharedDefaults, defaults.object(forKey: tierKey) as? Int != rawValue else { return }
        defaults.set(rawValue, forKey: tierKey)
    }

    /// 위젯이 열려 있는가(Pro).
    /// ⚠️ 적힌 값이 없으면 **연다.** 앱이 아직 영수증을 못 읽은 것이지 무료라는 뜻이 아니다 —
    ///    업데이트 뒤 앱을 열기 전에 산 사람의 위젯이 잠기면 안 된다.
    static var unlocksWidget: Bool {
        guard let raw = sharedDefaults?.object(forKey: tierKey) as? Int else { return true }
        return raw >= 2
    }

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
}

/// 위젯이 앱을 여는 링크.
enum CoolTimeWidgetLink {
    /// 잠긴 위젯(Pro 아님)을 누르면 앱이 Pro 페이월을 띄운다.
    static let paywall = URL(string: "cooltime://paywall")!
}

/// 위젯용 통계 데이터
struct WidgetStats: Codable {
    var totalItems: Int = 0
    var availableCount: Int = 0
    var onCooldownCount: Int = 0
    var complianceRate: Double = 1.0
    var monthlySavings: Int = 0
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
            return String(localized: "\(days)일")
        } else if hours > 0 {
            return String(localized: "\(hours)시간")
        } else if minutes > 0 {
            return String(localized: "\(minutes)분")
        } else {
            return String(localized: "곧!")
        }
    }
}
