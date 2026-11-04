//
//  CoolTimeIntents.swift
//  CoolTime
//
//  Siri · 단축어로 묻고, 남기고, 건다.
//   - "쿨타임, 커피 써도 돼?": 남은 대기 시간을 알려 준다.
//   - "쿨타임, 커피 썼어": 사용을 남긴다. 아직 쿨타임 중이면 정말 남길지 한 번 묻는다.
//   - "쿨타임에 새 항목 추가": 이름과 대기 일수로 새 항목을 만든다(앱처럼 처음 쓸 때부터 돈다).
//   - Spotlight: 항목 이름이 색인돼 Siri 도 찾는다. 누르면 그 항목의 사용 화면이 열린다.
//

import AppIntents
import CoreSpotlight
import Foundation
import SwiftData

struct CooldownItemEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("쿨타임 항목", comment: "Siri: one item with a cooldown")
    )
    static let defaultQuery = CooldownItemQuery()

    let id: UUID
    let name: String
    let emoji: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)")
    }

    init(_ item: CooldownItem) {
        id = item.id
        name = item.name
        emoji = item.emoji
    }
}

extension CooldownItemEntity: IndexedEntity {}

struct CooldownItemQuery: EntityStringQuery {
    @Dependency private var container: ModelContainer

    func entities(for identifiers: [UUID]) async throws -> [CooldownItemEntity] {
        let wanted = Set(identifiers)
        return CoolTimeLibrary.items(in: container).filter { wanted.contains($0.id) }.map(CooldownItemEntity.init)
    }

    func entities(matching string: String) async throws -> [CooldownItemEntity] {
        CoolTimeLibrary.items(in: container).filter { $0.name.localizedCaseInsensitiveContains(string) }.map(CooldownItemEntity.init)
    }

    func suggestedEntities() async throws -> [CooldownItemEntity] {
        CoolTimeLibrary.items(in: container).map(CooldownItemEntity.init)
    }
}

/// 써도 되는지 묻는다.
struct CheckCooldownIntent: AppIntent {
    static let title = LocalizedStringResource("써도 될까?", comment: "Siri: ask whether an item's cooldown is over")
    static let description = IntentDescription(
        LocalizedStringResource("그 항목의 쿨타임이 얼마나 남았는지 알려 줍니다.", comment: "Siri: check cooldown description")
    )

    @Parameter(title: LocalizedStringResource("항목", comment: "Siri: item parameter"),
               description: LocalizedStringResource("남은 쿨타임을 확인할 항목", comment: "Siri: check cooldown item parameter description"),
               requestValueDialog: IntentDialog(LocalizedStringResource("어떤 항목인가요?", comment: "Siri: ask which item")))
    var item: CooldownItemEntity

    @Dependency private var container: ModelContainer

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let found = CoolTimeLibrary.item(item.id, in: container) else {
            return .result(dialog: IntentDialog(LocalizedStringResource("그 항목을 찾지 못했어요.", comment: "Siri: item not found")))
        }
        guard found.isOnCooldown else {
            return .result(dialog: IntentDialog(LocalizedStringResource("\(found.name), 이제 써도 돼요.", comment: "Siri: cooldown over. Argument is the item name")))
        }
        let left = CoolTimeLibrary.spoken(found.remainingCooldown)
        return .result(dialog: IntentDialog(LocalizedStringResource("\(found.name)은 아직 \(left) 남았어요.", comment: "Siri: still cooling down. Arguments: item name, time left")))
    }
}

/// 사용을 남긴다. 쿨타임 중이면 깨는 것이니 한 번 확인한다.
struct UseItemIntent: AppIntent {
    static let title = LocalizedStringResource("썼어요", comment: "Siri: record that an item was used")
    static let description = IntentDescription(
        LocalizedStringResource("사용을 남기고 쿨타임을 다시 시작합니다.", comment: "Siri: use item description")
    )

    @Parameter(title: LocalizedStringResource("항목", comment: "Siri: item parameter"),
               description: LocalizedStringResource("방금 쓴 항목", comment: "Siri: use item parameter description"),
               requestValueDialog: IntentDialog(LocalizedStringResource("어떤 항목인가요?", comment: "Siri: ask which item")))
    var item: CooldownItemEntity

    init() {}

    init(item: CooldownItemEntity) {
        self.item = item
    }

    @Dependency private var container: ModelContainer

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(container)
        guard let found = try? context.fetch(FetchDescriptor<CooldownItem>()).first(where: { $0.id == item.id }) else {
            return .result(dialog: IntentDialog(LocalizedStringResource("그 항목을 찾지 못했어요.", comment: "Siri: item not found")))
        }
        let breaking = found.isOnCooldown
        if breaking {
            let left = CoolTimeLibrary.spoken(found.remainingCooldown)
            try await requestConfirmation(dialog: IntentDialog(LocalizedStringResource("아직 \(left) 남았어요. 그래도 남길까요?", comment: "Siri: confirm breaking the cooldown. Argument is time left")))
        }
        found.use(brokeRule: breaking)
        try context.save()
        NotificationManager.shared.scheduleNotificationsForItem(
            itemId: found.id, name: found.name, emoji: found.emoji, cooldownDuration: found.cooldownDuration
        )
        let next = CoolTimeLibrary.spoken(found.cooldownDuration)
        return .result(dialog: IntentDialog(LocalizedStringResource("남겼어요. 다음은 \(next) 뒤예요.", comment: "Siri: use recorded. Argument is the cooldown length")))
    }
}

/// 새 쿨타임을 건다.
struct AddCooldownIntent: AppIntent {
    static let title = LocalizedStringResource("쿨타임 걸기", comment: "Siri: add a new cooldown item")
    static let description = IntentDescription(
        LocalizedStringResource("이름과 대기 일수로 새 항목을 만듭니다.", comment: "Siri: add cooldown description")
    )

    @Parameter(title: LocalizedStringResource("이름", comment: "Siri: item name parameter"),
               description: LocalizedStringResource("쿨타임을 걸 대상의 이름", comment: "Siri: add cooldown name parameter description"),
               requestValueDialog: IntentDialog(LocalizedStringResource("무엇에 쿨타임을 걸까요?", comment: "Siri: ask item name")))
    var name: String

    @Parameter(title: LocalizedStringResource("대기 일수", comment: "Siri: cooldown days parameter"),
               description: LocalizedStringResource("한 번 쓰고 다시 쓸 때까지 기다릴 날수", comment: "Siri: add cooldown days parameter description"),
               default: 7,
               inclusiveRange: (1, 365))
    var days: Int

    @Dependency private var container: ModelContainer

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw $name.needsValueError(IntentDialog(LocalizedStringResource("무엇에 쿨타임을 걸까요?", comment: "Siri: ask item name")))
        }
        let context = ModelContext(container)
        // 앱에서 추가할 때와 같다. 쿨타임은 처음 쓸 때부터 돈다.
        context.insert(CooldownItem(name: trimmed, emoji: "⏳", cooldownDuration: TimeInterval(days) * 86_400))
        try context.save()
        return .result(dialog: IntentDialog(LocalizedStringResource("\(trimmed)을 \(days)일 쿨타임으로 추가했어요.", comment: "Siri: item added. Arguments: name, days")))
    }
}

/// 항목을 연다. Spotlight · Siri 결과를 누르면 여기로 와서 그 항목의 사용 화면이 뜬다.
struct OpenCooldownItemIntent: OpenIntent {
    static let title = LocalizedStringResource("항목 열기", comment: "Siri/Spotlight: open a cooldown item")
    static let description = IntentDescription(
        LocalizedStringResource("앱에서 그 항목을 열어 사용을 남길 수 있게 합니다.", comment: "Siri: open item description")
    )

    @Parameter(title: LocalizedStringResource("항목", comment: "Siri: item parameter"),
               description: LocalizedStringResource("열 항목", comment: "Siri: open item parameter description"))
    var target: CooldownItemEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        CoolTimeRouter.shared.openItemID = target.id
        return .result()
    }
}

/// 인텐트가 화면에 부탁하는 것. HomeView 가 보고 그 항목을 연다.
@MainActor @Observable
final class CoolTimeRouter {
    static let shared = CoolTimeRouter()
    var openItemID: UUID?
}

struct CoolTimeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckCooldownIntent(),
            phrases: [
                "Can I use \(\.$item) in \(.applicationName)",
                "Check \(.applicationName)"
            ],
            shortTitle: "Check Cooldown",
            systemImageName: "hourglass"
        )
        AppShortcut(
            intent: UseItemIntent(),
            phrases: [
                "I used \(\.$item) in \(.applicationName)",
                "Log a use in \(.applicationName)"
            ],
            shortTitle: "Log a Use",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: AddCooldownIntent(),
            phrases: [
                "Add a cooldown in \(.applicationName)",
                "New \(.applicationName) item"
            ],
            shortTitle: "Add Cooldown",
            systemImageName: "plus.circle"
        )
    }
}

enum CoolTimeLibrary {
    static func items(in container: ModelContainer) -> [CooldownItem] {
        ((try? ModelContext(container).fetch(FetchDescriptor<CooldownItem>())) ?? []).filter(\.isActive)
    }

    static func item(_ id: UUID, in container: ModelContainer) -> CooldownItem? {
        items(in: container).first { $0.id == id }
    }

    /// Spotlight 에 싣는 항목을 지금 것에 맞춘다. 앱을 열 때와 뒤로 보낼 때 부른다.
    static func reindex(_ container: ModelContainer) async {
        let index = CSSearchableIndex.default()
        try? await index.deleteAppEntities(ofType: CooldownItemEntity.self)
        try? await index.indexAppEntities(items(in: container).map(CooldownItemEntity.init))
    }

    /// 앱에서 쓴 것을 Siri 에 알린다. 다음에 "썼어" 를 고르기 쉬워진다.
    static func donateUse(of item: CooldownItem) {
        IntentDonationManager.shared.donate(intent: UseItemIntent(item: CooldownItemEntity(item)))
    }

    /// "3일 4시간" 처럼 읽히는 남은 시간. 기기 언어로 적는다.
    static func spoken(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = interval >= 86_400 ? [.day, .hour] : [.hour, .minute]
        return formatter.string(from: max(interval, 60)) ?? ""
    }
}
