import SwiftUI
import SwiftData
import AppIntents
import WidgetKit
import LeeoKit

@main
struct CoolTimeApp: App {
    @Environment(\.scenePhase) private var scenePhase

    /// `static let` 이라 처음 꺼낼 때 열린다 — init 에서 금고(bootstrap 안)가 예약된 복원을 적용한 뒤다.
    private static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CooldownItem.self,
        ])
        // 1. 사용자의 iCloud(앱 자체 컨테이너의 개인 데이터베이스). 기기에 있던 기록은 그대로 올라가고,
        //    새 기기는 계정에 있던 것을 받아 온다. 컨테이너를 이름으로 못박는다 — 비워 두면(.automatic)
        //    entitlements 의 첫 컨테이너(FeedbackHub, 피드백 전송용)로 가려다 스키마 검사에서 실패한다.
        if let synced = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudContainer))
        ) {
            usesCloud = true
            #if DEBUG
            ScreenshotSeed.applyIfRequested(to: synced)
            #endif
            return synced
        }
        // 2. 같은 파일을 기기 안에서만. entitlement 가 없거나 컨테이너가 아직 없는 빌드도 기록은 잃지 않는다.
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
            return StoreFallback.memoryContainer(schema: schema, after: error)
        }
    }()

    /// 앱 자체 iCloud 컨테이너. entitlements 에 이 이름이 있어야 1 단계가 열린다.
    static let cloudContainer = "iCloud.com.Ysoup.CoolTime"
    /// 이번 실행이 iCloud 와 이어져 열렸는가 (sharedModelContainer 가 한 번 정한다).
    private(set) static var usesCloud = false

    init() {
        #if DEBUG
        CloudKitSchemaWarmup.runIfRequested(Self.sharedModelContainer, cloudContainer: Self.cloudContainer) {
            [CooldownItem(name: "표본", emoji: "🧊", cooldownDuration: 60)]
        }
        #endif
        // 백업 금고 · 앱 실행 등록(리뷰/만족도 프롬프트 게이팅) · 크래시 진단 · 익명 사용 통계 (FeedbackHub).
        // 금고가 예약된 복원을 적용해야 하므로 저장소보다 먼저 켠다.
        LeeoKit.bootstrap(CoolTimeSpec.self)
        // 알림 카테고리 설정
        NotificationManager.shared.setupNotificationCategories()
        // Siri · 단축어가 같은 저장소를 쓰게 한다 (→ CoolTimeIntents.swift)
        let container = Self.sharedModelContainer
        AppDependencyManager.shared.add(dependency: container)
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .leeoSatisfactionCheck(CoolTimeSpec.self)
                // 개발자가 보낸 의견에 답장하면, 앱이 앞으로 올 때 답장을 시트로 보여 준다 (LeeoKit).
                .leeoFeedbackReplyNotice(CoolTimeSpec.self)
                .storeFallbackNotice()
                // 산 칸을 영수증으로 다시 읽는다(팁 엔진도 스토어가 함께 깨운다).
                .task { await PurchaseManager.shared.refresh() }
                // 창 크기로 접힘을 재서 아래로 흘린다. 시트 · 알림창도 접힌 선을 비킨다 (LeeoKit Fold).
                .foldAware()
        }
        .modelContainer(Self.sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // 앱이 활성화되면 뱃지 초기화
                NotificationManager.shared.clearBadge()
                // 위젯 리프레시
                #if !os(visionOS)   // visionOS 2 에는 위젯이 없다 — 위젯 확장은 iOS 에만 묶여 있다
                WidgetCenter.shared.reloadAllTimelines()
                #endif
                Task { await CoolTimeLibrary.reindex(Self.sharedModelContainer) }
                // 다른 기기에서 샀거나 구독이 끝났을 수 있다.
                Task { await PurchaseManager.shared.refresh() }
            case .background:
                // 백그라운드로 가면 위젯 업데이트
                #if !os(visionOS)   // visionOS 2 에는 위젯이 없다 — 위젯 확장은 iOS 에만 묶여 있다
                WidgetCenter.shared.reloadAllTimelines()
                #endif
                Task { await CoolTimeLibrary.reindex(Self.sharedModelContainer) }
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

// MARK: - 저장소를 못 연 날
//
// 예전에는 fatalError 로 죽었다. 그러면 마이그레이션 한 번 어긋난 사용자는 켤 때마다 죽고,
// 기기 안에 멀쩡히 있는 기록도 못 본다. 이제는 디스크의 기록은 건드리지 않고 이번 실행만
// 메모리에서 열고, 사용자에게 그 사실을 알린다.

enum StoreFallback {
    /// 이번 실행이 임시(메모리) 저장소로 열렸는가
    private(set) static var isActive = false

    static func memoryContainer(schema: Schema, after error: Error) -> ModelContainer {
        isActive = true
        print("⚠️ 저장소를 열지 못해 이번 실행은 메모리에서 엽니다: \(error)")
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            )
        } catch {
            // 메모리 저장소마저 안 되는 건 스키마 자체가 잘못된 것 — 개발 중에 바로 드러난다
            fatalError("메모리 저장소도 열지 못함: \(error)")
        }
    }
}

extension View {
    /// 임시 저장소로 열렸으면 한 번 알린다. 앱의 맨 바깥 화면에 붙인다.
    func storeFallbackNotice() -> some View {
        modifier(StoreFallbackNotice())
    }
}

private struct StoreFallbackNotice: ViewModifier {
    @State private var isPresented = StoreFallback.isActive

    func body(content: Content) -> some View {
        content.alert("기록을 열지 못했어요", isPresented: $isPresented) {
        } message: {
            Text("저장된 기록은 지워지지 않았어요. 다만 지금 적는 내용은 저장되지 않으니, 앱을 껐다 켜 보세요.")
        }
    }
}
