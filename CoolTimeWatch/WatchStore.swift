//
//  WatchStore.swift
//  워치 앱과 컴플리케이션이 함께 보는 '마지막으로 받은 목록'. 폰이 멀어져도 이것으로 센다.
//

import Foundation

enum WatchStore {
    static let group = "group.com.Ysoup.CoolTime.shared"
    private static let key = "watch.snapshot"
    private static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }

    static func load() -> WatchSnapshot? {
        #if DEBUG
        if let demo = WatchDemo.snapshot { return demo }
        #endif
        return CoolTimeWatchKeys.decode(defaults.data(forKey: key))
    }

    static func save(_ snapshot: WatchSnapshot) {
        defaults.set(CoolTimeWatchKeys.encode(snapshot), forKey: key)
    }
}

#if DEBUG
/// 시뮬레이터에서 아이폰 없이 화면을 보려고 — 실행 인자 `-watchDemo YES` 일 때만.
enum WatchDemo {
    static var snapshot: WatchSnapshot? {
        guard UserDefaults.standard.bool(forKey: "watchDemo") else { return nil }
        let now = Date.now, day: TimeInterval = 86_400
        return WatchSnapshot(items: [
            .init(id: UUID(), name: String(localized: "배달 음식"), emoji: "🍔", duration: 3 * day, lastUsed: now.addingTimeInterval(-1.2 * day)),
            .init(id: UUID(), name: String(localized: "온라인 쇼핑"), emoji: "🛍️", duration: 7 * day, lastUsed: now.addingTimeInterval(-2 * day)),
            .init(id: UUID(), name: String(localized: "카페 음료"), emoji: "☕️", duration: day, lastUsed: now.addingTimeInterval(-2 * day)),
        ], unlocksComplication: true)
    }
}
#endif

import SwiftUI

extension WatchCooldown {
    /// 남은 시간 글자. 하루 넘게 남으면 날 · 시간("1일 19시간" — 시계 글자로는 "43:11:54" 가 되어 읽히지 않는다),
    /// 하루 안이면 시스템이 초까지 세는 시계. `units` 가 1 이면 날만 올림으로("2일").
    func remaining(at now: Date, units: Int = 2) -> Text {
        guard let end = endsAt, end > now else { return Text(verbatim: "") }
        let left = end.timeIntervalSince(now)
        guard left > 86_400 else { return Text(timerInterval: now...end, countsDown: true) }
        return Text(Duration.seconds(left), format: .units(allowed: [.days, .hours], width: .narrow,
                                                           maximumUnitCount: units, fractionalPart: .hide(rounded: .up)))
    }
}
