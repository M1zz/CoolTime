import SwiftUI

/// 템플릿 선택 화면
struct TemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    var manager: CooldownManager
    
    @State private var selectedCategory: TemplateCategory?
    @State private var addedTemplates: Set<UUID> = []
    @State private var showToast = false
    @State private var lastAddedTemplateName: String = ""
    
    var body: some View {
        NavigationStack {
            // 토스트뷰 분리를 위해
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 24) {
                        // 헤더
                        VStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.largeTitle)
                                .foregroundStyle(.yellow)
                            
                            Text("추천 템플릿")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("자주 사용하는 쿨타임 항목들이에요\n탭해서 바로 추가하세요")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        
                        // 카테고리별 템플릿
                        ForEach(TemplateCategory.allCases, id: \.self) { category in
                            categorySection(category)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                
                // 토스트메세지
                if showToast {
                    ToastView(
                        message: "'\(lastAddedTemplateName)' 추가됨",
                        icon: "checkmark.circle.fill",
                        color: AppTheme.ready)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 10)
                    .zIndex(1)
                }
            }
            .navigationTitle("템플릿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }
    
    private func categorySection(_ category: TemplateCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.rawValue)
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(category.templates) { template in
                    TemplateCard(
                        template: template,
                        isAdded: addedTemplates.contains(template.id)
                    ) {
                        addTemplate(template)
                    }
                }
            }
        }
    }
    
    private func addTemplate(_ template: CooldownTemplate) {
        manager.addFromTemplate(template)
        addedTemplates.insert(template.id)
        lastAddedTemplateName = template.name
        
        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 토스트 표시
        showToast = true
        
        // 0.5초 후 토스트 숨김
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                withAnimation {
                    showToast = false
                }
            }
        }
    }
}

struct TemplateCard: View {
    let template: CooldownTemplate
    let isAdded: Bool
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(.tertiarySystemBackground))
                        .frame(width: 50, height: 50)
                    
                    if isAdded {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .font(.title3)
                    } else {
                        Text(template.emoji)
                            .font(.title2)
                    }
                }
                
                Text(template.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text(formatCooldown(template.cooldownDuration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                if let cost = template.estimatedCost {
                    Text("₩\(cost.formatted())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isAdded ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .disabled(isAdded)
    }
    
    private func formatCooldown(_ duration: TimeInterval) -> String {
        let days = Int(duration / 86400)
        if days >= 30 {
            return "\(days / 30)개월"
        } else if days >= 7 {
            return "\(days / 7)주"
        } else {
            return "\(days)일"
        }
    }
}

#Preview {
    TemplatesView(manager: CooldownManager())
}
