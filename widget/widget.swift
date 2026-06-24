import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Design Tokens

private let ctHold = Color(red: 0.10, green: 0.35, blue: 0.85)   // 아직 / 참는 중
private let ctSave = Color(red: 0.00, green: 0.55, blue: 0.30)   // 아낀 돈

// MARK: - Timeline Entry

struct CoolTimeEntry: TimelineEntry {
    let date: Date
    let items: [WidgetCooldownItem]
    let stats: WidgetStats

    /// 아직 참는 중인 항목 (곧 풀리는 순)
    var waiting: [WidgetCooldownItem] {
        items.filter { $0.isOnCooldown }.sorted { $0.remainingCooldown < $1.remainingCooldown }
    }

    /// 지금 "지를" 위험이 가장 큰 항목 = 돈이 가장 많이 걸린, 아직 참는 중인 것
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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(Color(red: 0.13, green: 0.13, blue: 0.17))

            // 비활성 베이스 (어둡고 채도 낮은 이모지)
            Text(item.emoji)
                .font(.system(size: size * 0.5))
                .saturation(0.12).opacity(0.32)

            // 활성화 레이어 — 경과한 만큼 시계방향으로 밝게
            Text(item.emoji)
                .font(.system(size: size * 0.5))
                .clipShape(ActivationWedge(progress: item.cooldownProgress))

            // 남은 시간 — 아이콘 위 중앙
            Text(item.remainingCooldown.widgetFormatted)
                .font(.system(size: size * 0.24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.85), radius: 2, y: 1)
                .minimumScaleFactor(0.6).lineLimit(1)

            RoundedRectangle(cornerRadius: corner)
                .stroke(ctHold.opacity(0.7), lineWidth: 2)
        }
        .frame(width: size, height: size)
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

    // 아직 참는 중 → 스킬 아이콘(이모지 깔고 시계방향 활성화 + 남은시간) + 이름
    private func holdView(_ item: WidgetCooldownItem) -> some View {
        VStack(spacing: 8) {
            WidgetSkillIcon(item: item, size: 84)
            Text(item.name)
                .font(.caption).fontWeight(.semibold)
                .lineLimit(1).minimumScaleFactor(0.8)
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
        HStack(spacing: 16) {
            // 왼쪽: 히어로 하나 — 스킬 아이콘 + 이름
            if let h = entry.hero {
                VStack(spacing: 6) {
                    WidgetSkillIcon(item: h, size: 72)
                    Text(h.name)
                        .font(.caption).fontWeight(.semibold)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundStyle(ctSave)
                    Text("충동 없이").font(.headline).fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            // 오른쪽: 스트릭 + 이번 달 절약
            VStack(alignment: .leading, spacing: 6) {
                if entry.stats.streakDays > 0 {
                    Text("🔥 \(entry.stats.streakDays)일째").font(.headline).fontWeight(.bold)
                }
                Spacer().frame(height: 2)
                Text("₩\(entry.stats.monthlySavings.formatted())")
                    .font(.title3).fontWeight(.bold).foregroundStyle(ctSave)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text("이번 달 아낌").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

            if let h = entry.hero {
                VStack(spacing: 10) {
                    HStack(spacing: 14) {
                        WidgetSkillIcon(item: h, size: 60)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("아직이에요").font(.caption).fontWeight(.bold).foregroundStyle(ctHold)
                            Text(h.name).font(.headline).fontWeight(.bold).lineLimit(1)
                        }
                        Spacer()
                    }
                    // 앱 안 열고 위젯에서 바로 기록
                    HStack(spacing: 8) {
                        Button(intent: ResistIntent(itemId: h.id.uuidString)) {
                            Label("참았어요", systemImage: "hand.raised.fill")
                                .font(.caption).fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(ctSave)
                        Button(intent: BuyIntent(itemId: h.id.uuidString)) {
                            Label("샀어요", systemImage: "cart.fill")
                                .font(.caption).fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.secondary)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(14)
                .background(ctHold.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
            }

            Divider()

            // 나머지 참는 항목 — 짧게
            VStack(spacing: 10) {
                ForEach(entry.waiting.dropFirst().prefix(4)) { item in
                    HStack(spacing: 10) {
                        Text(item.emoji).font(.title3)
                        Text(item.name).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text("아직 \(item.remainingCooldown.widgetFormatted)")
                            .font(.subheadline).fontWeight(.bold).foregroundStyle(ctHold)
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
                           estimatedCost: 25000, category: "기타")
    ]
    return CoolTimeEntry(date: .now, items: items,
                         stats: WidgetStats(totalItems: 2, onCooldownCount: 2,
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
