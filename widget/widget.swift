import WidgetKit
import SwiftUI

// MARK: - Design Tokens

private let ctReady    = Color(red: 0.18, green: 0.80, blue: 0.44)
private let ctCooldown = Color(red: 0.35, green: 0.55, blue: 1.00)
private let ctWarning  = Color(red: 1.00, green: 0.55, blue: 0.20)

// MARK: - Timeline Entry

struct CoolTimeEntry: TimelineEntry {
    let date: Date
    let items: [WidgetCooldownItem]
    let stats: WidgetStats

    var available: [WidgetCooldownItem] {
        items.filter { !$0.isOnCooldown }
    }

    var onCooldown: [WidgetCooldownItem] {
        items.filter { $0.isOnCooldown }.sorted { $0.remainingCooldown < $1.remainingCooldown }
    }

    // 가장 주의해야 할 아이템: 사용 가능 + 비용 높은 순
    var urgentItem: WidgetCooldownItem? {
        available
            .filter { $0.estimatedCost != nil }
            .max(by: { ($0.estimatedCost ?? 0) < ($1.estimatedCost ?? 0) })
        ?? available.first
    }
}

// MARK: - Provider

struct CoolTimeProvider: TimelineProvider {
    func placeholder(in context: Context) -> CoolTimeEntry {
        CoolTimeEntry(date: .now, items: [], stats: WidgetStats())
    }

    func getSnapshot(in context: Context, completion: @escaping (CoolTimeEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CoolTimeEntry>) -> Void) {
        let entry = makeEntry()
        // 다음 쿨타임 종료 시각 또는 30분 후 갱신 (배터리 효율)
        let nextEnd = entry.items.compactMap(\.cooldownEndDate).filter { $0 > .now }.min()
        let refresh = min(nextEnd ?? Date(timeIntervalSinceNow: 1800), Date(timeIntervalSinceNow: 1800))
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func makeEntry() -> CoolTimeEntry {
        CoolTimeEntry(date: .now, items: WidgetDataStore.loadItems(), stats: WidgetDataStore.loadStats())
    }
}

// MARK: - Shared: Lock / Empty Views

struct WidgetLockView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.circle.fill")
                .font(.title2).foregroundStyle(ctCooldown)
            Text("CoolTime Pro")
                .font(.caption).fontWeight(.bold)
            Text("앱에서 업그레이드")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyWidgetView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.title2).foregroundStyle(.secondary)
            Text("쿨타임 없음")
                .font(.caption).foregroundStyle(.secondary)
            Text("앱에서 추가하세요")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ═══════════════════════════════════════
// MARK:   WIDGET 1: 현황 위젯 (Small/Medium/Large)
// MARK: ═══════════════════════════════════════

struct CoolTimeWidget: Widget {
    let kind = "CoolTimeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoolTimeProvider()) { entry in
            CoolTimeOverviewView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("쿨타임 현황")
        .description("전체 쿨타임 상태를 한눈에")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CoolTimeOverviewView: View {
    @Environment(\.widgetFamily) var family
    let entry: CoolTimeEntry
    var body: some View {
        switch family {
        case .systemSmall:  SmallOverviewView(entry: entry)
        case .systemMedium: MediumOverviewView(entry: entry)
        default:            LargeOverviewView(entry: entry)
        }
    }
}

// ── Small Overview ───────────────────────────

struct SmallOverviewView: View {
    let entry: CoolTimeEntry

    var body: some View {
        if !entry.stats.isPro { WidgetLockView() }
        else if entry.items.isEmpty { EmptyWidgetView() }
        else { mainContent }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack(alignment: .center) {
                Text("쿨타임")
                    .font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: entry.available.isEmpty ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(entry.available.isEmpty ? ctReady : ctWarning)
            }

            Spacer()

            // 핵심 정보
            if let next = entry.onCooldown.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(next.emoji).font(.largeTitle)
                    Text(next.name)
                        .font(.caption).fontWeight(.semibold).lineLimit(1)
                    Text(next.remainingCooldown.widgetFormatted)
                        .font(.title2).fontWeight(.bold).foregroundStyle(ctCooldown)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle).foregroundStyle(ctWarning)
                    Text("\(entry.available.count)개 주의")
                        .font(.caption).fontWeight(.semibold)
                    Text("충동 조심!")
                        .font(.title2).fontWeight(.bold).foregroundStyle(ctWarning)
                }
            }

            Spacer()

            // 준수율
            HStack(spacing: 3) {
                Image(systemName: "checkmark.shield.fill").font(.caption2)
                Text("\(Int(entry.stats.complianceRate * 100))%").font(.caption2).fontWeight(.semibold)
                Text("준수").font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .padding(14)
    }
}

// ── Medium Overview ──────────────────────────

struct MediumOverviewView: View {
    let entry: CoolTimeEntry

    var body: some View {
        if !entry.stats.isPro { WidgetLockView() }
        else { content }
    }

    private var content: some View {
        HStack(spacing: 0) {
            // 왼쪽: 요약 통계
            VStack(alignment: .leading, spacing: 6) {
                Text("쿨타임")
                    .font(.subheadline).fontWeight(.bold)
                Spacer()

                if entry.stats.monthlySavings > 0 {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("이번 달 절약")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("₩\(entry.stats.monthlySavings.formatted())")
                            .font(.headline).fontWeight(.bold).foregroundStyle(ctReady)
                    }
                }

                HStack(spacing: 10) {
                    VStack(spacing: 1) {
                        Text("\(entry.available.count)")
                            .font(.title3).fontWeight(.bold).foregroundStyle(ctWarning)
                        Text("주의").font(.caption2).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 1) {
                        Text("\(entry.onCooldown.count)")
                            .font(.title3).fontWeight(.bold).foregroundStyle(ctCooldown)
                        Text("보호 중").font(.caption2).foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 3) {
                    Image(systemName: "checkmark.shield.fill").font(.caption2)
                    Text("\(Int(entry.stats.complianceRate * 100))%").font(.caption2).fontWeight(.semibold)
                }
                .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(width: 130, alignment: .leading)

            Divider().padding(.vertical, 12)

            // 오른쪽: 아이템 목록
            VStack(alignment: .leading, spacing: 6) {
                // 쿨타임 중 (보호됨)
                ForEach(entry.onCooldown.prefix(3)) { item in
                    HStack(spacing: 6) {
                        Text(item.emoji).font(.callout)
                        Text(item.name)
                            .font(.caption).fontWeight(.medium).lineLimit(1)
                        Spacer()
                        Text(item.remainingCooldown.widgetFormatted)
                            .font(.caption2).fontWeight(.bold).foregroundStyle(ctCooldown)
                    }
                }
                // 사용 가능 (주의)
                if !entry.available.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2).foregroundStyle(ctWarning)
                        Text(entry.available.prefix(3).map(\.emoji).joined() + " 사용 가능")
                            .font(.caption2).foregroundStyle(ctWarning).lineLimit(1)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// ── Large Overview ───────────────────────────

struct LargeOverviewView: View {
    let entry: CoolTimeEntry

    var body: some View {
        if !entry.stats.isPro { WidgetLockView() }
        else { content }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("쿨타임")
                        .font(.title2).fontWeight(.bold)
                    if entry.stats.monthlySavings > 0 {
                        Text("이번 달 ₩\(entry.stats.monthlySavings.formatted()) 절약")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ComplianceRing(rate: entry.stats.complianceRate, size: 52)
            }

            Divider()

            // 사용 가능 (주의 섹션)
            if !entry.available.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("지금 주의 필요", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(ctWarning)
                    HStack(spacing: 10) {
                        ForEach(entry.available.prefix(4)) { item in
                            VStack(spacing: 3) {
                                Text(item.emoji).font(.title2)
                                Text(item.name)
                                    .font(.caption2).lineLimit(1).foregroundStyle(.secondary)
                                if let cost = item.estimatedCost {
                                    Text("₩\(cost.formatted())")
                                        .font(.caption2).foregroundStyle(ctWarning).fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }

            // 쿨타임 중 섹션
            if !entry.onCooldown.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("쿨타임 보호 중", systemImage: "shield.fill")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(ctCooldown)
                    ForEach(entry.onCooldown.prefix(5)) { item in
                        HStack(spacing: 10) {
                            Text(item.emoji).font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.caption).fontWeight(.medium).lineLimit(1)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 3)
                                        Capsule().fill(ctCooldown)
                                            .frame(width: geo.size.width * item.cooldownProgress, height: 3)
                                    }
                                }
                                .frame(height: 3)
                            }
                            Spacer()
                            Text(item.remainingCooldown.widgetFormatted)
                                .font(.caption2).fontWeight(.bold).foregroundStyle(ctCooldown)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(14)
    }
}

// MARK: - ═══════════════════════════════════════
// MARK:   WIDGET 2: 저항 위젯 (Small/Medium)
// MARK:   → "지금 참아야 할 아이템" 특화
// MARK: ═══════════════════════════════════════

struct ResistanceWidget: Widget {
    let kind = "ResistanceWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoolTimeProvider()) { entry in
            ResistanceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("쿨타임 저항")
        .description("지금 참아야 할 항목과 절약 금액")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ResistanceWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: CoolTimeEntry
    var body: some View {
        switch family {
        case .systemSmall:  SmallResistanceView(entry: entry)
        default:            MediumResistanceView(entry: entry)
        }
    }
}

// ── Small Resistance ─────────────────────────

struct SmallResistanceView: View {
    let entry: CoolTimeEntry

    var body: some View {
        if !entry.stats.isPro { WidgetLockView() }
        else if entry.items.isEmpty { EmptyWidgetView() }
        else if let urgent = entry.urgentItem { dangerState(urgent) }
        else if let soonest = entry.onCooldown.first { cooldownState(soonest) }
        else { allSafeState }
    }

    // ⚠️ 사용 가능 → 위험 상태
    private func dangerState(_ item: WidgetCooldownItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundStyle(ctWarning)
                Text("지금 주의").font(.caption).fontWeight(.bold).foregroundStyle(ctWarning)
            }
            Spacer()
            Text(item.emoji).font(.system(size: 40))
            Spacer(minLength: 4)
            Text(item.name)
                .font(.caption).fontWeight(.semibold).lineLimit(1)
            if let cost = item.estimatedCost {
                Text("₩\(cost.formatted())")
                    .font(.title3).fontWeight(.bold).foregroundStyle(ctWarning)
                Text("지금 쓰면 이만큼")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("사용 가능해요")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(ctWarning)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // 🔒 쿨타임 중 → 안전 상태 (격려)
    private func cooldownState(_ item: WidgetCooldownItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "shield.fill")
                    .font(.caption2).foregroundStyle(ctCooldown)
                Text("잘 참고 있어요").font(.caption).fontWeight(.bold).foregroundStyle(ctCooldown)
            }
            Spacer()
            Text(item.emoji).font(.system(size: 40))
            Spacer(minLength: 4)
            Text(item.name)
                .font(.caption).fontWeight(.semibold).lineLimit(1)
            Text(item.remainingCooldown.widgetFormatted)
                .font(.title2).fontWeight(.bold).foregroundStyle(ctCooldown)
            if let cost = item.estimatedCost {
                HStack(spacing: 2) {
                    Image(systemName: "wonsign.circle.fill").font(.caption2)
                    Text("\(cost.formatted()) 절약 중")
                        .font(.caption2)
                }
                .foregroundStyle(ctReady)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // 🏆 모두 쿨타임 (아이템 없음)
    private var allSafeState: some View {
        VStack(spacing: 6) {
            Text("🏆").font(.system(size: 36))
            Text("완벽해요!")
                .font(.headline).fontWeight(.bold).foregroundStyle(ctReady)
            Text("\(Int(entry.stats.complianceRate * 100))% 준수")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ── Medium Resistance ────────────────────────

struct MediumResistanceView: View {
    let entry: CoolTimeEntry

    var body: some View {
        if !entry.stats.isPro { WidgetLockView() }
        else { content }
    }

    private var content: some View {
        HStack(spacing: 0) {
            // 왼쪽: 동기 부여 요약
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.caption).foregroundStyle(ctWarning)
                    Text("저항 현황").font(.caption).fontWeight(.bold)
                }

                Spacer()

                // 절약 금액
                VStack(alignment: .leading, spacing: 2) {
                    Text("이번 달 절약").font(.caption2).foregroundStyle(.secondary)
                    if entry.stats.monthlySavings > 0 {
                        Text("₩\(entry.stats.monthlySavings.formatted())")
                            .font(.title3).fontWeight(.bold).foregroundStyle(ctReady)
                    } else {
                        Text("₩0").font(.title3).fontWeight(.bold).foregroundStyle(.secondary)
                    }
                }

                // 준수율 링
                ComplianceRing(rate: entry.stats.complianceRate, size: 44)

                Text("\(Int(entry.stats.complianceRate * 100))% 준수율")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(width: 130, alignment: .leading)

            Divider().padding(.vertical, 12)

            // 오른쪽: 아이템 상태
            VStack(alignment: .leading, spacing: 5) {
                // 주의 항목 (사용 가능)
                ForEach(entry.available.prefix(2)) { item in
                    HStack(spacing: 8) {
                        Text(item.emoji).font(.callout)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.caption).fontWeight(.semibold).lineLimit(1)
                            if let cost = item.estimatedCost {
                                Text("₩\(cost.formatted()) 위험")
                                    .font(.caption2).foregroundStyle(ctWarning)
                            }
                        }
                        Spacer()
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption).foregroundStyle(ctWarning)
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                    .background(ctWarning.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }

                // 보호 중 항목 (쿨타임)
                ForEach(entry.onCooldown.prefix(3 - min(entry.available.count, 2))) { item in
                    HStack(spacing: 8) {
                        Text(item.emoji).font(.callout)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.caption).fontWeight(.medium).lineLimit(1)
                            // 진행바
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 3)
                                    Capsule().fill(ctCooldown)
                                        .frame(width: geo.size.width * item.cooldownProgress, height: 3)
                                }
                            }
                            .frame(height: 3)
                        }
                        Spacer()
                        Text(item.remainingCooldown.widgetFormatted)
                            .font(.caption2).fontWeight(.bold).foregroundStyle(ctCooldown)
                    }
                }

                if entry.items.isEmpty {
                    Text("아이템을 추가하세요")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - ═══════════════════════════════════════
// MARK:   WIDGET 3: 잠금화면 위젯
// MARK: ═══════════════════════════════════════

struct CoolTimeAccessoryWidget: Widget {
    let kind = "CoolTimeAccessoryWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoolTimeProvider()) { entry in
            CoolTimeAccessoryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("쿨타임")
        .description("잠금화면에서 쿨타임 확인")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct CoolTimeAccessoryView: View {
    @Environment(\.widgetFamily) var family
    let entry: CoolTimeEntry

    var body: some View {
        switch family {
        case .accessoryCircular:    circularView
        case .accessoryRectangular: rectangularView
        default:                    inlineView
        }
    }

    // 원형: 준수율 링 or 주의 카운트
    private var circularView: some View {
        ZStack {
            if entry.available.isEmpty {
                // 준수율 링
                Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: entry.stats.complianceRate)
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(entry.stats.complianceRate * 100))")
                        .font(.system(size: 16, weight: .bold))
                    Text("%").font(.caption2)
                }
            } else if let item = entry.urgentItem {
                // 주의 아이템 강조
                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                VStack(spacing: 1) {
                    Text(item.emoji).font(.caption)
                    Image(systemName: "exclamationmark").font(.caption2).fontWeight(.bold)
                }
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark").font(.title3).fontWeight(.bold)
                    Text("\(entry.onCooldown.count)").font(.caption2).fontWeight(.bold)
                }
            }
        }
    }

    // 직사각형: 가장 동기 부여가 되는 메시지
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let urgent = entry.urgentItem {
                // 주의 필요
                Label("지금 조심하세요", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2).fontWeight(.semibold)
                HStack(spacing: 4) {
                    Text(urgent.emoji)
                    Text(urgent.name).fontWeight(.medium).lineLimit(1)
                    if let cost = urgent.estimatedCost {
                        Spacer()
                        Text("₩\(cost.formatted())").fontWeight(.bold)
                    }
                }
                .font(.caption)
            } else if let next = entry.onCooldown.first {
                // 쿨타임 보호 중
                Label("잘 참고 있어요 ✊", systemImage: "shield.fill")
                    .font(.caption2).fontWeight(.semibold)
                HStack(spacing: 4) {
                    Text(next.emoji)
                    Text(next.name).fontWeight(.medium).lineLimit(1)
                    Spacer()
                    Text(next.remainingCooldown.widgetFormatted).fontWeight(.bold)
                }
                .font(.caption)
            } else {
                Label("쿨타임이 없어요", systemImage: "sparkles")
                    .font(.caption2)
                Text("앱에서 추가하세요").font(.caption)
            }
        }
    }

    // 인라인: 한 줄 요약
    private var inlineView: some View {
        Group {
            if let urgent = entry.urgentItem {
                Text("\(urgent.emoji) 주의! \(urgent.name)")
            } else if let next = entry.onCooldown.first {
                Text("✊ \(next.emoji) \(next.name) \(next.remainingCooldown.widgetFormatted)")
            } else {
                Text("✅ \(entry.onCooldown.count)개 보호 중")
            }
        }
    }
}

// MARK: - Shared Helper Views

struct ComplianceRing: View {
    let rate: Double
    let size: CGFloat

    private var color: Color {
        rate >= 0.8 ? ctReady : (rate >= 0.5 ? ctWarning : Color(red: 1, green: 0.35, blue: 0.35))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: size * 0.09)
            Circle()
                .trim(from: 0, to: rate)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(rate * 100))")
                    .font(.system(size: size * 0.28, weight: .bold))
                Text("%")
                    .font(.system(size: size * 0.18))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Previews

#Preview("Small Overview", as: .systemSmall) {
    CoolTimeWidget()
} timeline: {
    CoolTimeEntry(date: .now, items: [], stats: WidgetStats())
}

#Preview("Small Resistance", as: .systemSmall) {
    ResistanceWidget()
} timeline: {
    CoolTimeEntry(date: .now, items: [], stats: WidgetStats())
}

#Preview("Medium Resistance", as: .systemMedium) {
    ResistanceWidget()
} timeline: {
    CoolTimeEntry(date: .now, items: [], stats: WidgetStats())
}

#Preview("Lock Rectangular", as: .accessoryRectangular) {
    CoolTimeAccessoryWidget()
} timeline: {
    CoolTimeEntry(date: .now, items: [], stats: WidgetStats())
}
