//
//  ProPlan.swift
//  CoolTime
//
//  쿨타임의 세 칸 — 무료 · Plus · Pro. **무엇이 어느 칸에서 열리는지는 여기 한 곳에만 적는다.**
//  페이월 · 비교표 · 잠긴 자리 · 위젯이 모두 이 목록을 읽는다.
//
//   · 무료: 쿨타임 아이템 5개, 추천 템플릿, 깨기 전 경고 · 메모 · 비용, 끝 알림, 전체 준수율 · 아낀 금액 · 사용 기록, CSV 내보내기
//   · Plus: 아이템 무제한, 절반 응원 알림
//   · Pro:  Plus 전부 + 홈 · 잠금화면 위젯, 아이템별 · 카테고리별 준수율, 최근 활동 흐름
//
//  ⚠️ 잠그지 않는 것: 이미 만든 아이템 보기 · 쓰기 · 지우기, 기록 내보내기, 깨기 전 경고. 무료 한도를 넘겨
//     가진 아이템(예전 버전 · Siri 로 만든 것)도 그대로 쓴다. 막는 것은 **새로 거는 일** 하나다.
//

import Foundation

/// 칸. 값이 클수록 더 많이 연다. Pro 는 Plus 를 전부 포함한다.
/// ⚠️ rawValue 는 위젯과 나누는 값이다(`WidgetDataStore.saveTier`). 바꾸지 않는다.
enum ProTier: Int, Comparable, CaseIterable {
    case free = 0
    case plus = 1
    case pro = 2

    static func < (lhs: ProTier, rhs: ProTier) -> Bool { lhs.rawValue < rhs.rawValue }

    /// 유료 칸.
    static let paid: [ProTier] = [.plus, .pro]

    var title: String {
        switch self {
        case .free: String(localized: "무료", comment: "Plan name: free tier")
        case .plus: "Plus"
        case .pro:  "Pro"
        }
    }

    /// 칸 한 줄.
    var tagline: String {
        switch self {
        case .free: String(localized: "지르고 싶은 것 다섯 개에 쿨타임 걸기", comment: "Paywall: one line about the free plan")
        case .plus: String(localized: "참고 싶은 것 모두에 쿨타임", comment: "Paywall: one line about Plus")
        case .pro:  String(localized: "앱을 안 열어도 보이고, 숫자로 돌아보기", comment: "Paywall: one line about Pro (widgets and detailed stats)")
        }
    }
}

extension ProTier: Identifiable {
    var id: Int { rawValue }
}

/// 값을 받고 여는 것.
enum ProFeature: String, CaseIterable, Identifiable {
    /// 6번째 아이템부터.
    case unlimitedItems
    /// 쿨타임 절반에 "반 왔어요" 알림.
    case halfwayCheer
    /// 아이템별 · 카테고리별 준수율, 최근 활동 흐름.
    case insights
    /// 홈 · 잠금화면 위젯.
    case widgets

    var id: String { rawValue }

    /// 무료로 걸 수 있는 아이템 수.
    static let freeItemLimit = 5

    /// 이 기능을 여는 가장 낮은 칸.
    var tier: ProTier {
        switch self {
        case .unlimitedItems, .halfwayCheer: .plus
        case .insights, .widgets:            .pro
        }
    }
}

// MARK: - 비교표 (페이월에 그대로)

/// 페이월 비교표 한 줄. 무료 · Plus · Pro 칸에 무엇이 서는지.
struct PlanComparisonRow: Identifiable {
    enum Cell { case yes, no, text(String) }

    let title: String
    let free: Cell
    let plus: Cell
    let pro: Cell
    var id: String { title }

    static var all: [PlanComparisonRow] {
        let unlimited = String(localized: "무제한", comment: "Paywall comparison: no limit on items")
        return [
            .init(title: String(localized: "쿨타임 아이템", comment: "Paywall comparison row: number of cooldown items"),
                  free: .text(String(localized: "\(ProFeature.freeItemLimit)개", comment: "Paywall comparison: free item limit, e.g. 5")),
                  plus: .text(unlimited), pro: .text(unlimited)),
            .init(title: String(localized: "추천 템플릿", comment: "Paywall comparison row: suggested templates"), free: .yes, plus: .yes, pro: .yes),
            .init(title: String(localized: "깨기 전 경고 · 메모 · 비용 기록", comment: "Paywall comparison row: warning before breaking a cooldown, notes, actual cost"),
                  free: .yes, plus: .yes, pro: .yes),
            .init(title: String(localized: "끝 알림", comment: "Paywall comparison row: notification when a cooldown ends"), free: .yes, plus: .yes, pro: .yes),
            .init(title: String(localized: "전체 준수율 · 아낀 금액 · 사용 기록", comment: "Paywall comparison row: overall keep rate, money saved, usage history"),
                  free: .yes, plus: .yes, pro: .yes),
            .init(title: String(localized: "기록 CSV 내보내기", comment: "Paywall comparison row and Stats button: export history as CSV"), free: .yes, plus: .yes, pro: .yes),
            .init(title: String(localized: "절반 응원 알림", comment: "Paywall comparison row: cheer notification at the halfway point"), free: .no, plus: .yes, pro: .yes),
            .init(title: String(localized: "아이템별 · 카테고리별 준수율", comment: "Paywall comparison row: keep rate per item and per category"), free: .no, plus: .no, pro: .yes),
            .init(title: String(localized: "최근 활동 흐름", comment: "Paywall comparison row: recent activity"), free: .no, plus: .no, pro: .yes),
            .init(title: String(localized: "홈 · 잠금화면 위젯", comment: "Paywall comparison row: Home Screen and Lock Screen widgets"), free: .no, plus: .no, pro: .yes),
        ]
    }
}

// MARK: - 상품

enum ProEntitlement {

    // ⚠️ App Store Connect 의 상품 · `CoolTime.storekit` 과 **글자 하나까지 같아야 한다.**
    //    주 · 월 · 연 구독 여섯 개는 한 구독 그룹(Pro 가 위 단계)에 넣는다.

    static let plusWeeklyID = "com.Ysoup.CoolTime.plus.weekly"
    static let plusMonthlyID = "com.Ysoup.CoolTime.plus.monthly"
    static let plusYearlyID = "com.Ysoup.CoolTime.plus.yearly"
    static let plusLifetimeID = "com.Ysoup.CoolTime.plus.lifetime"
    static let proWeeklyID = "com.Ysoup.CoolTime.pro.weekly"
    static let proMonthlyID = "com.Ysoup.CoolTime.pro.monthly"
    static let proYearlyID = "com.Ysoup.CoolTime.pro.yearly"
    /// Pro 평생. **App Store Connect 에 이미 있던 '평생구매'(비소모성) 그 상품이다.** 번들 ID 와 앞자리가 다르지만
    /// 그대로 이어 쓴다 — 그때 산 사람은 따로 챙기지 않아도 Pro 평생이다.
    static let proLifetimeID = "com.cooltime.pro.lifetime"
    /// Plus 평생을 산 사람이 Pro 평생으로 올리는 값.
    static let upgradeID = "com.Ysoup.CoolTime.pro.upgrade"
    /// 구독 중인 사람의 졸업가 Pro 평생 (→ LeeoGraduation).
    static let graduateID = "com.Ysoup.CoolTime.pro.graduate"

    /// 개발자 응원 팁. 아무것도 열지 않는다 — `tierByProduct` 에 넣지 않는다.
    static let tipProductIDs = [
        "com.Ysoup.CoolTime.tip.small",
        "com.Ysoup.CoolTime.tip.medium",
        "com.Ysoup.CoolTime.tip.large",
    ]

    /// 페이월이 불러올 상품. 스토어에 아직 없는 상품은 불러오지 못한 채로 남고, 그 단추만 서지 않는다.
    static let productIDs = [
        plusYearlyID, plusLifetimeID, plusMonthlyID, plusWeeklyID,
        proYearlyID, proLifetimeID, proMonthlyID, proWeeklyID,
        upgradeID, graduateID,
    ]

    /// 상품마다 여는 칸.
    static let tierByProduct: [String: ProTier] = [
        plusWeeklyID: .plus, plusMonthlyID: .plus, plusYearlyID: .plus, plusLifetimeID: .plus,
        proWeeklyID: .pro, proMonthlyID: .pro, proYearlyID: .pro, proLifetimeID: .pro,
        upgradeID: .pro, graduateID: .pro,
    ]

    static var entitlementIDs: Set<String> { Set(tierByProduct.keys) }

    static let lifetimeIDs: Set<String> = [plusLifetimeID, proLifetimeID, upgradeID, graduateID]

    /// 자동 갱신 구독 (구독 졸업을 제안할 대상).
    static let subscriptionIDs: Set<String> = [plusWeeklyID, plusMonthlyID, plusYearlyID,
                                               proWeeklyID, proMonthlyID, proYearlyID]

    static func yearlyID(_ tier: ProTier) -> String { tier == .plus ? plusYearlyID : proYearlyID }
    static func monthlyID(_ tier: ProTier) -> String { tier == .plus ? plusMonthlyID : proMonthlyID }
    static func weeklyID(_ tier: ProTier) -> String { tier == .plus ? plusWeeklyID : proWeeklyID }

    /// 가진 상품 · 기존 사용자 · 언제나 평생 패스가 여는 칸. 가장 높은 것.
    static func tier(owning productIDs: Set<String>, grandfathered: Bool, foreverPass: Bool) -> ProTier {
        if grandfathered || foreverPass { return .pro }
        return productIDs.compactMap { tierByProduct[$0] }.max() ?? .free
    }

    static func ownsLifetime(_ tier: ProTier, in productIDs: Set<String>) -> Bool {
        productIDs.contains { lifetimeIDs.contains($0) && tierByProduct[$0] == tier }
    }

    // MARK: - 페이월 전에 받은 사람

    /// **페이월이 없던 마지막 빌드 번호**(1.0.4 빌드 4). 이 빌드까지 받은 사람은 위젯 · 통계를 빼앗지 않고 Pro 로 둔다.
    /// `AppTransaction.originalAppVersion` 은 iOS 에서 처음 받은 빌드의 CFBundleVersion 이다.
    /// ⚠️ 페이월이 든 빌드를 내기 전에 페이월 없는 빌드를 또 냈다면 이 값을 그 번호로 올린다.
    static let lastBuildBeforePaywall = "4"

    static func isBeforePaywall(originalAppVersion: String) -> Bool {
        originalAppVersion.compare(lastBuildBeforePaywall, options: .numeric) != .orderedDescending
    }
}
