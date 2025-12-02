import Foundation

/// 기본 제안 템플릿
struct CooldownTemplate: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let cooldownDuration: TimeInterval
    let estimatedCost: Int?
    let category: String
    let description: String
    
    /// CooldownItem으로 변환
    func toItem() -> CooldownItem {
        CooldownItem(
            name: name,
            emoji: emoji,
            cooldownDuration: cooldownDuration,
            estimatedCost: estimatedCost,
            category: category
        )
    }
}

// MARK: - 기본 제공 템플릿들

enum TemplateCategory: String, CaseIterable {
    case travel = "🌏 여행"
    case shopping = "🛍️ 쇼핑"
    case food = "🍔 음식"
    case entertainment = "🎮 엔터테인먼트"
    case lifestyle = "💅 라이프스타일"
    case health = "🏃 건강"
    case finance = "💰 금융"
    
    var templates: [CooldownTemplate] {
        switch self {
        case .travel:
            return [
                CooldownTemplate(
                    name: "해외여행",
                    emoji: "✈️",
                    cooldownDuration: .months(2),
                    estimatedCost: 1500000,
                    category: rawValue,
                    description: "해외여행은 2달에 한 번이면 충분해요"
                ),
                CooldownTemplate(
                    name: "국내여행",
                    emoji: "🚗",
                    cooldownDuration: .months(1),
                    estimatedCost: 300000,
                    category: rawValue,
                    description: "한 달에 한 번 국내여행"
                ),
                CooldownTemplate(
                    name: "호캉스",
                    emoji: "🏨",
                    cooldownDuration: .weeks(3),
                    estimatedCost: 200000,
                    category: rawValue,
                    description: "호텔 힐링은 3주에 한 번"
                )
            ]
            
        case .shopping:
            return [
                CooldownTemplate(
                    name: "고가 쇼핑 (10만원+)",
                    emoji: "💳",
                    cooldownDuration: .months(1),
                    estimatedCost: 150000,
                    category: rawValue,
                    description: "큰 지출은 한 달에 한 번"
                ),
                CooldownTemplate(
                    name: "옷 쇼핑",
                    emoji: "👕",
                    cooldownDuration: .weeks(2),
                    estimatedCost: 80000,
                    category: rawValue,
                    description: "옷은 2주에 한 번"
                ),
                CooldownTemplate(
                    name: "충동구매",
                    emoji: "🛒",
                    cooldownDuration: .weeks(1),
                    estimatedCost: 50000,
                    category: rawValue,
                    description: "충동구매는 일주일에 한 번만"
                ),
                CooldownTemplate(
                    name: "전자기기",
                    emoji: "📱",
                    cooldownDuration: .months(6),
                    estimatedCost: 500000,
                    category: rawValue,
                    description: "전자기기는 6개월에 한 번"
                )
            ]
            
        case .food:
            return [
                CooldownTemplate(
                    name: "패스트푸드",
                    emoji: "🍔",
                    cooldownDuration: .days(5),
                    estimatedCost: 12000,
                    category: rawValue,
                    description: "패스트푸드는 5일에 한 번"
                ),
                CooldownTemplate(
                    name: "배달음식",
                    emoji: "🍕",
                    cooldownDuration: .days(3),
                    estimatedCost: 25000,
                    category: rawValue,
                    description: "배달은 3일에 한 번"
                ),
                CooldownTemplate(
                    name: "카페",
                    emoji: "☕",
                    cooldownDuration: .days(2),
                    estimatedCost: 6000,
                    category: rawValue,
                    description: "커피는 이틀에 한 번"
                ),
                CooldownTemplate(
                    name: "디저트",
                    emoji: "🍰",
                    cooldownDuration: .days(4),
                    estimatedCost: 8000,
                    category: rawValue,
                    description: "달달한 건 4일에 한 번"
                ),
                CooldownTemplate(
                    name: "외식",
                    emoji: "🍽️",
                    cooldownDuration: .weeks(1),
                    estimatedCost: 50000,
                    category: rawValue,
                    description: "외식은 주 1회"
                ),
                CooldownTemplate(
                    name: "야식",
                    emoji: "🌙",
                    cooldownDuration: .days(5),
                    estimatedCost: 15000,
                    category: rawValue,
                    description: "야식은 5일에 한 번"
                )
            ]
            
        case .entertainment:
            return [
                CooldownTemplate(
                    name: "게임 과금",
                    emoji: "🎮",
                    cooldownDuration: .weeks(2),
                    estimatedCost: 30000,
                    category: rawValue,
                    description: "게임 과금은 2주에 한 번"
                ),
                CooldownTemplate(
                    name: "영화관",
                    emoji: "🎬",
                    cooldownDuration: .weeks(2),
                    estimatedCost: 15000,
                    category: rawValue,
                    description: "영화는 2주에 한 번"
                ),
                CooldownTemplate(
                    name: "넷플릭스 빈지워칭",
                    emoji: "📺",
                    cooldownDuration: .days(3),
                    estimatedCost: nil,
                    category: rawValue,
                    description: "몰아보기는 3일에 한 번"
                ),
                CooldownTemplate(
                    name: "콘서트/공연",
                    emoji: "🎤",
                    cooldownDuration: .months(2),
                    estimatedCost: 150000,
                    category: rawValue,
                    description: "공연은 2달에 한 번"
                )
            ]
            
        case .lifestyle:
            return [
                CooldownTemplate(
                    name: "술 마시기",
                    emoji: "🍺",
                    cooldownDuration: .days(3),
                    estimatedCost: 50000,
                    category: rawValue,
                    description: "음주는 3일에 한 번"
                ),
                CooldownTemplate(
                    name: "택시",
                    emoji: "🚕",
                    cooldownDuration: .days(3),
                    estimatedCost: 15000,
                    category: rawValue,
                    description: "택시는 3일에 한 번"
                ),
                CooldownTemplate(
                    name: "네일아트",
                    emoji: "💅",
                    cooldownDuration: .weeks(3),
                    estimatedCost: 50000,
                    category: rawValue,
                    description: "네일은 3주에 한 번"
                ),
                CooldownTemplate(
                    name: "미용실",
                    emoji: "💇",
                    cooldownDuration: .months(1),
                    estimatedCost: 30000,
                    category: rawValue,
                    description: "미용실은 한 달에 한 번"
                ),
                CooldownTemplate(
                    name: "마사지/스파",
                    emoji: "💆",
                    cooldownDuration: .weeks(2),
                    estimatedCost: 80000,
                    category: rawValue,
                    description: "마사지는 2주에 한 번"
                )
            ]
            
        case .health:
            return [
                CooldownTemplate(
                    name: "휴식의 날 (운동 스킵)",
                    emoji: "😴",
                    cooldownDuration: .days(3),
                    estimatedCost: nil,
                    category: rawValue,
                    description: "운동 쉬는 날은 3일에 한 번"
                ),
                CooldownTemplate(
                    name: "치팅데이",
                    emoji: "🍖",
                    cooldownDuration: .weeks(1),
                    estimatedCost: nil,
                    category: rawValue,
                    description: "다이어트 치팅은 주 1회"
                )
            ]
            
        case .finance:
            return [
                CooldownTemplate(
                    name: "주식 매매",
                    emoji: "📈",
                    cooldownDuration: .weeks(1),
                    estimatedCost: nil,
                    category: rawValue,
                    description: "충동 매매 방지, 주 1회"
                ),
                CooldownTemplate(
                    name: "로또",
                    emoji: "🎰",
                    cooldownDuration: .weeks(1),
                    estimatedCost: 5000,
                    category: rawValue,
                    description: "로또는 주 1회"
                )
            ]
        }
    }
}

// MARK: - 모든 템플릿 접근

struct Templates {
    static var all: [CooldownTemplate] {
        TemplateCategory.allCases.flatMap { $0.templates }
    }
    
    static func byCategory(_ category: TemplateCategory) -> [CooldownTemplate] {
        category.templates
    }
}
