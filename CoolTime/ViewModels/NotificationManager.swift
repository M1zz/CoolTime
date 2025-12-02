//
//  NotificationManager.swift
//  CoolTime
//
//  알림 관리 서비스
//

import Foundation
import UserNotifications

/// 알림 관리자
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    // MARK: - Permission

    /// 알림 권한 요청
    func requestPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission error: \(error)")
                }
                completion(granted)
            }
        }
    }

    /// 알림 권한 상태 확인
    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    // MARK: - Schedule Notifications

    /// 쿨타임 종료 알림 예약
    func scheduleCooldownEndNotification(
        itemId: UUID,
        name: String,
        emoji: String,
        endDate: Date
    ) {
        // 이미 지난 시간이면 스킵
        guard endDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(emoji) 쿨타임 종료!"
        content.body = "\(name) 쿨타임이 끝났어요. 이제 사용할 수 있어요!"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "COOLDOWN_END"
        content.userInfo = ["itemId": itemId.uuidString]

        // 트리거 설정
        let timeInterval = endDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, timeInterval),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "cooldown-end-\(itemId.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    /// 쿨타임 50% 도달 알림 예약 (응원 메시지)
    func scheduleHalfwayNotification(
        itemId: UUID,
        name: String,
        emoji: String,
        halfwayDate: Date
    ) {
        guard halfwayDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(emoji) 절반 달성!"
        content.body = "\(name) 쿨타임의 절반을 지났어요! 조금만 더 힘내세요 💪"
        content.sound = .default
        content.categoryIdentifier = "COOLDOWN_HALFWAY"

        let timeInterval = halfwayDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, timeInterval),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "cooldown-halfway-\(itemId.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// 아이템 사용 시 알림 예약 (쿨타임 시작)
    func scheduleNotificationsForItem(
        itemId: UUID,
        name: String,
        emoji: String,
        cooldownDuration: TimeInterval,
        enableHalfwayNotification: Bool = false
    ) {
        let endDate = Date().addingTimeInterval(cooldownDuration)

        // 쿨타임 종료 알림
        scheduleCooldownEndNotification(
            itemId: itemId,
            name: name,
            emoji: emoji,
            endDate: endDate
        )

        // 절반 도달 알림 (옵션, 1시간 이상 쿨타임만)
        if enableHalfwayNotification && cooldownDuration >= 3600 {
            let halfwayDate = Date().addingTimeInterval(cooldownDuration / 2)
            scheduleHalfwayNotification(
                itemId: itemId,
                name: name,
                emoji: emoji,
                halfwayDate: halfwayDate
            )
        }
    }

    // MARK: - Cancel Notifications

    /// 특정 아이템의 모든 알림 취소
    func cancelNotifications(for itemId: UUID) {
        let identifiers = [
            "cooldown-end-\(itemId.uuidString)",
            "cooldown-halfway-\(itemId.uuidString)"
        ]

        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: identifiers
        )
    }

    /// 모든 알림 취소
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Badge Management

    /// 뱃지 초기화
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    // MARK: - Notification Categories

    /// 알림 카테고리 설정 (액션 버튼 포함)
    func setupNotificationCategories() {
        // 쿨타임 종료 카테고리
        let useAction = UNNotificationAction(
            identifier: "USE_NOW",
            title: "지금 사용하기",
            options: [.foreground]
        )

        let laterAction = UNNotificationAction(
            identifier: "REMIND_LATER",
            title: "나중에",
            options: []
        )

        let cooldownEndCategory = UNNotificationCategory(
            identifier: "COOLDOWN_END",
            actions: [useAction, laterAction],
            intentIdentifiers: [],
            options: []
        )

        // 절반 도달 카테고리
        let keepGoingAction = UNNotificationAction(
            identifier: "KEEP_GOING",
            title: "계속 힘내기 💪",
            options: []
        )

        let cooldownHalfwayCategory = UNNotificationCategory(
            identifier: "COOLDOWN_HALFWAY",
            actions: [keepGoingAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            cooldownEndCategory,
            cooldownHalfwayCategory
        ])
    }

    // MARK: - Daily Summary

    /// 매일 아침 요약 알림 예약
    func scheduleDailySummary(
        availableCount: Int,
        onCooldownCount: Int,
        hour: Int = 9,
        minute: Int = 0
    ) {
        let content = UNMutableNotificationContent()
        content.title = "오늘의 쿨타임"
        content.sound = .default

        if availableCount > 0 {
            content.body = "사용 가능한 아이템 \(availableCount)개! 쿨타임 중 \(onCooldownCount)개"
        } else if onCooldownCount > 0 {
            content.body = "모든 아이템이 쿨타임 중이에요. \(onCooldownCount)개 대기 중!"
        } else {
            content.body = "아직 쿨타임 아이템이 없어요. 추가해보세요!"
        }

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "daily-summary",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// 매일 아침 알림 취소
    func cancelDailySummary() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily-summary"]
        )
    }
}
