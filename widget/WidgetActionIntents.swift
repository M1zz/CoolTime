//
//  WidgetActionIntents.swift
//  CoolTime Widget
//
//  위젯의 인터랙티브 버튼용 인텐트. 앱 안 열고 위젯에서 바로
//  "참았어요"/"샀어요"를 기록한다(공유 큐 → 앱이 다음 실행 때 반영).
//

import AppIntents
import WidgetKit

struct ResistIntent: AppIntent {
    static var title: LocalizedStringResource = "참았어요"
    static var description = IntentDescription("충동을 이겨낸 것을 기록해요.")

    @Parameter(title: "itemId")
    var itemId: String

    init() {}
    init(itemId: String) { self.itemId = itemId }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: itemId) {
            WidgetDataStore.recordResist(itemId: id)
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}

struct BuyIntent: AppIntent {
    static var title: LocalizedStringResource = "샀어요"
    static var description = IntentDescription("구매를 기록하고 쿨타임을 다시 시작해요.")

    @Parameter(title: "itemId")
    var itemId: String

    init() {}
    init(itemId: String) { self.itemId = itemId }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: itemId) {
            WidgetDataStore.recordPurchase(itemId: id)
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}
