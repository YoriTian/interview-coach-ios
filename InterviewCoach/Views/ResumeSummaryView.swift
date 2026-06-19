import SwiftUI

struct ResumeSummaryView: View {
    let profile: ResumeProfile
    var onStartTechStackPractice: (() -> Void)? = nil

    var body: some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.candidateName ?? "简历画像")
                            .font(.system(size: 22, weight: .semibold))
                        Text(profile.headline)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Text("\(Int(profile.confidence * 100))%")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .accessibilityLabel("匹配置信度 \(Int(profile.confidence * 100))%")
                }

                HStack {
                    ForEach(profile.matchedRoles.prefix(3)) { role in
                        RoleBadge(role: role)
                    }
                }

                techStackSection

                if let onStartTechStackPractice, !techStackEntities.isEmpty {
                    Button(action: onStartTechStackPractice) {
                        Label("技术栈专项训练", systemImage: "terminal")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var techStackEntities: [TechStackEntity] {
        if !profile.techStack.isEmpty {
            return profile.techStack
        }
        return profile.skills.map { skill in
            TechStackEntity(name: skill, category: .other, confidence: 0.5, evidence: [skill])
        }
    }

    private var techStackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("技术栈实体")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(techStackEntities.count) 项")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }

            if techStackEntities.isEmpty {
                Text("还没有识别到技术栈，建议重新上传包含工具、平台、框架和中间件的简历。")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(techStackEntities.prefix(14)) { entity in
                        techStackChip(entity)
                    }
                }
            }

            if !profile.projectKeywords.isEmpty {
                Text("当前训练会优先按技术栈出题，项目经历仅作为表达证据，不参与技术专项排序。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func techStackChip(_ entity: TechStackEntity) -> some View {
        let color = color(for: entity.category)
        return HStack(spacing: 5) {
            Image(systemName: entity.category.symbolName)
                .font(.system(size: 11, weight: .semibold))
            Text(entity.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Text(entity.category.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color.opacity(0.78))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.1), in: Capsule())
        .foregroundStyle(color)
    }

    private func color(for category: TechStackCategory) -> Color {
        switch category {
        case .ciCd: return .blue
        case .container: return .teal
        case .orchestrator: return .indigo
        case .registry: return .cyan
        case .cloudNative: return .mint
        case .automation: return .purple
        case .operatingSystem: return .gray
        case .database: return .orange
        case .middleware: return .brown
        case .monitoring: return .red
        case .language: return .green
        case .mobile: return .pink
        case .frontend: return .yellow
        case .backend: return .blue
        case .ai: return .purple
        case .other: return .secondary
        }
    }
}
