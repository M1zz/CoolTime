import SwiftUI
import Charts

/// 통계 화면
struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseManager.self) private var purchaseManager
    var manager: CooldownManager

    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    overallSummary
                    complianceChart
                    categoryStats
                    recentActivity
                    usageHistorySection
                    itemDetails
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("통계")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(trigger: .statsHistory)
                    .environment(purchaseManager)
            }
        }
    }

    // MARK: - Overall Summary

    private var overallSummary: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: manager.overallComplianceRate)
                    .stroke(
                        complianceGradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(Int(manager.overallComplianceRate * 100))%")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("전체 준수율")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 24) {
                StatItem(value: "\(manager.items.count)", label: "총 아이템")
                StatItem(value: "\(totalUsageCount)", label: "총 사용")
                StatItem(value: "\(totalBreakCount)", label: "깬 횟수")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var complianceGradient: LinearGradient {
        let rate = manager.overallComplianceRate
        let colors: [Color]
        if rate >= 0.8 {
            colors = [Color(red: 0.2, green: 0.7, blue: 0.3), Color(red: 0.0, green: 0.6, blue: 0.6)]
        } else if rate >= 0.5 {
            colors = [Color(red: 0.9, green: 0.6, blue: 0.2), Color(red: 0.95, green: 0.75, blue: 0.3)]
        } else {
            colors = [Color(red: 0.9, green: 0.3, blue: 0.3), Color(red: 0.9, green: 0.5, blue: 0.2)]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    private var totalUsageCount: Int { manager.items.reduce(0) { $0 + $1.totalUseCount } }
    private var totalBreakCount: Int { manager.items.reduce(0) { $0 + $1.breakCount } }

    // MARK: - Compliance Chart

    private var complianceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("아이템별 준수율")
                .font(.headline)

            if #available(iOS 17.0, *) {
                Chart(manager.items.filter { $0.totalUseCount > 0 }) { item in
                    BarMark(
                        x: .value("준수율", item.complianceRate * 100),
                        y: .value("아이템", "\(item.emoji) \(item.name)")
                    )
                    .foregroundStyle(barColor(for: item.complianceRate))
                }
                .frame(height: CGFloat(manager.items.filter { $0.totalUseCount > 0 }.count) * 40)
                .chartXScale(domain: 0...100)
            } else {
                ForEach(manager.items.filter { $0.totalUseCount > 0 }) { item in
                    HStack {
                        Text("\(item.emoji) \(item.name)")
                            .font(.caption)
                            .frame(width: 100, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color(.systemGray5)).frame(height: 20)
                                Rectangle()
                                    .fill(barColor(for: item.complianceRate))
                                    .frame(width: geo.size.width * item.complianceRate, height: 20)
                            }
                            .cornerRadius(4)
                        }
                        .frame(height: 20)

                        Text("\(Int(item.complianceRate * 100))%")
                            .font(.caption)
                            .frame(width: 40)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func barColor(for rate: Double) -> Color {
        if rate >= 0.8 { return Color(red: 0.2, green: 0.7, blue: 0.3) }
        if rate >= 0.5 { return Color(red: 0.9, green: 0.6, blue: 0.2) }
        return Color(red: 0.9, green: 0.3, blue: 0.3)
    }

    // MARK: - Category Stats

    private var categoryStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("카테고리별")
                .font(.headline)

            ForEach(manager.statsByCategory(), id: \.category) { stat in
                HStack {
                    Text(stat.category).font(.subheadline)
                    Spacer()
                    Text("\(stat.items)개").font(.caption).foregroundStyle(.secondary)
                    Text("\(Int(stat.compliance * 100))%")
                        .font(.caption)
                        .foregroundStyle(barColor(for: stat.compliance))
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Recent Activity (무료: 7일 / Pro: 전체)

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("최근 활동")
                    .font(.headline)
                Spacer()
                if !purchaseManager.isPro {
                    Text("7일")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            let allActivity = manager.recentActivity()
            let cutoff: Date? = purchaseManager.isPro ? nil : Calendar.current.date(byAdding: .day, value: -PurchaseManager.freeStatsDays, to: Date())
            let sortedDates = allActivity.keys
                .filter { cutoff == nil || $0 >= cutoff! }
                .sorted(by: >)
                .prefix(purchaseManager.isPro ? 30 : PurchaseManager.freeStatsDays)

            if sortedDates.isEmpty {
                Text("아직 활동이 없어요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(sortedDates), id: \.self) { date in
                    HStack {
                        Text(date, style: .date).font(.caption)
                        Spacer()
                        Text("\(allActivity[date] ?? 0)회 사용").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Usage History Section (Pro 전용 상세 이력)

    private var usageHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("상세 사용 이력")
                    .font(.headline)

                Spacer()

                if !purchaseManager.isPro {
                    proLockBadge
                }
            }

            if purchaseManager.isPro {
                proUsageHistory
            } else {
                lockedHistoryPreview
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var proLockBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.caption2)
            Text("PRO")
                .font(.caption2)
                .fontWeight(.heavy)
                .kerning(0.5)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(AppTheme.cooldown))
    }

    private var proUsageHistory: some View {
        let allRecords: [(item: String, emoji: String, record: UsageRecord)] = manager.items.flatMap { item in
            item.usageHistory.map { (item.name, item.emoji, $0) }
        }.sorted { $0.record.date > $1.record.date }

        return Group {
            if allRecords.isEmpty {
                Text("아직 기록이 없어요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(allRecords.prefix(20), id: \.record.id) { entry in
                    HStack(spacing: 10) {
                        Text(entry.emoji).font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.item)
                                .font(.caption)
                                .fontWeight(.medium)

                            if entry.record.brokeCooldown {
                                Text("쿨타임 깨기")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.warning)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(entry.record.date, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if let cost = entry.record.cost {
                                Text("₩\(cost.formatted())")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    Divider()
                }
            }
        }
    }

    private var lockedHistoryPreview: some View {
        ZStack {
            // 흐릿한 미리보기
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 10) {
                        Circle().fill(Color(.systemGray4)).frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray4))
                                .frame(width: 80, height: 10)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(width: 50, height: 8)
                        }
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(width: 40, height: 10)
                    }
                }
            }
            .blur(radius: 4)

            // 잠금 오버레이
            Button { showingPaywall = true } label: {
                VStack(spacing: 10) {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.cooldown)

                    Text("Pro에서 전체 이력을 확인하세요")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground).opacity(0.9))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Item Details

    private var itemDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("아이템 상세")
                .font(.headline)

            ForEach(manager.items) { item in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("총 사용"); Spacer(); Text("\(item.totalUseCount)회")
                        }
                        .font(.caption)

                        HStack {
                            Text("쿨타임 깬 횟수"); Spacer()
                            Text("\(item.breakCount)회")
                                .foregroundStyle(item.breakCount > 0 ? .red : .primary)
                        }
                        .font(.caption)

                        HStack {
                            Text("준수율"); Spacer()
                            Text("\(Int(item.complianceRate * 100))%")
                                .foregroundStyle(barColor(for: item.complianceRate))
                        }
                        .font(.caption)

                        if let cost = item.estimatedCost, item.totalUseCount > 0 {
                            HStack {
                                Text("총 지출 (추정)"); Spacer()
                                Text("₩\((cost * item.totalUseCount).formatted())")
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                } label: {
                    HStack {
                        Text(item.emoji)
                        Text(item.name).font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}

struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2).fontWeight(.bold)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    StatsView(manager: CooldownManager())
        .environment(PurchaseManager.shared)
}
