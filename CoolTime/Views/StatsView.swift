import SwiftUI
import Charts

/// 통계 화면
struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    var manager: CooldownManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 전체 요약
                    overallSummary
                    
                    // 준수율 차트
                    complianceChart
                    
                    // 카테고리별 통계
                    categoryStats
                    
                    // 최근 활동
                    recentActivity
                    
                    // 개별 아이템 상세
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
        }
    }
    
    // MARK: - Overall Summary
    
    private var overallSummary: some View {
        VStack(spacing: 16) {
            // 준수율 링
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
            
            // 요약 통계
            HStack(spacing: 24) {
                StatItem(
                    value: "\(manager.items.count)",
                    label: "총 아이템"
                )
                
                StatItem(
                    value: "\(totalUsageCount)",
                    label: "총 사용"
                )
                
                StatItem(
                    value: "\(totalBreakCount)",
                    label: "깬 횟수"
                )
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
    
    private var totalUsageCount: Int {
        manager.items.reduce(0) { $0 + $1.totalUseCount }
    }
    
    private var totalBreakCount: Int {
        manager.items.reduce(0) { $0 + $1.breakCount }
    }
    
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
                // iOS 16 이하 대체 UI
                ForEach(manager.items.filter { $0.totalUseCount > 0 }) { item in
                    HStack {
                        Text("\(item.emoji) \(item.name)")
                            .font(.caption)
                            .frame(width: 100, alignment: .leading)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(height: 20)
                                
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
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
                    Text(stat.category)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(stat.items)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(Int(stat.compliance * 100))%")
                        .font(.caption)
                        .foregroundStyle(barColor(for: stat.compliance))
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Recent Activity
    
    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 활동")
                .font(.headline)
            
            let activity = manager.recentActivity()
            let sortedDates = activity.keys.sorted(by: >).prefix(7)
            
            if sortedDates.isEmpty {
                Text("아직 활동이 없어요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(sortedDates), id: \.self) { date in
                    HStack {
                        Text(date, style: .date)
                            .font(.caption)
                        
                        Spacer()
                        
                        Text("\(activity[date] ?? 0)회 사용")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Item Details
    
    private var itemDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("상세 기록")
                .font(.headline)
            
            ForEach(manager.items) { item in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("총 사용")
                            Spacer()
                            Text("\(item.totalUseCount)회")
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("쿨타임 깬 횟수")
                            Spacer()
                            Text("\(item.breakCount)회")
                                .foregroundStyle(item.breakCount > 0 ? .red : .primary)
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("준수율")
                            Spacer()
                            Text("\(Int(item.complianceRate * 100))%")
                                .foregroundStyle(barColor(for: item.complianceRate))
                        }
                        .font(.caption)
                        
                        if let cost = item.estimatedCost, item.totalUseCount > 0 {
                            HStack {
                                Text("총 지출 (추정)")
                                Spacer()
                                Text("₩\((cost * item.totalUseCount).formatted())")
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                } label: {
                    HStack {
                        Text(item.emoji)
                        Text(item.name)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct StatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    StatsView(manager: CooldownManager())
}
