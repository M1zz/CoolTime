//
//  widget.swift
//  CoolTime Widget
//
//  Created by Leeo on 12/1/25.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct CoolTimeProvider: TimelineProvider {
    func placeholder(in context: Context) -> CoolTimeEntry {
        CoolTimeEntry(date: Date(), items: [], stats: WidgetStats())
    }

    func getSnapshot(in context: Context, completion: @escaping (CoolTimeEntry) -> Void) {
        let items = WidgetDataStore.loadItems()
        let stats = WidgetDataStore.loadStats()
        let entry = CoolTimeEntry(date: Date(), items: items, stats: stats)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CoolTimeEntry>) -> Void) {
        let items = WidgetDataStore.loadItems()
        let stats = WidgetDataStore.loadStats()

        var entries: [CoolTimeEntry] = []
        let currentDate = Date()

        // 매 분마다 업데이트
        for minuteOffset in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = CoolTimeEntry(date: entryDate, items: items, stats: stats)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct CoolTimeEntry: TimelineEntry {
    let date: Date
    let items: [WidgetCooldownItem]
    let stats: WidgetStats

    var availableItems: [WidgetCooldownItem] {
        items.filter { !$0.isOnCooldown }
    }

    var onCooldownItems: [WidgetCooldownItem] {
        items.filter { $0.isOnCooldown }.sorted { $0.remainingCooldown < $1.remainingCooldown }
    }

    var nextAvailable: WidgetCooldownItem? {
        onCooldownItems.first
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: CoolTimeEntry

    private var readyColor: Color {
        Color(red: 0.2, green: 0.7, blue: 0.3)
    }

    private var cooldownColor: Color {
        Color(red: 0.3, green: 0.5, blue: 0.9)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더
            HStack {
                Text("쿨타임")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Image(systemName: "clock.fill")
                    .foregroundStyle(cooldownColor)
            }

            Spacer()

            if let next = entry.nextAvailable {
                // 다음 사용 가능 아이템
                VStack(alignment: .leading, spacing: 4) {
                    Text(next.emoji)
                        .font(.title)

                    Text(next.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(next.remainingCooldown.widgetFormatted)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(cooldownColor)
                }
            } else if entry.availableItems.isEmpty && entry.items.isEmpty {
                // 아이템 없음
                VStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("아이템 추가")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                // 모두 사용 가능
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(readyColor)

                    Text("모두 사용 가능!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(readyColor)

                    Text("\(entry.availableItems.count)개")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: CoolTimeEntry

    private var readyColor: Color {
        Color(red: 0.2, green: 0.7, blue: 0.3)
    }

    private var cooldownColor: Color {
        Color(red: 0.3, green: 0.5, blue: 0.9)
    }

    var body: some View {
        HStack(spacing: 16) {
            // 왼쪽: 요약
            VStack(alignment: .leading, spacing: 8) {
                Text("쿨타임")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                HStack(spacing: 12) {
                    StatBox(
                        value: "\(entry.availableItems.count)",
                        label: "사용 가능",
                        color: readyColor
                    )

                    StatBox(
                        value: "\(entry.onCooldownItems.count)",
                        label: "대기 중",
                        color: cooldownColor
                    )
                }

                if entry.stats.complianceRate > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption2)
                        Text("\(Int(entry.stats.complianceRate * 100))% 준수")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Divider()

            // 오른쪽: 쿨타임 목록
            VStack(alignment: .leading, spacing: 6) {
                if entry.onCooldownItems.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(readyColor)
                        Text("모두 사용 가능!")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(readyColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(entry.onCooldownItems.prefix(3)) { item in
                        HStack(spacing: 8) {
                            Text(item.emoji)
                                .font(.body)

                            Text(item.name)
                                .font(.caption)
                                .lineLimit(1)

                            Spacer()

                            Text(item.remainingCooldown.widgetFormatted)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(cooldownColor)
                        }
                    }

                    if entry.onCooldownItems.count > 3 {
                        Text("+\(entry.onCooldownItems.count - 3)개 더")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let entry: CoolTimeEntry

    private var readyColor: Color {
        Color(red: 0.2, green: 0.7, blue: 0.3)
    }

    private var cooldownColor: Color {
        Color(red: 0.3, green: 0.5, blue: 0.9)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("쿨타임")
                        .font(.title2)
                        .fontWeight(.bold)

                    if entry.stats.monthlySavings > 0 {
                        Text("이번 달 ₩\(entry.stats.monthlySavings.formatted()) 절약")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 준수율 원
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 4)
                        .frame(width: 50, height: 50)

                    Circle()
                        .trim(from: 0, to: entry.stats.complianceRate)
                        .stroke(readyColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(entry.stats.complianceRate * 100))%")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
            }

            Divider()

            // 사용 가능 섹션
            if !entry.availableItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(readyColor)
                        Text("사용 가능")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(entry.availableItems.prefix(5)) { item in
                                VStack(spacing: 4) {
                                    Text(item.emoji)
                                        .font(.title2)
                                    Text(item.name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .frame(width: 50)
                            }
                        }
                    }
                }
            }

            // 쿨타임 중 섹션
            if !entry.onCooldownItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(cooldownColor)
                        Text("쿨타임 중")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    ForEach(entry.onCooldownItems.prefix(4)) { item in
                        HStack(spacing: 12) {
                            Text(item.emoji)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.caption)
                                    .fontWeight(.medium)

                                // 프로그레스 바
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color(.systemGray5))
                                            .frame(height: 4)

                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(cooldownColor)
                                            .frame(width: geo.size.width * item.cooldownProgress, height: 4)
                                    }
                                }
                                .frame(height: 4)
                            }

                            Spacer()

                            Text(item.remainingCooldown.widgetFormatted)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(cooldownColor)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Helper Views

struct StatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Widget Entry View

struct CoolTimeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: CoolTimeProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Main Widget

struct CoolTimeWidget: Widget {
    let kind: String = "CoolTimeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoolTimeProvider()) { entry in
            CoolTimeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("쿨타임")
        .description("쿨타임 현황을 한눈에 확인하세요")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Accessory Widget (잠금화면)

struct CoolTimeAccessoryProvider: TimelineProvider {
    func placeholder(in context: Context) -> CoolTimeAccessoryEntry {
        CoolTimeAccessoryEntry(date: Date(), nextItem: nil, availableCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (CoolTimeAccessoryEntry) -> Void) {
        let items = WidgetDataStore.loadItems()
        let onCooldown = items.filter { $0.isOnCooldown }.sorted { $0.remainingCooldown < $1.remainingCooldown }
        let available = items.filter { !$0.isOnCooldown }

        let entry = CoolTimeAccessoryEntry(
            date: Date(),
            nextItem: onCooldown.first,
            availableCount: available.count
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CoolTimeAccessoryEntry>) -> Void) {
        let items = WidgetDataStore.loadItems()
        let onCooldown = items.filter { $0.isOnCooldown }.sorted { $0.remainingCooldown < $1.remainingCooldown }
        let available = items.filter { !$0.isOnCooldown }

        var entries: [CoolTimeAccessoryEntry] = []
        let currentDate = Date()

        for minuteOffset in 0..<30 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = CoolTimeAccessoryEntry(
                date: entryDate,
                nextItem: onCooldown.first,
                availableCount: available.count
            )
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct CoolTimeAccessoryEntry: TimelineEntry {
    let date: Date
    let nextItem: WidgetCooldownItem?
    let availableCount: Int
}

struct CoolTimeAccessoryWidget: Widget {
    let kind: String = "CoolTimeAccessoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoolTimeAccessoryProvider()) { entry in
            CoolTimeAccessoryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("쿨타임")
        .description("다음 쿨타임 종료 시간")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct CoolTimeAccessoryView: View {
    @Environment(\.widgetFamily) var family
    let entry: CoolTimeAccessoryEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            if let item = entry.nextItem {
                // 프로그레스 링
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: item.cooldownProgress)
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(item.emoji)
                        .font(.caption)
                    Text(item.remainingCooldown.widgetFormatted)
                        .font(.caption2)
                        .fontWeight(.bold)
                }
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark")
                        .font(.title3)
                    Text("\(entry.availableCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
            }
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            if let item = entry.nextItem {
                Text(item.emoji)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(item.remainingCooldown.widgetFormatted)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("모두 사용 가능")
                        .font(.caption)
                        .fontWeight(.medium)

                    Text("\(entry.availableCount)개 아이템")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var inlineView: some View {
        if let item = entry.nextItem {
            Text("\(item.emoji) \(item.name) \(item.remainingCooldown.widgetFormatted)")
        } else {
            Text("✅ \(entry.availableCount)개 사용 가능")
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    CoolTimeWidget()
} timeline: {
    CoolTimeEntry(date: .now, items: [], stats: WidgetStats())
}

#Preview(as: .systemMedium) {
    CoolTimeWidget()
} timeline: {
    CoolTimeEntry(date: .now, items: [], stats: WidgetStats())
}

#Preview(as: .systemLarge) {
    CoolTimeWidget()
} timeline: {
    CoolTimeEntry(date: .now, items: [], stats: WidgetStats())
}
