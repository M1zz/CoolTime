import SwiftUI
import SwiftData
import WidgetKit

@main
struct CoolTimeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var purchaseManager = PurchaseManager.shared
    // 화면 생명주기와 무관하게, 앱 활성/백그라운드 전환 때마다 저장소→위젯 동기화
    @State private var widgetSync = CooldownManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CooldownItem.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        NotificationManager.shared.setupNotificationCategories()
        _ = PurchaseManager.shared
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(purchaseManager)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                NotificationManager.shared.clearBadge()
                // 저장소에서 항목을 다시 읽어 위젯 데이터 기록 + 리프레시
                widgetSync.setModelContext(sharedModelContainer.mainContext)
            case .background:
                widgetSync.setModelContext(sharedModelContainer.mainContext)
            default:
                break
            }
        }
    }
}
