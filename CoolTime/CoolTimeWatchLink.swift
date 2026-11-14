//
//  CoolTimeWatchLink.swift
//  아이폰 ↔ 애플워치가 함께 쓰는 말. 워치 앱 · 워치 컴플리케이션에도 같은 파일이 들어간다.
//
//  아이폰은 항목이 바뀔 때마다 목록 전체(이름 · 이모지 · 쿨타임 · 마지막 사용)를 보낸다.
//  남은 시간은 워치가 혼자 센다 — 폰이 멀어져도 손목의 숫자는 맞다.
//  워치에서 [썼어요] 를 누르면 그 항목 id 만 아이폰으로 간다. 기록은 아이폰이 한다(Siri '썼어요' 와 같은 길).
//

import Foundation

struct WatchCooldown: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var emoji: String
    var duration: TimeInterval
    var lastUsed: Date?

    var endsAt: Date? { lastUsed.map { $0.addingTimeInterval(duration) } }
    func isCooling(at date: Date = .now) -> Bool { (endsAt ?? .distantPast) > date }
}

struct WatchSnapshot: Codable, Equatable {
    var items: [WatchCooldown]
    /// 위젯 · 컴플리케이션을 여는 칸인가 (아이폰 위젯과 같은 기준 → WidgetDataStore.unlocksWidget)
    var unlocksComplication: Bool

    /// 쿨타임 중인 것 먼저(곧 끝나는 순), 그다음 지금 써도 되는 것(이름순)
    var sorted: [WatchCooldown] {
        let now = Date.now
        let cooling = items.filter { $0.isCooling(at: now) }.sorted { $0.endsAt! < $1.endsAt! }
        let ready = items.filter { !$0.isCooling(at: now) }.sorted { $0.name < $1.name }
        return cooling + ready
    }

    /// 그 시각 이후 가장 먼저 끝나는 쿨타임
    func soonest(after date: Date) -> WatchCooldown? {
        items.filter { $0.isCooling(at: date) }.min { $0.endsAt! < $1.endsAt! }
    }
}

enum CoolTimeWatchKeys {
    static let snapshot = "snapshot"
    static let use = "use"

    static func encode(_ s: WatchSnapshot) -> Data? { try? JSONEncoder().encode(s) }
    static func decode(_ d: Data?) -> WatchSnapshot? { d.flatMap { try? JSONDecoder().decode(WatchSnapshot.self, from: $0) } }
}
