//
//  PhoneWatchLink.swift
//  아이폰 쪽 워치 연결. 목록을 손목으로 보내고, 손목에서 온 [썼어요] 를 기록한다.
//  (워치가 짝지어 있지 않으면 아무것도 하지 않는다. 아이패드 · visionOS 에는 워치가 없다.)
//

#if os(iOS)
import Foundation
import SwiftData
import WatchConnectivity

@MainActor
final class PhoneWatchLink: NSObject {
    static let shared = PhoneWatchLink()
    private var container: ModelContainer?

    func activate(_ container: ModelContainer) {
        self.container = container
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// 지금 목록을 손목으로. 같은 내용이면 시스템이 알아서 거른다(applicationContext 는 마지막 하나만 남는다).
    func push(_ items: [WidgetCooldownItem]) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        let snapshot = WatchSnapshot(
            items: items.map { WatchCooldown(id: $0.id, name: $0.name, emoji: $0.emoji,
                                             duration: $0.cooldownDuration, lastUsed: $0.lastUsedDate) },
            unlocksComplication: WidgetDataStore.unlocksWidget)
        guard let data = CoolTimeWatchKeys.encode(snapshot) else { return }
        try? WCSession.default.updateApplicationContext([CoolTimeWatchKeys.snapshot: data])
    }

    /// 저장소에 있는 그대로 다시 보낸다 (손목에서 쓴 직후 · 처음 이어졌을 때)
    func pushAll() {
        guard let container else { return }
        let items = (try? container.mainContext.fetch(FetchDescriptor<CooldownItem>())) ?? []
        push(items.map {
            WidgetCooldownItem(id: $0.id, name: $0.name, emoji: $0.emoji, cooldownDuration: $0.cooldownDuration,
                               lastUsedDate: $0.lastUsedDate, estimatedCost: $0.estimatedCost, category: $0.category)
        })
    }

    /// 손목의 [썼어요] — Siri '썼어요'(UseItemIntent)와 같은 기록. 쿨타임 중이었으면 깬 것으로 센다(워치가 한 번 물었다).
    private func use(_ id: UUID) {
        guard let container,
              let item = try? container.mainContext.fetch(FetchDescriptor<CooldownItem>()).first(where: { $0.id == id })
        else { return }
        item.use(brokeRule: item.isOnCooldown)
        try? container.mainContext.save()
        NotificationManager.shared.scheduleNotificationsForItem(
            itemId: item.id, name: item.name, emoji: item.emoji, cooldownDuration: item.cooldownDuration)
        pushAll()
    }

    nonisolated private func handle(_ info: [String: Any]) {
        guard let raw = info[CoolTimeWatchKeys.use] as? String, let id = UUID(uuidString: raw) else { return }
        Task { @MainActor in self.use(id) }
    }
}

extension PhoneWatchLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        guard state == .activated else { return }
        Task { @MainActor in self.pushAll() }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.pushAll() }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { handle(message) }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) { handle(userInfo) }
}
#endif
