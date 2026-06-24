import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Design Tokens

private let ctHold = Color(red: 0.10, green: 0.35, blue: 0.85)   // 아직 / 참는 중
private let ctSave = Color(red: 0.00, green: 0.55, blue: 0.30)   // 아낀 돈 / 참았어요
private let ctDanger = Color(red: 0.85, green: 0.25, blue: 0.25) // 그냥 샀어요

// MARK: - Timeline Entry

struct CoolTimeEntry: TimelineEntry {
    let date: Date
    let items: [WidgetCooldownItem]
    let stats: WidgetStats

    /// 아직 참는 중인 항목 (곧 풀리는 순)
    var waiting: [WidgetCooldownItem] {
        items.filter { $0.isOnCooldown }.sorted { $0.remainingCooldown < $1.remainingCooldown }
    }

    /// 지금 사용 가능한 항목 (이름순)
    var ready: [WidgetCooldownItem] {
        items.filter { !$0.isOnCooldown }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// 쿨타임 중인 것 먼저(곧 풀리는 순) → 그다음 사용 가능
    var ordered: [WidgetCooldownItem] { waiting + ready }

    /// 지를 위험이 가장 큰 항목 = 돈이 가장 많이 걸린 대기 항목
    var hero: WidgetCooldownItem? {
        waiting.max(by: { ($0.estimatedCost ?? 0) < ($1.estimatedCost ?? 0) }) ?? waiting.first
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
        let nextEnd = entry.items.compactMap(\.cooldownEndDate).filter { $0 > .now }.min()
        let refresh = min(nextEnd ?? Date(timeIntervalSinceNow: 1800), Date(timeIntervalSinceNow: 1800))
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func makeEntry() -> CoolTimeEntry {
        CoolTimeEntry(date: .now, items: WidgetDataStore.loadItems(), stats: WidgetDataStore.loadStats())
    }
}

// MARK: - Shared States

private struct EmptyWidgetView: View {
    var stats: WidgetStats = WidgetStats()
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "hourglass").font(.title3).foregroundStyle(.secondary)
            Text("쿨타임 없음").font(.caption).foregroundStyle(.secondary)
            Text("앱에서 추가").font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 12시에서 시계방향으로 차오르는 부채꼴 (앱 타일과 동일)
private struct ActivationWedge: Shape {
    var progress: Double
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = (rect.width * rect.width + rect.height * rect.height).squareRoot() / 2 + 2
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * progress),
                    clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// 게임 스킬 쿨타임 아이콘 — 이모지를 깔고(ZStack), 어두운 비활성 상태에서
/// 시계방향으로 밝게 차오르며, 남은 시간 글자를 위에 얹는다. 앱 타일과 동일.
private struct WidgetSkillIcon: View {
    let item: WidgetCooldownItem
    let size: CGFloat
    private var corner: CGFloat { size * 0.24 }
    private var isReady: Bool { !item.isOnCooldown }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(Color(red: 0.13, green: 0.13, blue: 0.17))

            // 비활성 베이스 — 거의 꺼진 상태(대비 강화)
            Text(item.emoji)
                .font(.system(size: size * 0.5))
                .saturation(0).opacity(0.14)

            // 활성화 레이어 — 경과한 만큼 시계방향으로 밝게 (사용 가능이면 꽉 참)
            Text(item.emoji)
                .font(.system(size: size * 0.5))
                .clipShape(ActivationWedge(progress: isReady ? 1 : item.cooldownProgress))

            // 시계방향 진행 링 (쿨타임 중)
            if !isReady {
                Circle()
                    .trim(from: 0, to: item.cooldownProgress)
                    .stroke(ctHold, style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(size * 0.05)

                Text(item.remainingCooldown.widgetFormatted)
                    .font(.system(size: size * 0.2, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
                    .minimumScaleFactor(0.6).lineLimit(1)
                    .offset(y: size * 0.22)
            }

            RoundedRectangle(cornerRadius: corner)
                .stroke((isReady ? ctSave : ctHold).opacity(isReady ? 0.9 : 0.25),
                        lineWidth: isReady ? 3 : 1.5)
        }
        .frame(width: size, height: size)
    }
}

/// 상태에 맞는 액션 버튼. full=true면 대기 항목에 참았어요/그냥 샀어요 둘 다,
/// full=false면 대표 액션 하나(대기=참음, 사용가능=스킬 사용).
private struct WidgetActionButtons: View {
    let item: WidgetCooldownItem
    var full: Bool = true

    private var id: String { item.id.uuidString }

    var body: some View {
        if item.isOnCooldown {
            HStack(spacing: 8) {
                Button(intent: ResistIntent(itemId: id)) {
                    Image(systemName: "hand.raised.fill")
                        .font(.callout).frame(maxWidth: full ? .infinity : nil)
                }.tint(ctSave)
                if full {
                    Button(intent: BuyIntent(itemId: id)) {
                        Image(systemName: "cart.fill")
                            .font(.callout).frame(maxWidth: .infinity)
                    }.tint(ctDanger)
                }
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button(intent: BuyIntent(itemId: id)) {
                Image(systemName: "bolt.fill")
                    .font(.callout).frame(maxWidth: full ? .infinity : nil)
            }
            .buttonStyle(.borderedProminent).tint(ctSave)
        }
    }
}

// MARK: - ═══════════════════════════════════════
// MARK:   WIDGET 1: 선제 개입 (Small/Medium/Large)
// MARK: ═══════════════════════════════════════

struct CoolTimeWidget: Widget {
    let kind = "CoolTimeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoolTimeProvider()) { entry in
            InterventionView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("충동 멈춤")
        .description("지를 때 ‘아직이에요’로 한 박자 멈춰줘요")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct InterventionView: View {
    @Environment(\.widgetFamily) var family
    let entry: CoolTimeEntry
    var body: some View {
        switch family {
        case .systemSmall:  InterventionSmall(entry: entry)
        case .systemMedium: InterventionMedium(entry: entry)
        default:            InterventionLarge(entry: entry)
        }
    }
}

// ── Small ────────────────────────────────────

private struct InterventionSmall: View {
    let entry: CoolTimeEntry

    var body: some View {
        if entry.items.isEmpty { EmptyWidgetView(stats: entry.stats) }
        else if let h = entry.hero { holdView(h) }
        else { savedView }
    }

    // 아직 참는 중 → 작은 스킬 아이콘 + 심볼 액션 버튼 (이름 텍스트 생략)
    private func holdView(_ item: WidgetCooldownItem) -> some View {
        VStack(spacing: 10) {
            WidgetSkillIcon(item: item, size: 58)
            WidgetActionButtons(item: item, full: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }

    // 다 가능 → 스트릭/절약 한 줄씩
    private var savedView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 40)).foregroundStyle(ctSave)
            Spacer()
            if entry.stats.streakDays > 0 {
                Text("🔥 \(entry.stats.streakDays)일째").font(.headline).fontWeight(.bold)
            }
            if entry.stats.monthlySavings > 0 {
                Text("₩\(entry.stats.monthlySavings.formatted()) 아낌")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(ctSave)
                    .lineLimit(1).minimumScaleFactor(0.8)
            } else if entry.stats.streakDays == 0 {
                Text("충동 없이").font(.headline).fontWeight(.bold)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }
}

// ── Medium ───────────────────────────────────

private struct InterventionMedium: View {
    let entry: CoolTimeEntry

    var body: some View {
        if entry.items.isEmpty { EmptyWidgetView(stats: entry.stats) }
        else { content }
    }

    private var content: some View {
        let target = entry.hero ?? entry.ready.first
        return HStack(spacing: 14) {
            if let t = target {
                WidgetSkillIcon(item: t, size: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text(t.isOnCooldown ? "아직이에요" : "지금 가능")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(t.isOnCooldown ? ctHold : ctSave)
                    Text(t.name).font(.headline).fontWeight(.bold).lineLimit(1)
                    WidgetActionButtons(item: t, full: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 40)).foregroundStyle(ctSave)
                    if entry.stats.monthlySavings > 0 {
                        Text("₩\(entry.stats.monthlySavings.formatted()) 아낌")
                            .font(.subheadline).fontWeight(.bold).foregroundStyle(ctSave)
                    } else {
                        Text("충동 없이 가는 중").font(.headline).fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
    }
}

// ── Large ────────────────────────────────────

private struct InterventionLarge: View {
    let entry: CoolTimeEntry

    var body: some View {
        if entry.items.isEmpty { EmptyWidgetView(stats: entry.stats) }
        else { content }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("충동 멈춤").font(.title3).fontWeight(.bold)
                Spacer()
                if entry.stats.monthlySavings > 0 {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("이번 달 아낀 돈").font(.caption2).foregroundStyle(.secondary)
                        Text("₩\(entry.stats.monthlySavings.formatted())")
                            .font(.headline).fontWeight(.bold).foregroundStyle(ctSave)
                    }
                }
            }

            // 히어로 (가장 돈 걸린 대기 항목) — 큰 버튼 둘
            if let h = entry.hero {
                VStack(spacing: 10) {
                    HStack(spacing: 14) {
                        WidgetSkillIcon(item: h, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("아직이에요").font(.caption).fontWeight(.bold).foregroundStyle(ctHold)
                            Text(h.name).font(.headline).fontWeight(.bold).lineLimit(1)
                        }
                        Spacer()
                    }
                    WidgetActionButtons(item: h, full: true)
                }
                .padding(12)
                .background(ctHold.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
            }

            // 나머지 항목들 — 스킬 바(각자 액션 버튼)
            VStack(spacing: 8) {
                ForEach(entry.ordered.filter { $0.id != entry.hero?.id }.prefix(entry.hero == nil ? 5 : 3)) { item in
                    HStack(spacing: 10) {
                        WidgetSkillIcon(item: item, size: 38)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name).font(.subheadline).fontWeight(.medium).lineLimit(1)
                            Text(item.isOnCooldown ? "아직 \(item.remainingCooldown.widgetFormatted)" : "사용 가능")
                                .font(.caption2)
                                .foregroundStyle(item.isOnCooldown ? ctHold : ctSave)
                        }
                        Spacer()
                        WidgetActionButtons(item: item, full: false)
                    }
                }
            }
            Spacer()
        }
        .padding(16)
    }
}

// MARK: - ═══════════════════════════════════════
// MARK:   WIDGET 2: 지금 참기 (Small/Medium)
// MARK:   → 가장 돈 걸린 한 항목에 집중
// MARK: ═══════════════════════════════════════

struct ResistanceWidget: Widget {
    let kind = "ResistanceWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoolTimeProvider()) { entry in
            InterventionView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("지금 참기")
        .description("가장 큰 충동 하나를 ‘아직이에요’로 막아줘요")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - ═══════════════════════════════════════
// MARK:   WIDGET 3: 잠금화면 (선제 개입의 핵심)
// MARK: ═══════════════════════════════════════

struct CoolTimeAccessoryWidget: Widget {
    let kind = "CoolTimeAccessoryWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoolTimeProvider()) { entry in
            CoolTimeAccessoryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("충동 멈춤 (잠금화면)")
        .description("지를 때 잠금화면이 먼저 ‘아직이에요’")
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

    // 원형: 가장 가까운 충동의 충전 진행 + 이모지
    private var circularView: some View {
        ZStack {
            if let h = entry.waiting.first {
                Circle().stroke(.secondary.opacity(0.3), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: h.cooldownProgress)
                    .stroke(.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(h.emoji).font(.body)
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "checkmark.seal.fill").font(.body)
                    Text("OK").font(.caption2).fontWeight(.bold)
                }
            }
        }
    }

    // 직사각형: 핵심 개입 메시지
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let h = entry.hero {
                Label("아직이에요", systemImage: "hourglass")
                    .font(.caption2).fontWeight(.bold)
                HStack(spacing: 4) {
                    Text(h.emoji)
                    Text(h.name).fontWeight(.semibold).lineLimit(1)
                    Spacer()
                    Text(h.remainingCooldown.widgetFormatted).fontWeight(.bold)
                }
                .font(.headline)
            } else if entry.stats.streakDays > 0 {
                Label("\(entry.stats.streakDays)일째 충동 없이", systemImage: "flame.fill")
                    .font(.caption).fontWeight(.bold)
            } else {
                Label("충동 없이 가는 중", systemImage: "checkmark.seal.fill")
                    .font(.caption).fontWeight(.semibold)
            }
        }
    }

    // 인라인: 한 줄
    private var inlineView: some View {
        Group {
            if let h = entry.hero {
                Text("\(h.emoji) 아직 \(h.remainingCooldown.widgetFormatted)")
            } else if entry.stats.monthlySavings > 0 {
                Text("이번 달 ₩\(entry.stats.monthlySavings.formatted()) 아낌")
            } else {
                Text("충동 없이 가는 중")
            }
        }
    }
}

// MARK: - Previews

private func sampleEntry() -> CoolTimeEntry {
    let items = [
        WidgetCooldownItem(id: UUID(), name: "온라인 쇼핑", emoji: "🛍️",
                           cooldownDuration: 14 * 86400,
                           lastUsedDate: Date().addingTimeInterval(-4 * 86400),
                           estimatedCost: 50000, category: "기타"),
        WidgetCooldownItem(id: UUID(), name: "배달음식", emoji: "🍕",
                           cooldownDuration: 3 * 86400,
                           lastUsedDate: Date().addingTimeInterval(-86400),
                           estimatedCost: 25000, category: "기타"),
        WidgetCooldownItem(id: UUID(), name: "커피", emoji: "☕️",
                           cooldownDuration: 86400,
                           lastUsedDate: Date().addingTimeInterval(-2 * 86400),
                           estimatedCost: 5000, category: "기타")
    ]
    return CoolTimeEntry(date: .now, items: items,
                         stats: WidgetStats(totalItems: 3, onCooldownCount: 2,
                                            monthlySavings: 305000, isPro: true,
                                            streakDays: 14, lastSync: Date()))
}

#Preview("Small", as: .systemSmall) {
    CoolTimeWidget()
} timeline: { sampleEntry() }

#Preview("Medium", as: .systemMedium) {
    CoolTimeWidget()
} timeline: { sampleEntry() }

#Preview("Large", as: .systemLarge) {
    CoolTimeWidget()
} timeline: { sampleEntry() }

#Preview("Lock Rectangular", as: .accessoryRectangular) {
    CoolTimeAccessoryWidget()
} timeline: { sampleEntry() }
