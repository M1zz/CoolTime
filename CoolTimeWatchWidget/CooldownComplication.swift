//
//  CooldownComplication.swift
//  손목을 들 때마다 보는 값 하나: 가장 먼저 끝나는 쿨타임의 남은 시간.
//  시간은 시스템이 세는 타이머 글자라 매초 다시 그리지 않아도 줄어든다.
//  쿨타임이 끝나는 시각마다 항목을 하나씩 두어, 하나가 끝나면 다음 것으로 넘어간다.
//  아이폰 위젯과 같은 칸에서 열린다 — 잠긴 칸이면 자물쇠만 보인다.
//

import WidgetKit
import SwiftUI

struct CooldownEntry: TimelineEntry {
    let date: Date
    let item: WatchCooldown?
    let locked: Bool
}

struct CooldownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CooldownEntry {
        CooldownEntry(date: .now, item: .init(id: UUID(), name: String(localized: "배달 음식"), emoji: "🍔",
                                              duration: 86_400, lastUsed: .now.addingTimeInterval(-40_000)),
                      locked: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (CooldownEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entries().first!)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CooldownEntry>) -> Void) {
        completion(Timeline(entries: entries(), policy: .never))
    }

    /// 지금 한 장 + 쿨타임이 끝나는 시각마다 한 장
    private func entries() -> [CooldownEntry] {
        guard let s = WatchStore.load() else { return [CooldownEntry(date: .now, item: nil, locked: false)] }
        guard s.unlocksComplication else { return [CooldownEntry(date: .now, item: nil, locked: true)] }
        let ends = s.items.compactMap(\.endsAt).filter { $0 > .now }
        // 하루 넘게 남은 것은 날로 보인다 → 하루씩 줄어드는 시각에도 한 장씩(한 달까지)
        let days = ends.flatMap { end in (1...30).map { end.addingTimeInterval(-Double($0) * 86_400) } }.filter { $0 > .now }
        let marks = Set(ends + days).sorted()
        return ([Date.now] + marks).map { CooldownEntry(date: $0, item: s.soonest(after: $0), locked: false) }
    }
}

struct CooldownComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CooldownEntry

    var body: some View {
        if let item = entry.item, let end = item.endsAt {
            let timer = end > entry.date ? item.remaining(at: entry.date, units: 1) : Text(verbatim: "")
            switch family {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Text(item.emoji).font(.caption)
                    timer.font(.system(.caption, design: .rounded).weight(.semibold).monospacedDigit())
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                }
            case .accessoryCorner:
                Text(item.emoji).font(.title3).widgetLabel { timer }
            case .accessoryInline:
                Text(verbatim: "\(item.emoji) ") + timer
            default:
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "\(item.emoji) \(item.name)").font(.headline).lineLimit(1).widgetAccentable()
                    timer.font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                    Text("남은 쿨타임").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            let symbol = entry.locked ? "lock.fill" : "hourglass"
            switch family {
            case .accessoryCircular, .accessoryCorner:
                Image(systemName: symbol).font(.title3).widgetAccentable()
            case .accessoryInline:
                Label(entry.locked ? "쿨타임" : "모두 써도 돼요", systemImage: symbol)
            default:
                VStack(alignment: .leading, spacing: 2) {
                    Label("쿨타임", systemImage: symbol).font(.headline).widgetAccentable()
                    Text(entry.locked ? "iPhone에서 Pro로 열 수 있어요" : "모두 써도 돼요")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

@main
struct CooldownComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CooldownSoonest", provider: CooldownProvider()) { entry in
            CooldownComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("남은 쿨타임")
        .description("가장 먼저 끝나는 쿨타임의 남은 시간을 보여 줘요.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}
