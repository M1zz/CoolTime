import Foundation
import SwiftData

/// 쿨타임 아이템 모델
@Model
final class CooldownItem {
    var id: UUID
    var name: String
    var emoji: String
    var cooldownDuration: TimeInterval  // 쿨타임 기간 (초 단위)
    var lastUsedDate: Date?             // 마지막 사용 시각
    var estimatedCost: Int?             // 예상 비용 (선택)
    var category: String
    var isActive: Bool                  // 활성화 여부
    var createdAt: Date
    
    // 통계용
    var totalUseCount: Int              // 총 사용 횟수
    var breakCount: Int                 // 쿨타임 깬 횟수
    var usageHistory: [UsageRecord]     // 사용 기록
    
    init(
        name: String,
        emoji: String,
        cooldownDuration: TimeInterval,
        estimatedCost: Int? = nil,
        category: String = "기타"
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.cooldownDuration = cooldownDuration
        self.lastUsedDate = nil
        self.estimatedCost = estimatedCost
        self.category = category
        self.isActive = true
        self.createdAt = Date()
        self.totalUseCount = 0
        self.breakCount = 0
        self.usageHistory = []
    }
    
    // MARK: - Computed Properties
    
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
    
    /// 쿨타임 잘 지킨 비율
    var complianceRate: Double {
        guard totalUseCount > 0 else { return 1.0 }
        return Double(totalUseCount - breakCount) / Double(totalUseCount)
    }
    
    // MARK: - Methods
    
    /// 사용하기 (쿨타임 시작)
    func use(note: String? = nil, actualCost: Int? = nil, brokeRule: Bool = false) {
        let record = UsageRecord(
            date: Date(),
            note: note,
            cost: actualCost ?? estimatedCost,
            brokeCooldown: brokeRule
        )
        usageHistory.append(record)
        totalUseCount += 1
        
        if brokeRule {
            breakCount += 1
        }
        
        lastUsedDate = Date()
    }
    
    /// 쿨타임 리셋
    func resetCooldown() {
        lastUsedDate = nil
    }
}

// MARK: - 사용 기록

struct UsageRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var note: String?
    var cost: Int?
    var brokeCooldown: Bool  // 쿨타임 중에 사용했는지
}

// MARK: - 시간 포맷팅 Extension

extension TimeInterval {
    /// 남은 시간을 읽기 쉽게 포맷팅
    var cooldownFormatted: String {
        let totalSeconds = Int(self)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if days > 0 {
            return "\(days)일 \(hours)시간"
        } else if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        } else if minutes > 0 {
            return "\(minutes)분 \(seconds)초"
        } else {
            return "\(seconds)초"
        }
    }
    
    /// 쿨타임 기간 설정용 (일/시간 단위)
    static func days(_ days: Int) -> TimeInterval {
        return TimeInterval(days * 86400)
    }
    
    static func hours(_ hours: Int) -> TimeInterval {
        return TimeInterval(hours * 3600)
    }
    
    static func weeks(_ weeks: Int) -> TimeInterval {
        return TimeInterval(weeks * 7 * 86400)
    }
    
    static func months(_ months: Int) -> TimeInterval {
        return TimeInterval(months * 30 * 86400)
    }
    
    #if DEBUG
    // 테스트 (분 단위)
    static func minutes(_ minutes: Int) -> TimeInterval {
        return TimeInterval(minutes * 60)
    }
    #endif
}
