import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Binding var selectedTab: Int
    @StateObject private var speechService = SpeechRecognitionService()
    @State private var recitationText = ""
    @State private var recordingError: String?
    @State private var isRecitingMode = false
    @State private var showAnswer = false
    @State private var showFollowUps = false
    @State private var now = Date()
    @FocusState private var focusedInput: PracticeInputFocus?

    private let sessionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Color.clear
                            .frame(height: 0)
                            .id(PracticeScrollTarget.top)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("模拟面试")
                                    .font(.system(size: 34, weight: .semibold))
                                Text(viewModel.isMockSessionActive ? "整场模拟 · \(viewModel.progressText)" : viewModel.progressText)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.top, 12)

                        if viewModel.isMockSessionActive {
                            mockSessionStatusCard
                        } else if let report = viewModel.lastMockSessionReport {
                            mockSessionCompletedCard(report)
                        }

                        if let question = viewModel.currentQuestion {
                            if viewModel.selectedPracticeMode == .flashcard {
                                flashcardView(question: question)
                            } else {
                                normalPracticeView(question: question)
                            }
                            navigationButtons
                        } else {
                            emptyState
                        }

                        if let error = viewModel.importError {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Color(.systemGroupedBackground))
                .onChange(of: viewModel.currentQuestion?.id) { _, _ in
                    resetState()
                    dismissKeyboard()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(PracticeScrollTarget.top, anchor: .top)
                    }
                }
                .onChange(of: viewModel.draftAnswer) { _, _ in
                    viewModel.syncCurrentMockAnswer()
                }
                .onChange(of: speechService.transcript) { _, newValue in
                    if speechService.isRecording {
                        if isRecitingMode {
                            recitationText = newValue
                        } else {
                            viewModel.draftAnswer = newValue
                        }
                    }
                }
                .onDisappear {
                    dismissKeyboard()
                    speechService.stopRecording()
                }
                .onReceive(sessionTimer) { value in
                    if viewModel.isMockSessionActive {
                        now = value
                    }
                }
            }
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

    private func toggleRecording() async {
        do {
            recordingError = nil
            try await speechService.toggle()
        } catch {
            recordingError = error.localizedDescription
        }
    }

    private func resetState() {
        dismissKeyboard()
        isRecitingMode = false
        showAnswer = false
        showFollowUps = false
        recordingError = nil
        recitationText = ""
    }

    private func dismissKeyboard() {
        focusedInput = nil
        KeyboardDismissal.dismiss()
    }

    private var answerExpressionMetrics: ExpressionMetrics {
        if speechService.expressionMetrics.characterCount > 0 {
            return speechService.expressionMetrics
        }
        return ExpressionMetrics.detect(in: viewModel.draftAnswer)
    }

    private var recitationExpressionMetrics: ExpressionMetrics {
        if speechService.expressionMetrics.characterCount > 0 {
            return speechService.expressionMetrics
        }
        return ExpressionMetrics.detect(in: recitationText)
    }

    private var mockSessionStatusCard: some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "person.2.wave.2")
                        .foregroundStyle(.blue)
                    Text("整场模拟")
                        .font(.system(size: 20, weight: .semibold))
                    Spacer()
                    Text(MockSessionReport.durationText(viewModel.mockSessionElapsedSeconds(now: now)))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    sessionMetric(title: "进度", value: viewModel.progressText, icon: "list.number")
                    sessionMetric(title: "已回答", value: "\(viewModel.mockSessionAnsweredCount)/\(viewModel.currentQuestions.count)", icon: "text.bubble")
                    sessionMetric(title: "AI评分", value: "\(viewModel.mockSessionScoredCount)", icon: "checkmark.seal")
                }

                Button {
                    dismissKeyboard()
                    speechService.stopRecording()
                    _ = viewModel.completeMockSession()
                    resetState()
                } label: {
                    Label("结束并生成报告", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func mockSessionCompletedCard(_ report: MockSessionReport) -> some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(.green)
                    Text("报告已生成")
                        .font(.system(size: 20, weight: .semibold))
                    Spacer()
                    Text(report.averageScore.map { "\($0) 分" } ?? "待评分")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.blue)
                }

                Text("完成 \(report.answeredCount)/\(report.questionCount) 题，用时 \(MockSessionReport.durationText(report.durationSeconds))。报告已保存到复盘页。")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    viewModel.selectedReviewSection = 3
                    selectedTab = 3
                } label: {
                    Label("查看面试报告", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func sessionMetric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Flashcard

    @ViewBuilder
    private func flashcardView(question: InterviewQuestion) -> some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    RoleBadge(role: question.role)
                    Spacer()
                    Text("闪卡模式")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.1), in: Capsule())
                }

                Text(question.prompt)
                    .font(.system(size: 22, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                if showAnswer {
                    Divider()

                    if !question.idealPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("答题要点")
                                .font(.system(size: 15, weight: .semibold))
                            ForEach(Array(question.idealPoints.enumerated()), id: \.offset) { idx, point in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Color.blue, in: Circle())
                                    Text(point)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    if !question.sampleAnswer.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("参考思路")
                                .font(.system(size: 15, weight: .semibold))
                            Text(question.sampleAnswer)
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        assessButton("不熟", .red) {
                            viewModel.recordFlashcardResult(score: 30)
                            viewModel.goToNextQuestion(); resetState()
                        }
                        assessButton("模糊", .orange) {
                            viewModel.recordFlashcardResult(score: 60)
                            viewModel.goToNextQuestion(); resetState()
                        }
                        assessButton("掌握", .green) {
                            viewModel.recordFlashcardResult(score: 90)
                            viewModel.goToNextQuestion(); resetState()
                        }
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { showAnswer.toggle() }
                } label: {
                    Label(showAnswer ? "隐藏答案" : "翻转看答案", systemImage: showAnswer ? "eye.slash" : "eye")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
        }
    }

    private func assessButton(_ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.bordered)
        .tint(color)
    }

    // MARK: - Normal Practice

    @ViewBuilder
    private func normalPracticeView(question: InterviewQuestion) -> some View {
        // Question Card
        SurfacePanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    RoleBadge(role: question.role)
                    Spacer()
                    MasteryBadge(text: viewModel.reviewStore.statusText(for: question))
                }

                Text(question.prompt)
                    .font(.system(size: 22, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                if !question.keywords.isEmpty {
                    Text("建议覆盖：\(question.keywords.prefix(6).joined(separator: "、"))")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }

                if question.timeLimitSeconds > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 12))
                        Text("建议 \(question.timeLimitSeconds / 60) 分钟内回答")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }

        if !question.resources.isEmpty {
            learningResourcesPanel(question.resources)
        }

        if !isRecitingMode {
            // Answer Input
            SurfacePanel {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("你的回答")
                            .font(.system(size: 20, weight: .semibold))
                        Spacer()
                        if speechService.isRecording {
                            Text("\(speechService.seconds)s")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundStyle(.red)
                        }
                        Button {
                            dismissKeyboard()
                            Task { await toggleRecording() }
                        } label: {
                            Label(speechService.isRecording ? "停止" : "语音", systemImage: speechService.isRecording ? "stop.fill" : "mic.fill")
                                .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(speechService.isRecording ? .red : .blue)
                    }

                    TextEditor(text: $viewModel.draftAnswer)
                        .frame(minHeight: 150)
                        .font(.system(size: 17))
                        .focused($focusedInput, equals: .answer)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if answerExpressionMetrics.characterCount > 0 {
                        ExpressionMetricsPanel(metrics: answerExpressionMetrics)
                    }

                    if let recordingError {
                        Label(recordingError, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            PrimaryActionButton(
                title: viewModel.isCoaching ? "生成中" : "AI 教练",
                icon: "graduationcap"
            ) {
                dismissKeyboard()
                Task { await viewModel.coachCurrentAnswer() }
            }
            .disabled(viewModel.isCoaching || viewModel.draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            // AI Evaluation
            if let evaluation = viewModel.activeEvaluation {
                SurfacePanel {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 16) {
                            ScoreRing(score: evaluation.overallScore)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("AI 评分")
                                    .font(.system(size: 22, weight: .semibold))
                                Text(evaluation.overallScore >= 70 ? "方向正确" : "需要加强")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !evaluation.strengths.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("亮点")
                                    .font(.system(size: 17, weight: .semibold))
                                ForEach(evaluation.strengths, id: \.self) { s in
                                    Text("• \(s)")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.green)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        if !evaluation.improvements.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("改进建议")
                                    .font(.system(size: 17, weight: .semibold))
                                ForEach(evaluation.improvements, id: \.self) { item in
                                    Text("• \(item)")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        if !evaluation.optimizedAnswer.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("优化版回答")
                                    .font(.system(size: 17, weight: .semibold))
                                Text(evaluation.optimizedAnswer)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Button {
                            dismissKeyboard()
                            Task { await viewModel.coachCurrentAnswer() }
                        } label: {
                            Label(viewModel.isCoaching ? "生成中" : "生成 AI 教练稿", systemImage: "graduationcap")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(viewModel.isCoaching)
                    }
                }
            }

            // Coaching
            if let coaching = viewModel.activeCoachingResult {
                CoachingResultCard(coaching: coaching)

                Button {
                    dismissKeyboard()
                    isRecitingMode = true
                    recitationText = ""
                } label: {
                    Label("隐藏示范，开始复述", systemImage: "mouth.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            // Follow-ups
            if !question.followUps.isEmpty {
                SurfacePanel {
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            dismissKeyboard()
                            withAnimation { showFollowUps.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .foregroundStyle(.orange)
                                Text("追问 (\(question.followUps.count))")
                                    .font(.system(size: 17, weight: .semibold))
                                Spacer()
                                Image(systemName: showFollowUps ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if showFollowUps {
                            ForEach(Array(question.followUps.enumerated()), id: \.offset) { idx, q in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("Q\(idx + 1)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 20)
                                        .background(Color.orange, in: Capsule())
                                    Text(q)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // Recitation Mode
            SurfacePanel {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "mouth.fill").foregroundStyle(.green)
                        Text("背诵练习")
                            .font(.system(size: 20, weight: .semibold))
                        Spacer()
                        Button("取消") {
                            dismissKeyboard()
                            isRecitingMode = false
                        }
                            .font(.system(size: 14))
                    }

                    HStack {
                        Spacer()
                        Button {
                            dismissKeyboard()
                            Task { await toggleRecording() }
                        } label: {
                            Label(speechService.isRecording ? "停止 \(speechService.seconds)s" : "开始录音", systemImage: speechService.isRecording ? "stop.fill" : "mic.fill")
                                .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(speechService.isRecording ? .red : .green)
                        Spacer()
                    }

                    TextEditor(text: $recitationText)
                        .frame(minHeight: 120)
                        .font(.system(size: 17))
                        .focused($focusedInput, equals: .recitation)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if recitationExpressionMetrics.characterCount > 0 {
                        ExpressionMetricsPanel(metrics: recitationExpressionMetrics)
                    }

                    if let recordingError {
                        Label(recordingError, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        dismissKeyboard()
                        Task { await viewModel.evaluateRecitation(recitation: recitationText) }
                    } label: {
                        Label(viewModel.isEvaluating ? "评估中" : "提交背诵", systemImage: "paperplane")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(recitationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isEvaluating)
                }
            }

            if let result = viewModel.activeRecitationResult {
                RecitationPanel(result: result)
            }
        }
    }

    private func learningResourcesPanel(_ resources: [LearningResource]) -> some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "play.rectangle")
                        .foregroundStyle(.blue)
                    Text("学习资源")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text("\(resources.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }

                ForEach(Array(resources.prefix(4).enumerated()), id: \.offset) { _, resource in
                    if let url = URL(string: resource.url) {
                        Link(destination: url) {
                            HStack(spacing: 10) {
                                Image(systemName: resourceIcon(for: resource))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.blue)
                                    .frame(width: 28, height: 28)
                                    .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                Text(resource.label)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    private func resourceIcon(for resource: LearningResource) -> String {
        let label = resource.label.lowercased()
        if label.contains("视频") || label.contains("b站") || label.contains("youtube") {
            return "play.rectangle"
        }
        if label.contains("文档") || label.contains("docs") || label.contains("api") {
            return "doc.text"
        }
        return "link"
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        let isLastQuestion = viewModel.currentQuestionIndex + 1 >= viewModel.currentQuestions.count

        return HStack(spacing: 12) {
            if viewModel.currentQuestionIndex > 0 {
                Button {
                    dismissKeyboard()
                    viewModel.goToPreviousQuestion(); resetState()
                } label: {
                    Label("上一题", systemImage: "arrow.left")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)
            }

            Button {
                dismissKeyboard()
                if viewModel.isMockSessionActive && isLastQuestion {
                    speechService.stopRecording()
                    _ = viewModel.completeMockSession()
                } else {
                    viewModel.goToNextQuestion()
                }
                resetState()
            } label: {
                Label(viewModel.isMockSessionActive && isLastQuestion ? "生成报告" : "下一题", systemImage: viewModel.isMockSessionActive && isLastQuestion ? "doc.text.magnifyingglass" : "arrow.right")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.bordered)
        }
    }

    private var emptyState: some View {
        SurfacePanel {
            VStack(spacing: 16) {
                Image(systemName: "person.wave.2")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("还没有练习题")
                    .font(.system(size: 22, weight: .semibold))
                Text("从题库选择题目或使用推荐题开始。")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "使用推荐题开始", icon: "play.fill") {
                    dismissKeyboard()
                    viewModel.startPractice()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private enum PracticeScrollTarget {
    static let top = "practice-top"
}

private enum PracticeInputFocus: Hashable {
    case answer
    case recitation
}
