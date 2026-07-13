import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Binding var selectedTab: Int
    @State private var isImporterPresented = false
    @State private var isJobDescriptionEditorExpanded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("备面Pro")
                                .font(.system(size: 32, weight: .semibold, design: .default))
                                .foregroundStyle(.primary)
                            Text("AI驱动的面试特训系统")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 12)

                    trainingPlanCard

                    // Today Focus Card
                    todayFocusCard

                    // Stats Dashboard
                    HStack(spacing: 8) {
                        MetricPill(icon: "chart.bar", title: "平均分", value: "\(viewModel.reviewStore.averageScore)")
                        MetricPill(icon: "flame", title: "连续", value: "\(viewModel.reviewStore.streakDays)天")
                        MetricPill(icon: "checkmark.seal", title: "掌握", value: "\(viewModel.reviewStore.masteredCount)")
                        MetricPill(icon: "bell.badge", title: "待复习", value: "\(viewModel.dueReviewCount)")
                    }

                    // Resume or Upload
                    if let profile = viewModel.resumeProfile {
                        ResumeSummaryView(
                            profile: profile,
                            generatedQuestionCount: viewModel.questionBank.aiGeneratedCount,
                            isGeneratingQuestions: viewModel.isGeneratingTechQuestions,
                            onReplaceResume: { isImporterPresented = true },
                            onGenerateQuestions: {
                                Task {
                                    if await viewModel.generateTechStackQuestions() {
                                        selectedTab = 2
                                    }
                                }
                            },
                            onStartTechStackPractice: {
                                viewModel.startTechStackPractice()
                                selectedTab = 2
                            }
                        )
                    } else {
                        uploadResumePanel
                    }

                    jobDescriptionPanel

                    // Quick Actions
                    quickActionsRow

                    // Recommended Questions
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("推荐练习")
                                .font(.system(size: 22, weight: .semibold))
                            Spacer()
                            Text("\(viewModel.questionBank.questions.count) 题")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        ForEach(viewModel.recommendedQuestions.prefix(3)) { question in
                            Button {
                                viewModel.startPractice(with: [question])
                                selectedTab = 2
                            } label: {
                                QuestionRow(question: question, reviewStore: viewModel.reviewStore)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    PrimaryActionButton(title: "开始模拟面试", icon: "play.fill") {
                        viewModel.startMockInterview()
                        selectedTab = 2
                    }
                    .padding(.top, 4)

                    if let error = viewModel.importError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.pdf, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { await viewModel.importResume(from: url) }
                case .failure(let error):
                    viewModel.importError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Training Plan

    private var trainingPlanCard: some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 42, height: 42)
                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text("训练计划")
                        .font(.system(size: 22, weight: .semibold))

                    Spacer()

                    Text(viewModel.activeAIProviderName)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }

                Text(planSummary)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    planMetric(title: "目标岗位", value: targetRoleName, icon: "person.crop.rectangle")
                    planMetric(title: "总题库", value: "\(viewModel.questionBank.questions.count) 题", icon: "books.vertical")
                    planMetric(title: "技术栈", value: techStackMetricName, icon: "terminal")
                    planMetric(title: "岗位缺口", value: gapMetricName, icon: "scope")
                }

                Button {
                    viewModel.startMockInterview()
                    selectedTab = 2
                } label: {
                    Label("开始模拟面试", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func planMetric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 26, height: 26)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var targetRoleName: String {
        if let jobTarget = viewModel.jobTargetProfile {
            return jobTarget.primaryRole.rawValue
        }
        return viewModel.resumeProfile?.primaryRole.rawValue ?? "待上传简历"
    }

    private var gapMetricName: String {
        guard let jobTarget = viewModel.jobTargetProfile else { return "待粘贴 JD" }
        guard !jobTarget.gapKeywords.isEmpty else { return "已覆盖" }
        return "\(jobTarget.gapKeywords.count) 项"
    }

    private var techStackMetricName: String {
        guard let profile = viewModel.resumeProfile, !profile.techStack.isEmpty else { return "待上传" }
        return "\(profile.techStack.count) 项"
    }

    private var planSummary: String {
        if let jobTarget = viewModel.jobTargetProfile {
            return "已按 \(jobTarget.title) 调整训练顺序，优先练岗位要求和简历差距。"
        }
        if let profile = viewModel.resumeProfile {
            return "\(profile.summary)。今天优先练技术栈实体、错题和到期复习题。"
        }
        return "先上传简历或使用样例，系统会提取技术栈实体，再按 Jenkins、Docker、K8S、Harbor 等方向推荐题目。"
    }

    private func startTodayPlan() {
        if viewModel.dueReviewCount > 0 {
            viewModel.startPracticeForMode(.review)
        } else if viewModel.wrongQuestionCount > 0 {
            viewModel.startPracticeForMode(.wrong)
        } else if viewModel.jobTargetProfile != nil {
            viewModel.startJobTargetPractice()
        } else if viewModel.resumeProfile?.techStack.isEmpty == false {
            viewModel.startTechStackPractice()
        } else {
            viewModel.startPracticeForMode(.drill)
        }
        selectedTab = 2
    }

    // MARK: - Today Focus

    private var todayFocusCard: some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("今日焦点")
                        .font(.system(size: 20, weight: .semibold))
                    Spacer()
                    StreakBadge(days: viewModel.reviewStore.streakDays)
                }

                Text(viewModel.todayFocusRecommendation)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    let dueCount = viewModel.dueReviewCount
                    let wrongCount = viewModel.wrongQuestionCount

                    if dueCount > 0 {
                        Button {
                            viewModel.startPracticeForMode(.review)
                            selectedTab = 2
                        } label: {
                            Label("复习 \(dueCount) 题", systemImage: "calendar.badge.clock")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if wrongCount > 0 {
                        Button {
                            viewModel.startPracticeForMode(.wrong)
                            selectedTab = 2
                        } label: {
                            Label("错题 \(wrongCount)", systemImage: "exclamationmark.triangle")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.bordered)
                    }

                    if dueCount == 0 && wrongCount == 0 {
                        Button {
                            if viewModel.resumeProfile?.techStack.isEmpty == false {
                                viewModel.startTechStackPractice()
                            } else {
                                viewModel.startPracticeForMode(.drill)
                            }
                            selectedTab = 2
                        } label: {
                            Label(viewModel.resumeProfile?.techStack.isEmpty == false ? "技术栈专项" : "今日10题", systemImage: viewModel.resumeProfile?.techStack.isEmpty == false ? "terminal" : "timer")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsRow: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            quickAction(icon: "timer", title: "今日10题", color: .blue) {
                viewModel.startPracticeForMode(.drill)
                selectedTab = 2
            }
            quickAction(icon: PracticeMode.tech.systemImage, title: "技术栈", color: .cyan) {
                viewModel.startTechStackPractice()
                if !viewModel.techStackQuestions.isEmpty {
                    selectedTab = 2
                }
            }
            quickAction(icon: "exclamationmark.triangle", title: "错题本", color: .orange) {
                viewModel.startPracticeForMode(.wrong)
                selectedTab = 2
            }
            quickAction(icon: PracticeMode.product.systemImage, title: "产品经理", color: .teal) {
                viewModel.startPracticeForMode(.product)
                selectedTab = 2
            }
            quickAction(icon: PracticeMode.implementation.systemImage, title: "实施工程师", color: .indigo) {
                viewModel.startPracticeForMode(.implementation)
                selectedTab = 2
            }
            quickAction(icon: PracticeMode.jobTarget.systemImage, title: "岗位JD", color: .cyan) {
                viewModel.startJobTargetPractice()
                if !viewModel.jobTargetQuestions.isEmpty {
                    selectedTab = 2
                }
            }
            quickAction(icon: "rectangle.on.rectangle.angled", title: "闪卡", color: .purple) {
                viewModel.startPracticeForMode(.flashcard)
                selectedTab = 2
            }
            quickAction(icon: "person.text.rectangle", title: "简历追问", color: .green) {
                viewModel.startPracticeForMode(.resume)
                selectedTab = 2
            }
        }
    }

    // MARK: - Job Description

    private var jobDescriptionPanel: some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "scope")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .frame(width: 46, height: 46)
                        .background(Color.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("目标岗位 JD")
                            .font(.system(size: 22, weight: .semibold))
                        Text(jobDescriptionSubtitle)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                if viewModel.jobTargetProfile == nil || isJobDescriptionEditorExpanded {
                    jobDescriptionEditor
                } else if let profile = viewModel.jobTargetProfile {
                    jobDescriptionSummary(profile)
                }
            }
        }
    }

    private var jobDescriptionEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $viewModel.jobDescriptionText)
                .font(.system(size: 15))
                .frame(minHeight: 132)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    viewModel.applyJobDescriptionText()
                    if viewModel.jobTargetProfile != nil {
                        isJobDescriptionEditorExpanded = false
                    }
                } label: {
                    Label("分析 JD", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.loadSampleJobDescription()
                    isJobDescriptionEditorExpanded = false
                } label: {
                    Label("样例", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
            }

            if viewModel.jobTargetProfile != nil {
                Button("取消编辑") {
                    isJobDescriptionEditorExpanded = false
                }
                .font(.system(size: 14, weight: .medium))
            }
        }
    }

    private func jobDescriptionSummary(_ profile: JobDescriptionProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.title)
                        .font(.system(size: 17, weight: .semibold))
                    Text(profile.summary)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(viewModel.jobTargetQuestions.count) 题")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }

            if !profile.requiredSkills.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("岗位要求")
                        .font(.system(size: 15, weight: .semibold))
                    FlowLayout(spacing: 8) {
                        ForEach(profile.requiredSkills.prefix(8), id: \.self) { skill in
                            jobChip(skill, color: .blue)
                        }
                    }
                }
            }

            if !profile.gapKeywords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("优先补齐")
                        .font(.system(size: 15, weight: .semibold))
                    FlowLayout(spacing: 8) {
                        ForEach(profile.gapKeywords.prefix(8), id: \.self) { gap in
                            jobChip(gap, color: .orange)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.startJobTargetPractice()
                    selectedTab = 2
                } label: {
                    Label("JD专项训练", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)

                Menu {
                    Button("重新编辑") {
                        isJobDescriptionEditorExpanded = true
                    }
                    Button("清除 JD", role: .destructive) {
                        viewModel.clearJobDescription()
                        isJobDescriptionEditorExpanded = false
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 48, height: 44)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func jobChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.1), in: Capsule())
            .foregroundStyle(color)
    }

    private var jobDescriptionSubtitle: String {
        if let profile = viewModel.jobTargetProfile {
            return "已按 \(profile.primaryRole.rawValue) 和 \(profile.seniority.rawValue) 难度生成岗位专项训练。"
        }
        return "把招聘 JD 粘贴进来，系统会提取必备技能、职责和简历差距。"
    }

    private func quickAction(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Upload Resume

    private var uploadResumePanel: some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 46, height: 46)
                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("上传简历匹配题库")
                            .font(.system(size: 22, weight: .semibold))
                        Text("支持 PDF 和 TXT。系统会抽取技术栈实体，优先围绕 Jenkins、CI/CD、K8S、Harbor、Docker 等方向出题。")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 12) {
                    Button { isImporterPresented = true } label: {
                        Label(viewModel.isImportingResume ? "解析中" : "选择简历", systemImage: "arrow.up.doc")
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isImportingResume)

                    Button { viewModel.loadSampleResume() } label: {
                        Label("体验样例", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
