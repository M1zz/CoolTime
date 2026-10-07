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
}
