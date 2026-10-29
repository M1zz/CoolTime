import Foundation
import LeeoKit

enum CoolTimeSpec: LeeoAppSpec {
    static let appName = "쿨타임"
    static let developerEmail = "mizzking75@gmail.com"
    static let feedback = LeeoFeedbackConfig(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub", appIdentifier: "com.Ysoup.CoolTime")

    /// 개인정보 처리방침·지원·소개 페이지 (docs/ 를 GitHub Pages 로 서빙).
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/CoolTime/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/CoolTime/support.html")!,
        marketingURL: URL(string: "https://m1zz.github.io/CoolTime/")!
    )

    /// 결제 없음 — 앱 안에 StoreKit·페이월 코드가 존재하지 않는다.
    static let monetization = LeeoMonetization.free

    /// App Store 앱 ID — 리뷰 링크 · 친구에게 소개하기에 쓴다.
    static var appStoreID: String? { "6755988507" }

    /// 익명 사용 통계 → FeedbackHub. 없으면 bootstrap 이 스냅샷·app_open 을 건너뛴다.
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: CoolTimeSpec.self)
}

// MARK: - 팁 (개발자 응원하기)

/// 무료 앱이라 LeeoStore 가 없다. 팁 엔진을 여기 하나 두고, 앱을 열 때 `startStandalone()` 을 부른다.
@MainActor
enum CoolTimeTip {
    static let tipJar = LeeoTipJar(config: LeeoTipJarConfig(productIDs: [
        "com.Ysoup.CoolTime.tip.small",
        "com.Ysoup.CoolTime.tip.medium",
        "com.Ysoup.CoolTime.tip.large",
    ]))
}

/// 팁을 부탁할 만한 순간 — 쿨타임을 **깨지 않고** 기다렸다 쓴 횟수(아이템마다 첫 사용은 기다린 게 아니라 뺀다). 큰 것부터.
enum CoolTimeTipMoments {
    static let kept = [100, 30, 10]

    static func reached(keptCount n: Int) -> [LeeoTipMoment] {
        kept.filter { n >= $0 }.map { threshold in
            LeeoTipMoment(id: "kept.\(threshold)",
                          message: String(localized: "지금까지 쿨타임을 \(n)번 지켜 냈어요",
                                          comment: "Tip ask card: how many times the person waited out a cooldown before using again"))
        }
    }

    static func reachedNow(in items: [CooldownItem]) -> [LeeoTipMoment] {
        reached(keptCount: items.reduce(0) { $0 + max(0, $1.totalUseCount - $1.breakCount - 1) })
    }
}
