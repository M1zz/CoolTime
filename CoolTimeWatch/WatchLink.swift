//
//  WatchLink.swift
//  워치 쪽 아이폰 연결. 목록을 받아 두고, [썼어요] 를 보낸다.
//

import Foundation
import WatchConnectivity
import WidgetKit
import WatchKit

@MainActor
final class WatchLink: NSObject, ObservableObject {
    static let shared = WatchLink()

    @Published private(set) var snapshot: WatchSnapshot? = WatchStore.load()

    func activate() {
        guard WCSession.isSupported(), WCSession.default.activationState != .activated else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// '방금 썼다' 를 아이폰으로. 가까우면 바로, 멀면 가까워질 때 전해진다.
    /// 화면은 기다리지 않고 바로 새 쿨타임을 보여 준다 — 아이폰이 기록한 목록이 오면 그것으로 바뀐다.
    func use(_ item: WatchCooldown) {
        WKInterfaceDevice.current().play(.success)
        if var s = snapshot, let i = s.items.firstIndex(where: { $0.id == item.id }) {
            s.items[i].lastUsed = .now
            apply(s)
        }
        activate()
        let message = [CoolTimeWatchKeys.use: item.id.uuidString]
        let wc = WCSession.default
        if wc.activationState == .activated, wc.isReachable {
            wc.sendMessage(message, replyHandler: nil) { _ in wc.transferUserInfo(message) }
        } else {
            wc.transferUserInfo(message)
        }
    }

    fileprivate func apply(_ new: WatchSnapshot) {
        WatchStore.save(new)
        guard new != snapshot else { return }
        snapshot = new
        WidgetCenter.shared.reloadAllTimelines()
    }

    nonisolated fileprivate func receive(_ context: [String: Any]) {
        guard let new = CoolTimeWatchKeys.decode(context[CoolTimeWatchKeys.snapshot] as? Data) else { return }
        Task { @MainActor in self.apply(new) }
    }
}

extension WatchLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        receive(session.receivedApplicationContext)
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        receive(context)
    }
}
