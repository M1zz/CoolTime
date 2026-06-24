//
//  CoolTimeIntents.swift
//  CoolTime
//
//  능동 개입의 토대 — App Intents.
//  "지금 사도 돼?"를 Siri/Spotlight/단축어에서 호출하고,
//  "배달앱 열면 → 사도 돼?" 자동화로 충동의 순간에 개입한다.
//

import AppIntents
import WidgetKit

// MARK: - 항목 엔티티 (인텐트 파라미터로 노출)

struct CooldownEntity: AppEntity {
    let id: UUID
    let name: String
    let emoji: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "쿨타임 항목"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)")
    }

    static var defaultQuery = CooldownQuery()
}

struct CooldownQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CooldownEntity] {
        loadAll().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CooldownEntity] {
        loadAll()
    }

    private func loadAll() -> [CooldownEntity] {
        WidgetDataStore.loadItems().map {
            CooldownEntity(id: $0.id, name: $0.name, emoji: $0.emoji)
        }
    }
}

// MARK: - "지금 사도 돼?" (읽기 전용 개입)

struct CheckUrgeIntent: AppIntent {
    static var title: LocalizedStringResource = "지금 사도 돼?"
    static var description = IntentDescription("충동구매 전에 쿨타임이 남았는지 확인해요.")
    static var openAppWhenRun = false

    @Parameter(title: "항목")
    var item: CooldownEntity?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let items = WidgetDataStore.loadItems()
        let stats = WidgetDataStore.loadStats()

        // 대상: 지정 항목 → 없으면 돈 가장 많이 걸린 대기 항목 → 없으면 아무거나
        let target: WidgetCooldownItem? = {
            if let item { return items.first { $0.id == item.id } }
            let waiting = items.filter { $0.isOnCooldown }
            return waiting.max { ($0.estimatedCost ?? 0) < ($1.estimatedCost ?? 0) } ?? items.first
        }()

        guard let t = target else {
            return .result(dialog: "아직 등록된 쿨타임이 없어요.")
        }

        if t.isOnCooldown {
            let left = t.remainingCooldown.widgetFormatted
            let cost = t.estimatedCost.map { "지금 사면 \($0.formatted())원이에요. " } ?? ""
            let saved = stats.monthlySavings > 0
                ? "이번 달 벌써 \(stats.monthlySavings.formatted())원 아꼈어요. "
                : ""
            return .result(dialog: "아직이에요. \(t.name)은 \(left) 남았어요. \(cost)\(saved)한 번만 더 참아봐요.")
        } else {
            return .result(dialog: "\(t.name)은 지금 해도 돼요. 그래도 정말 필요한지 한 번 더 생각해봐요.")
        }
    }
}

// MARK: - "샀어요" (기록 + 쿨타임 재시작)

struct LogPurchaseIntent: AppIntent {
    static var title: LocalizedStringResource = "샀어요 기록"
    static var description = IntentDescription("구매를 기록하고 쿨타임을 다시 시작해요.")
    static var openAppWhenRun = false

    @Parameter(title: "항목")
    var item: CooldownEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        WidgetDataStore.recordPurchase(itemId: item.id)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "\(item.name) 기록했어요. 쿨타임을 다시 시작할게요.")
    }
}

// MARK: - Siri/Spotlight/단축어 등록

struct CoolTimeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckUrgeIntent(),
            phrases: [
                "\(.applicationName) 사도 돼",
                "\(.applicationName)에서 사도 돼?",
                "지금 사도 돼 \(.applicationName)"
            ],
            shortTitle: "사도 돼?",
            systemImageName: "hand.raised.fill"
        )
        AppShortcut(
            intent: LogPurchaseIntent(),
            phrases: [
                "\(.applicationName)에 샀어요",
                "\(.applicationName) 샀어"
            ],
            shortTitle: "샀어요 기록",
            systemImageName: "checkmark.circle.fill"
        )
    }
}
