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
