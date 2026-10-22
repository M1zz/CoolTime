import SwiftUI
import SwiftData
import WidgetKit
import LeeoKit

@main
struct CoolTimeApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CooldownItem.self,
        ])
        // 앱 데이터는 기기에만 둔다. entitlements 의 iCloud 컨테이너(FeedbackHub)는 피드백 전송용이라,
        // 지정하지 않으면 SwiftData 가 그 컨테이너로 CloudKit 동기화를 켜려다 스키마 검사에서 실패한다.
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            #if DEBUG
            ScreenshotSeed.applyIfRequested(to: container)
            #endif
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // 알림 카테고리 설정
        NotificationManager.shared.setupNotificationCategories()
        // 앱 실행 등록(리뷰/만족도 프롬프트 게이팅) · 크래시 진단 · 익명 사용 통계 (FeedbackHub)
        LeeoKit.bootstrap(CoolTimeSpec.self)
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .leeoSatisfactionCheck(CoolTimeSpec.self)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // 앱이 활성화되면 뱃지 초기화
                NotificationManager.shared.clearBadge()
                // 위젯 리프레시
                WidgetCenter.shared.reloadAllTimelines()
            case .background:
                // 백그라운드로 가면 위젯 업데이트
                WidgetCenter.shared.reloadAllTimelines()
            default:
                break
            }
        }
    }
}

#if DEBUG
/// 스토어 스크린샷용 예시 데이터 — `-screenshotSeed` 로 켰을 때만, 디버그 빌드에서만 쓴다.
/// 이름은 템플릿 이름(카탈로그에 있는 말)을 써서 기기 언어로 나온다. scripts/capture_screenshots.sh 가 켠다.
/// `-screenshotScreen break|stats|templates` 를 같이 주면 그 화면을 열고 시작한다(HomeView).
enum ScreenshotSeed {
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-screenshotSeed") }

    static var screen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screenshotScreen"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func applyIfRequested(to container: ModelContainer) {
        guard isOn else { return }
        let context = ModelContext(container)
        try? context.delete(model: CooldownItem.self)
        let day: TimeInterval = 86400
        // (이름, 이모지, 주기, 비용, 카테고리, 사용, 깬 횟수, 마지막 사용이 몇 초 전)
        let rows: [(String, String, TimeInterval, Int, String, Int, Int, TimeInterval)] = [
            (String(localized: "옷 쇼핑"), "👕", .weeks(3), 80000, TemplateCategory.shopping.rawValue, 6, 1, 3600),
            (String(localized: "해외여행"), "✈️", .days(120), 1500000, TemplateCategory.travel.rawValue, 3, 0, 2 * day - 30),
            (String(localized: "택시"), "🚕", .weeks(1), 15000, "기타", 13, 3, 2 * day - 5 * 3600),
            (String(localized: "배달음식"), "🍔", .days(3), 25000, TemplateCategory.food.rawValue, 15, 1, day + 7 * 3600),
            (String(localized: "네일아트"), "💅", .weeks(4), 60000, TemplateCategory.lifestyle.rawValue, 4, 0, 31 * day),
            (String(localized: "게임 과금"), "🎮", .weeks(2), 30000, TemplateCategory.entertainment.rawValue, 5, 0, 20 * day),
            (String(localized: "디저트"), "🍰", .days(2), 7000, TemplateCategory.food.rawValue, 17, 2, 6 * 3600),
        ]
        let now = Date()
        for (index, row) in rows.enumerated() {
            let item = CooldownItem(name: row.0, emoji: row.1, cooldownDuration: row.2, estimatedCost: row.3, category: row.4)
            item.createdAt = now.addingTimeInterval(-Double(index + 1) * day)  // 위 순서대로 화면에 나온다
            let last = now.addingTimeInterval(-row.7)
            item.usageHistory = (0..<row.5).map { n in
                UsageRecord(date: last.addingTimeInterval(-Double(n) * row.2), note: nil, cost: row.3, brokeCooldown: n >= row.5 - row.6)
            }
            item.totalUseCount = row.5
            item.breakCount = row.6
            item.lastUsedDate = last
            context.insert(item)
        }
        try? context.save()
    }
}
#endif
