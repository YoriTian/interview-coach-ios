import SwiftUI

struct QuestionBankView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Binding var selectedTab: Int
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("题库")
                        .font(.system(size: 34, weight: .semibold))
                        .padding(.top, 12)

                    if viewModel.questionBank.aiGeneratedCount > 0 {
                        Label(
                            "AI 专项题 \(viewModel.questionBank.aiGeneratedCount) 道 · 技术栈 \(viewModel.questionBank.aiTechGeneratedCount) · JD \(viewModel.questionBank.aiJobGeneratedCount)",
                            systemImage: "sparkles"
                        )
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.blue)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    // Practice Mode Selector
                    PracticeModeSelector(selection: $viewModel.selectedPracticeMode) { mode in
                        viewModel.modeCount(for: mode)
                    }

                    // Search & Filter
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("搜索题目或关键词", text: $viewModel.searchText)
                                .font(.system(size: 15))
                                .focused($isSearchFocused)
                                .submitLabel(.done)
                                .onSubmit {
                                    dismissKeyboard()
                                }
                            if !viewModel.searchText.isEmpty {
                                Button { viewModel.searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        HStack(spacing: 10) {
                            Picker("分类", selection: $viewModel.selectedCategory) {
                                ForEach(viewModel.questionBank.categories, id: \.self) { Text($0) }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Picker("难度", selection: $viewModel.selectedDifficulty) {
                                ForEach(viewModel.questionBank.difficulties, id: \.self) { Text($0) }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }

                    if viewModel.selectedPracticeMode == .jobTarget {
                        jobTargetContextCard
                    } else if viewModel.selectedPracticeMode == .tech {
                        techStackContextCard
                    }

                    let visibleQuestions = viewModel.visibleQuestions

                    // Section Header
                    HStack {
                        Text(viewModel.selectedPracticeMode.title)
                            .font(.system(size: 20, weight: .semibold))
                        Spacer()
                        Text("\(visibleQuestions.count) 题")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }

                    // Questions List
                    if visibleQuestions.isEmpty {
                        SurfacePanel {
                            VStack(spacing: 14) {
                                Image(systemName: viewModel.selectedPracticeMode.systemImage)
                                    .font(.system(size: 40))
                                    .foregroundStyle(.blue)
                                Text(emptyMessage)
                                    .font(.system(size: 16, weight: .medium))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                    } else {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(visibleQuestions) { question in
                                SurfacePanel {
                                    VStack(alignment: .leading, spacing: 14) {
                                        HStack {
                                            RoleBadge(role: question.role)
                                            Text(question.difficulty.rawValue)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            MasteryBadge(text: viewModel.reviewStore.statusText(for: question))
                                        }

                                        Text(question.prompt)
                                            .font(.system(size: 17, weight: .semibold))
                                            .fixedSize(horizontal: false, vertical: true)
                                            .lineLimit(3)

                                        if !question.keywords.isEmpty {
                                            Text("关键词：\(question.keywords.prefix(5).joined(separator: "、"))")
                                                .font(.system(size: 14))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }

                                        Button {
                                            dismissKeyboard()
                                            viewModel.startPractice(with: [question])
                                            selectedTab = 2
                                        } label: {
                                            Label("练这一题", systemImage: "mic")
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 44)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        dismissKeyboard()
                    }
                }
            }
        }
    }

    private func dismissKeyboard() {
        isSearchFocused = false
        KeyboardDismissal.dismiss()
    }

    private var jobTargetContextCard: some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: PracticeMode.jobTarget.systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .frame(width: 40, height: 40)
                        .background(Color.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.jobTargetProfile?.title ?? "还没有目标岗位 JD")
                            .font(.system(size: 18, weight: .semibold))
                        Text(jobTargetContextText)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                if !viewModel.jobGapKeywords.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(viewModel.jobGapKeywords.prefix(8), id: \.self) { gap in
                            Text(gap)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.1), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Button {
                    selectedTab = 0
                } label: {
                    Label(viewModel.jobTargetProfile == nil ? "去首页粘贴 JD" : "去首页编辑 JD", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var techStackContextCard: some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: PracticeMode.tech.systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .frame(width: 40, height: 40)
                        .background(Color.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("技术栈专项")
                            .font(.system(size: 18, weight: .semibold))
                        Text(techStackContextText)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                if let techStack = viewModel.resumeProfile?.techStack, !techStack.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(techStack.prefix(10)) { entity in
                            Text(entity.name)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.cyan.opacity(0.1), in: Capsule())
                                .foregroundStyle(.cyan)
                        }
                    }
                }

                Button {
                    if viewModel.resumeProfile?.techStack.isEmpty == false {
                        viewModel.startTechStackPractice()
                        selectedTab = 2
                    } else {
                        selectedTab = 0
                    }
                } label: {
                    Label(viewModel.resumeProfile?.techStack.isEmpty == false ? "开始技术栈训练" : "去首页上传简历", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var emptyMessage: String {
        switch viewModel.selectedPracticeMode {
        case .jobTarget: return "先在首页粘贴目标岗位 JD\n系统会按岗位差距推荐专项题"
        case .tech: return "先在首页上传简历\n系统会抽取技术栈实体并按实体匹配题目"
        case .wrong: return "没有错题\n所有练习过的题目都得分 75 分以上"
        case .review: return "没有待复习题\n完成练习后系统会自动安排复习"
        case .drill: return "题库为空"
        default: return "该分类暂无题目\n可以切换其他练习模式"
        }
    }

    private var jobTargetContextText: String {
        if let profile = viewModel.jobTargetProfile {
            return "系统正在按 \(profile.primaryRole.rawValue)、\(profile.seniority.rawValue) 难度和岗位缺口推荐题目。"
        }
        return "粘贴 JD 后，这里会出现岗位专项题和需要优先补齐的能力点。"
    }

    private var techStackContextText: String {
        if let profile = viewModel.resumeProfile, !profile.techStack.isEmpty {
            return "系统正在按 \(profile.techStack.prefix(4).map(\.name).joined(separator: "、")) 等实体推荐题目，不按项目经历泛泛追问。"
        }
        return "上传简历后，这里会显示 Jenkins、Docker、K8S、Harbor 等技术栈实体和专项题。"
    }
}
