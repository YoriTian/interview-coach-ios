import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("我的")
                        .font(.system(size: 34, weight: .semibold))
                        .padding(.top, 12)

                    DeepSeekSettingsPanel()

                    SurfacePanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("产品能力")
                                .font(.system(size: 22, weight: .semibold))
                            CapabilityRow(icon: "doc.text.magnifyingglass", title: "简历解析", subtitle: "识别岗位、技能、项目关键词")
                            CapabilityRow(icon: "scope", title: "JD 专项出题", subtitle: "粘贴岗位描述，由 DeepSeek 生成针对性问题")
                            CapabilityRow(icon: "square.stack.3d.up", title: "\(viewModel.questionBank.questions.count) 题库", subtitle: "涵盖简历追问、技术专项、项目复盘、方案投标")
                            CapabilityRow(icon: "mic", title: "语音练习", subtitle: "中文语音转写 + 表达指标分析")
                            CapabilityRow(icon: "sparkles", title: "DeepSeek 评分", subtitle: "6 维评估 + 改进建议 + 优化回答")
                            CapabilityRow(icon: "graduationcap", title: "AI 教练", subtitle: "生成目标答案、答题框架、关键短句")
                            CapabilityRow(icon: "mouth", title: "背诵练习", subtitle: "复述评估：覆盖度、清晰度、流畅度、自信")
                            CapabilityRow(icon: "scope", title: "强化重点", subtitle: "自动汇总高频短板，指导下一轮练习")
                            CapabilityRow(icon: "play.rectangle", title: "学习资源", subtitle: "题目内直达文档、视频和专项资料")
                            CapabilityRow(icon: "calendar.badge.clock", title: "间隔重复", subtitle: "智能复习计划，遗忘曲线驱动")
                            CapabilityRow(icon: "exclamationmark.triangle", title: "错题本", subtitle: "低分题自动收集，重点突破")
                        }
                    }

                    if let profile = viewModel.resumeProfile {
                        ResumeSummaryView(
                            profile: profile,
                            generatedQuestionCount: viewModel.questionBank.aiTechGeneratedCount
                        )
                    }

                    SurfacePanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("数据管理")
                                .font(.system(size: 22, weight: .semibold))

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("已完成 \(viewModel.reviewStore.attempts.count) 次回答评分")
                                        .font(.system(size: 15))
                                    Text("掌握 \(viewModel.reviewStore.masteredCount) 题，学习中 \(viewModel.reviewStore.learningCount) 题")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }

                            if viewModel.questionBank.aiGeneratedCount > 0 {
                                Button(role: .destructive) {
                                    viewModel.clearAIGeneratedQuestions()
                                } label: {
                                    Label(
                                        "清除 \(viewModel.questionBank.aiGeneratedCount) 道 AI 生成题",
                                        systemImage: "sparkles"
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                }
                                .buttonStyle(.bordered)
                            }

                            Button(role: .destructive) {
                                showResetConfirmation = true
                            } label: {
                                Label("重置所有学习数据", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    SurfacePanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("备面Pro")
                                .font(.system(size: 17, weight: .semibold))
                            Text("版本 1.2.0 · 面试特训系统")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .alert("确认重置", isPresented: $showResetConfirmation) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) {
                    viewModel.resetReviewData()
                }
            } message: {
                Text("这会清除所有练习记录、掌握状态和错题数据。此操作不可撤销。")
            }
        }
    }
}

private struct CapabilityRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
