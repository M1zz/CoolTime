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
        // 알림 카테고리 설정
        NotificationManager.shared.setupNotificationCategories()
        // 앱 실행 등록 (리뷰/만족도 프롬프트 게이팅용)
        LeeoEngagement.shared.registerLaunch()
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
