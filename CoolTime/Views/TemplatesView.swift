import SwiftUI

/// 템플릿 선택 화면
struct TemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseManager.self) private var purchaseManager
    var manager: CooldownManager

    @State private var addedTemplates: Set<UUID> = []
    @State private var showToast = false
    @State private var lastAddedTemplateName: String = ""
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        ForEach(TemplateCategory.allCases, id: \.self) { category in
                            categorySection(category)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Color(.systemGroupedBackground))

                if showToast {
                    ToastView(
                        message: String(format: NSLocalizedString("'%@' 추가됨", comment: ""), lastAddedTemplateName),
                        icon: "checkmark.circle.fill",
                        color: AppTheme.ready
                    )
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
            .sheet(isPresented: $showingPaywall) {
                PaywallView(trigger: .itemLimit)
                    .environment(purchaseManager)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.yellow)
            }

            Text("추천 템플릿")
                .font(.title2)
                .fontWeight(.bold)

            Text("자주 사용하는 쿨타임 항목들이에요\n탭해서 바로 추가하세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Category Section

    private func categorySection(_ category: TemplateCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(category.rawValue)
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(category.templates.enumerated()), id: \.element.id) { index, template in
                    TemplateCard(
                        template: template,
                        isAdded: addedTemplates.contains(template.id)
                    ) {
                        addTemplate(template)
                    }

                    if index < category.templates.count - 1 {
                        Divider()
                            .padding(.leading, 80)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Actions

    private func addTemplate(_ template: CooldownTemplate) {
        guard manager.canAddItem else {
            showingPaywall = true
            return
        }
        manager.addFromTemplate(template)
        addedTemplates.insert(template.id)
        lastAddedTemplateName = template.name

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation { showToast = true }

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation { showToast = false }
            }
        }
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: CooldownTemplate
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 14) {
                // 이모지
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isAdded
                              ? AppTheme.ready.opacity(0.12)
                              : Color(.tertiarySystemBackground))
                        .frame(width: 50, height: 50)

                    if isAdded {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.ready)
                    } else {
                        Text(template.emoji)
                            .font(.system(size: 26))
                    }
                }

                // 텍스트
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(isAdded ? .secondary : .primary)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(formatCooldown(template.cooldownDuration))
                            .font(.caption)

                        if let cost = template.estimatedCost {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(Color(.tertiaryLabel))
                            Text("₩\(cost.formatted())")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // 추가 아이콘
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isAdded ? AppTheme.ready : AppTheme.cooldown)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
    }

    private func formatCooldown(_ duration: TimeInterval) -> String {
        let days = Int(duration / 86400)
        if days >= 30 {
            return String(format: NSLocalizedString("%d개월", comment: ""), days / 30)
        } else if days >= 7 {
            return String(format: NSLocalizedString("%d주", comment: ""), days / 7)
        } else {
            return String(format: NSLocalizedString("%d일", comment: ""), days)
        }
    }
}

#Preview {
    TemplatesView(manager: CooldownManager())
        .environment(PurchaseManager.shared)
}
