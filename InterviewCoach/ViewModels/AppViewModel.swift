import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - Published State
    @Published var resumeProfile: ResumeProfile?
    @Published var jobDescriptionText = ""
    @Published var jobTargetProfile: JobDescriptionProfile?
    @Published var recommendedQuestions: [InterviewQuestion]
    @Published var currentQuestions: [InterviewQuestion]
    @Published var currentQuestionIndex = 0
    @Published var draftAnswer = ""
    @Published var activeEvaluation: AnswerEvaluation?
    @Published var evaluations: [AnswerEvaluation] = []
    @Published var importError: String?
    @Published var isImportingResume = false
    @Published var isEvaluating = false
    @Published var isCoaching = false
    @Published var activeAIProviderName: String
    @Published var selectedPracticeMode: PracticeMode = .resume {
        didSet { refreshVisibleQuestions() }
    }
    @Published var activeCoachingResult: CoachingResult?
    @Published var activeRecitationResult: RecitationResult?
    @Published var searchText = "" {
        didSet { refreshVisibleQuestions() }
    }
    @Published var selectedCategory = "全部" {
        didSet { refreshVisibleQuestions() }
    }
    @Published var selectedDifficulty = "全部" {
        didSet { refreshVisibleQuestions() }
    }
    @Published var isMockSessionActive = false
    @Published var mockSessionStartedAt: Date?
    @Published var mockSessionAnswers: [String: String] = [:]
    @Published var mockSessionScores: [String: Int] = [:]
    @Published var mockSessionMisses: [String: [String]] = [:]
    @Published var lastMockSessionReport: MockSessionReport?
    @Published var selectedReviewSection = 0
    @Published private(set) var todayFocusRecommendation = "开始今日训练吧"
    @Published private(set) var jobTargetQuestions: [InterviewQuestion] = []
    @Published private(set) var techStackQuestions: [InterviewQuestion] = []
    @Published private(set) var visibleQuestions: [InterviewQuestion] = []
    @Published private(set) var dueReviewQuestions: [InterviewQuestion] = []
    @Published private(set) var wrongReviewQuestions: [InterviewQuestion] = []
    @Published private(set) var dueReviewCount = 0
    @Published private(set) var wrongQuestionCount = 0

    // MARK: - Sub-objects
    let questionBank = QuestionBank()
    let reviewStore = ReviewStore()
    private let resumeAnalyzer = ResumeAnalyzer()
    private let jobDescriptionAnalyzer = JobDescriptionAnalyzer()
    private let questionMatcher = QuestionMatcher()
    private let textExtractor = ResumeTextExtractor()
    private var aiService: any InterviewAIProviding
    private var cachedDueQuestions: [InterviewQuestion] = []
    private var cachedWrongQuestions: [InterviewQuestion] = []
    private var cachedDailyDrillQuestions: [InterviewQuestion] = []
    private var practiceModeCounts: [PracticeMode: Int] = [:]
    private static let savedJobDescriptionKey = "InterviewCoach.savedJobDescription"

    // MARK: - Init

    init(aiService: any InterviewAIProviding = AIServiceFactory.makeDefaultService()) {
        self.aiService = aiService
        activeAIProviderName = AIServiceFactory.currentProviderName()
        let defaults = questionBank.questions.prefix(8).map { $0 }
        recommendedQuestions = defaults
        currentQuestions = defaults

        let savedJobDescription = UserDefaults.standard.string(forKey: Self.savedJobDescriptionKey) ?? ""
        let cleanedJobDescription = savedJobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedJobDescription.isEmpty {
            jobDescriptionText = cleanedJobDescription
            jobTargetProfile = jobDescriptionAnalyzer.analyze(text: cleanedJobDescription, resumeProfile: resumeProfile)
        }
        refreshDerivedQuestionState(updateRecommendations: true)
        currentQuestions = recommendedQuestions
    }

    func loadQuestionBankIfNeeded() async {
        let previousRecommendationIDs = recommendedQuestions.map(\.id)
        let previousCurrentIDs = currentQuestions.map(\.id)
        let shouldRefreshCurrent = previousCurrentIDs == previousRecommendationIDs
            && draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && activeEvaluation == nil
            && activeCoachingResult == nil
            && activeRecitationResult == nil

        await questionBank.loadBundledQuestionsIfNeeded()

        refreshDerivedQuestionState(updateRecommendations: true)
        if shouldRefreshCurrent {
            currentQuestions = recommendedQuestions
            currentQuestionIndex = 0
        }
    }

    // MARK: - Computed Properties

    var currentQuestion: InterviewQuestion? {
        guard currentQuestions.indices.contains(currentQuestionIndex) else { return nil }
        return currentQuestions[currentQuestionIndex]
    }

    var progressText: String {
        guard !currentQuestions.isEmpty else { return "0/0" }
        return "\(currentQuestionIndex + 1)/\(currentQuestions.count)"
    }

    var jobGapKeywords: [String] {
        jobTargetProfile?.gapKeywords ?? []
    }

    var mockSessionAnsweredCount: Int {
        currentQuestions.filter { question in
            !(mockSessionAnswers[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }.count
    }

    var mockSessionScoredCount: Int {
        currentQuestions.filter { mockSessionScores[$0.id] != nil }.count
    }

    func mockSessionElapsedSeconds(now: Date = Date()) -> Int {
        guard let mockSessionStartedAt else { return 0 }
        return max(0, Int(now.timeIntervalSince(mockSessionStartedAt)))
    }

    func modeCount(for mode: PracticeMode) -> Int {
        practiceModeCounts[mode] ?? 0
    }

    // MARK: - Resume

    func importResume(from url: URL) async {
        isImportingResume = true
        importError = nil
        do {
            let text = try textExtractor.extractText(from: url)
            let localProfile = resumeAnalyzer.analyze(text: text)
            applyResumeProfile(localProfile)
            if AIServiceFactory.currentDeepSeekKey() != nil {
                do {
                    let aiEntities = try await aiService.extractTechStackEntities(from: text)
                    if !aiEntities.isEmpty {
                        applyResumeProfile(localProfile.mergingTechStack(aiEntities))
                    }
                } catch {
                    importError = "已完成本地解析；DeepSeek 技术栈抽取暂不可用：\(error.localizedDescription)"
                }
            }
        } catch {
            importError = error.localizedDescription
        }
        isImportingResume = false
    }

    func loadSampleResume() {
        applyResumeText("""
        匿名候选人
        高级运维工程师，5年企业 IT 运维与交付经验。
        熟悉 Jenkins、CI/CD、Docker、Kubernetes、K8S、Harbor、Helm、Nginx、Linux、Shell、Prometheus、Grafana、Ceph、Redis、MySQL、达梦 DM8。
        负责私有云、容器平台、数据库、离线镜像仓库、监控告警和系统上线验收。
        """)
    }

    // MARK: - Job Description

    func applyJobDescriptionText() {
        let cleaned = jobDescriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            importError = "先粘贴目标岗位 JD，再生成岗位专项训练。"
            return
        }

        jobDescriptionText = cleaned
        jobTargetProfile = jobDescriptionAnalyzer.analyze(text: cleaned, resumeProfile: resumeProfile)
        UserDefaults.standard.set(cleaned, forKey: Self.savedJobDescriptionKey)
        refreshRecommendations()
        importError = nil
    }

    func loadSampleJobDescription() {
        jobDescriptionText = """
        iOS 开发工程师
        岗位职责：
        负责核心业务 App 的 SwiftUI/UIKit 页面开发、性能优化和线上问题排查。
        参与需求评审、技术方案设计、埋点数据分析、灰度发布和 App Store 上架。
        任职要求：
        3 年以上 iOS 开发经验，熟悉 Swift、SwiftUI、UIKit、Combine，了解 Instruments、崩溃分析和启动优化。
        具备良好的项目复盘、跨团队沟通和风险控制能力。
        """
        applyJobDescriptionText()
    }

    func clearJobDescription() {
        jobDescriptionText = ""
        jobTargetProfile = nil
        UserDefaults.standard.removeObject(forKey: Self.savedJobDescriptionKey)
        refreshRecommendations()
    }

    // MARK: - AI Service

    func refreshAIService() {
        aiService = AIServiceFactory.makeDefaultService()
        activeAIProviderName = AIServiceFactory.currentProviderName()
    }

    func resetReviewData() {
        reviewStore.reset()
        refreshReviewProgressState()
    }

    // MARK: - Practice Flow

    func startPractice(with questions: [InterviewQuestion]? = nil) {
        clearMockSessionState()
        currentQuestions = questions ?? recommendedQuestions
        currentQuestionIndex = 0
        draftAnswer = ""
        activeEvaluation = nil
        activeCoachingResult = nil
        activeRecitationResult = nil
    }

    func startMockInterview(with questions: [InterviewQuestion]? = nil, fillToSix: Bool = true) {
        var seenQuestionIDs = Set<String>()
        let primaryQuestions = questions ?? recommendedQuestions
        let source = fillToSix
            ? primaryQuestions
                + recommendedQuestions
                + techStackQuestions
                + jobTargetQuestions
                + cachedDailyDrillQuestions
                + questionBank.questions
            : primaryQuestions
        let sessionQuestions = Array(source.filter { question in
            seenQuestionIDs.insert(question.id).inserted
        }.prefix(fillToSix ? 6 : source.count))
        guard !sessionQuestions.isEmpty else {
            importError = "当前没有可用题目，先上传简历、粘贴 JD 或进入题库选择题目。"
            return
        }

        currentQuestions = sessionQuestions
        currentQuestionIndex = 0
        draftAnswer = ""
        activeEvaluation = nil
        activeCoachingResult = nil
        activeRecitationResult = nil
        isMockSessionActive = true
        mockSessionStartedAt = Date()
        mockSessionAnswers = [:]
        mockSessionScores = [:]
        mockSessionMisses = [:]
        lastMockSessionReport = nil
        importError = nil
    }

    func startReportFollowUp(_ report: MockSessionReport) {
        let summaries = report.questionSummaries
        let targetSummaries = summaries.contains { $0.score == nil }
            ? summaries.filter { $0.score == nil }
            : summaries
        let questionByID = Dictionary(uniqueKeysWithValues: questionBank.questions.map { ($0.id, $0) })
        let questions = targetSummaries.compactMap { questionByID[$0.id] }
        guard !questions.isEmpty else {
            importError = "报告里的题目已不在当前题库中，建议重新开始一场模拟面试。"
            return
        }

        startMockInterview(with: questions, fillToSix: false)
    }

    func syncCurrentMockAnswer() {
        persistCurrentMockAnswer()
    }

    func startPracticeForMode(_ mode: PracticeMode) {
        selectedPracticeMode = mode
        let questions = visibleQuestions
        guard !questions.isEmpty else { return }
        startPractice(with: questions)
    }

    func startJobTargetPractice() {
        let questions = jobTargetQuestions
        guard !questions.isEmpty else {
            importError = "先粘贴目标岗位 JD，系统会按岗位差距推荐题目。"
            return
        }
        selectedPracticeMode = .jobTarget
        startPractice(with: questions)
    }

    func startTechStackPractice() {
        let questions = techStackQuestions
        guard !questions.isEmpty else {
            importError = "先上传简历，系统会提取 Jenkins、Docker、K8S、Harbor 等技术栈实体后再出题。"
            return
        }
        selectedPracticeMode = .tech
        startPractice(with: questions)
    }

    func goToNextQuestion() {
        persistCurrentMockAnswer()
        guard currentQuestionIndex + 1 < currentQuestions.count else { return }
        currentQuestionIndex += 1
        draftAnswer = isMockSessionActive ? mockSessionAnswers[currentQuestion?.id ?? ""] ?? "" : ""
        activeEvaluation = nil
        activeCoachingResult = nil
        activeRecitationResult = nil
    }

    func goToPreviousQuestion() {
        persistCurrentMockAnswer()
        guard currentQuestionIndex > 0 else { return }
        currentQuestionIndex -= 1
        draftAnswer = isMockSessionActive ? mockSessionAnswers[currentQuestion?.id ?? ""] ?? "" : ""
        activeEvaluation = nil
        activeCoachingResult = nil
        activeRecitationResult = nil
    }

    func recordFlashcardResult(score: Int) {
        guard let question = currentQuestion else { return }
        let dimensions = ScoreDimensions(technical: score, structure: score, projectEvidence: score, risk: score, quantification: score, management: score)
        let result = ScoreResult(
            score: score,
            summary: score >= 80 ? "已掌握" : score >= 50 ? "需要巩固" : "需要重点学习",
            dimensions: dimensions,
            matchedKeywords: [],
            missingKeywords: question.keywords,
            misses: [],
            strengths: [],
            followUps: []
        )
        reviewStore.record(question: question, result: result)
        refreshReviewProgressState()
    }

    func evaluateCurrentAnswer() async {
        guard let question = currentQuestion else { return }
        let answer = draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else {
            importError = "先输入或录制一段回答，再让 AI 评分。"
            return
        }

        isEvaluating = true
        importError = nil
        do {
            let scoreResult = try await aiService.scoreAnswer(question: question, answer: answer)
            let evaluation = answerEvaluation(from: scoreResult, question: question, answer: answer)
            activeEvaluation = evaluation
            evaluations.insert(evaluation, at: 0)
            reviewStore.record(question: question, result: scoreResult)
            refreshReviewProgressState()
            recordMockSessionResult(question: question, answer: answer, result: scoreResult)
        } catch {
            importError = "评分失败：\(error.localizedDescription)"
        }
        isEvaluating = false
    }

    // MARK: - Coaching

    func coachCurrentAnswer() async {
        guard let question = currentQuestion else { return }
        let answer = draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else {
            importError = "先输入或录制一段回答，再获取教练指导。"
            return
        }

        isCoaching = true
        importError = nil
        activeEvaluation = nil
        activeRecitationResult = nil
        do {
            let coaching = try await aiService.coachAnswer(question: question, answer: answer)
            activeCoachingResult = coaching
            // Also record score
            reviewStore.record(question: question, result: coaching.scoreResult)
            refreshReviewProgressState()
            recordMockSessionResult(question: question, answer: answer, result: coaching.scoreResult)
        } catch {
            importError = "教练失败：\(error.localizedDescription)"
        }
        isCoaching = false
    }

    // MARK: - Recitation

    func evaluateRecitation(recitation: String) async {
        guard let question = currentQuestion,
              let coaching = activeCoachingResult else { return }
        isEvaluating = true
        importError = nil
        do {
            let result = try await aiService.evaluateRecitation(
                question: question,
                targetAnswer: coaching.targetAnswer,
                originalAnswer: draftAnswer,
                recitation: recitation
            )
            activeRecitationResult = result
            let scoreResult = scoreResult(from: result)
            reviewStore.record(question: question, result: scoreResult)
            refreshReviewProgressState()
            recordMockSessionResult(question: question, answer: recitation, result: scoreResult)
        } catch {
            importError = "背诵评估失败：\(error.localizedDescription)"
        }
        isEvaluating = false
    }

    @discardableResult
    func completeMockSession() -> MockSessionReport? {
        guard isMockSessionActive, let startedAt = mockSessionStartedAt else { return nil }
        persistCurrentMockAnswer()

        let endedAt = Date()
        let summaries = currentQuestions.map { question in
            let answer = mockSessionAnswers[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return MockSessionQuestionSummary(
                id: question.id,
                prompt: question.prompt,
                answerPreview: preview(answer),
                score: mockSessionScores[question.id],
                misses: mockSessionMisses[question.id] ?? []
            )
        }

        let scores = summaries.compactMap(\.score)
        let weakPoints = topWeakPoints(from: summaries)
        let report = MockSessionReport(
            title: "模拟面试报告",
            modeTitle: selectedPracticeMode.title,
            questionCount: currentQuestions.count,
            answeredCount: summaries.filter { !$0.answerPreview.isEmpty }.count,
            scoredCount: scores.count,
            averageScore: scores.isEmpty ? nil : scores.reduce(0, +) / scores.count,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: max(0, Int(endedAt.timeIntervalSince(startedAt))),
            questionSummaries: summaries,
            weakPoints: weakPoints,
            nextActions: nextActions(from: weakPoints, scoredCount: scores.count)
        )

        reviewStore.recordSession(report)
        refreshReviewProgressState()
        lastMockSessionReport = report
        isMockSessionActive = false
        mockSessionStartedAt = nil
        return report
    }

    // MARK: - Private

    private func applyResumeText(_ text: String) {
        let profile = resumeAnalyzer.analyze(text: text)
        applyResumeProfile(profile)
    }

    private func applyResumeProfile(_ profile: ResumeProfile) {
        resumeProfile = profile
        let cleanedJobDescription = jobDescriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedJobDescription.isEmpty {
            jobTargetProfile = jobDescriptionAnalyzer.analyze(text: cleanedJobDescription, resumeProfile: profile)
        }
        refreshRecommendations()
        startPractice(with: recommendedQuestions)
    }

    private func refreshRecommendations() {
        refreshDerivedQuestionState(updateRecommendations: true)
    }

    private func refreshDerivedQuestionState(updateRecommendations: Bool = true) {
        refreshTargetQuestionCaches()
        refreshReviewQuestionCaches()
        refreshModeCounts()
        refreshTodayFocus()
        if updateRecommendations {
            recommendedQuestions = makeRecommendations(limit: 8)
        }
        refreshVisibleQuestions()
    }

    private func refreshReviewProgressState() {
        refreshReviewQuestionCaches()
        refreshModeCounts()
        refreshTodayFocus()
        refreshVisibleQuestions()
    }

    private func refreshTargetQuestionCaches() {
        if jobTargetProfile != nil || !jobDescriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            jobTargetQuestions = questionMatcher.match(
                profile: resumeProfile,
                jobDescription: jobTargetProfile,
                questions: questionBank.questions,
                limit: 12
            )
        } else {
            jobTargetQuestions = []
        }

        if let techStack = resumeProfile?.techStack, !techStack.isEmpty {
            techStackQuestions = questionMatcher.match(
                techStack: techStack,
                questions: questionBank.questions,
                limit: 12
            )
        } else {
            techStackQuestions = []
        }
    }

    private func refreshReviewQuestionCaches() {
        cachedDueQuestions = reviewStore.dueQuestions(from: questionBank.questions)
        cachedWrongQuestions = reviewStore.wrongQuestions(from: questionBank.questions)
        cachedDailyDrillQuestions = reviewStore.dailyDrill(from: questionBank.questions)
        dueReviewQuestions = cachedDueQuestions
        wrongReviewQuestions = cachedWrongQuestions
        dueReviewCount = cachedDueQuestions.count
        wrongQuestionCount = cachedWrongQuestions.count
    }

    private func refreshModeCounts() {
        practiceModeCounts = Dictionary(uniqueKeysWithValues: PracticeMode.allCases.map { mode in
            (mode, baseQuestions(for: mode).count)
        })
    }

    private func refreshTodayFocus() {
        if dueReviewCount > 0 {
            todayFocusRecommendation = "有 \(dueReviewCount) 道待复习题"
        } else if wrongQuestionCount > 0 {
            todayFocusRecommendation = "有 \(wrongQuestionCount) 道错题需要巩固"
        } else if let jobTargetProfile, !jobTargetProfile.gapKeywords.isEmpty {
            todayFocusRecommendation = "目标岗位还差 \(jobTargetProfile.gapKeywords.prefix(3).joined(separator: "、"))"
        } else if let techStack = resumeProfile?.techStack, !techStack.isEmpty {
            todayFocusRecommendation = "优先练技术栈：\(techStack.prefix(4).map(\.name).joined(separator: "、"))"
        } else {
            todayFocusRecommendation = "开始今日训练吧"
        }
    }

    private func refreshVisibleQuestions() {
        let base = baseQuestions(for: selectedPracticeMode)
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else {
            visibleQuestions = []
            return
        }
        guard !keyword.isEmpty || selectedCategory != "全部" || selectedDifficulty != "全部" else {
            visibleQuestions = base
            return
        }

        visibleQuestions = base.filter { question in
            let matchKeyword = keyword.isEmpty
                || question.prompt.localizedCaseInsensitiveContains(keyword)
                || question.keywords.contains { $0.localizedCaseInsensitiveContains(keyword) }
            let matchCategory = selectedCategory == "全部" || question.category.rawValue == selectedCategory
            let matchDifficulty = selectedDifficulty == "全部" || question.difficulty.rawValue == selectedDifficulty
            return matchKeyword && matchCategory && matchDifficulty
        }
    }

    private func baseQuestions(for mode: PracticeMode) -> [InterviewQuestion] {
        switch mode {
        case .wrong:
            return cachedWrongQuestions
        case .jobTarget:
            return jobTargetQuestions
        case .tech:
            return techStackQuestions.isEmpty ? questionBank.questions(for: .tech) : techStackQuestions
        case .drill:
            return cachedDailyDrillQuestions
        case .review:
            return cachedDueQuestions
        case .flashcard:
            return questionBank.questions
        default:
            return questionBank.questions(for: mode)
        }
    }

    private func makeRecommendations(limit: Int) -> [InterviewQuestion] {
        if resumeProfile != nil || jobTargetProfile != nil {
            return questionMatcher.match(
                profile: resumeProfile,
                jobDescription: jobTargetProfile,
                questions: questionBank.questions,
                limit: limit
            )
        }

        return questionBank.questions.prefix(limit).map { $0 }
    }

    private func clearMockSessionState() {
        isMockSessionActive = false
        mockSessionStartedAt = nil
        mockSessionAnswers = [:]
        mockSessionScores = [:]
        mockSessionMisses = [:]
    }

    private func persistCurrentMockAnswer() {
        guard isMockSessionActive, let question = currentQuestion else { return }
        let answer = draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        if answer.isEmpty {
            mockSessionAnswers.removeValue(forKey: question.id)
        } else {
            mockSessionAnswers[question.id] = answer
        }
    }

    private func recordMockSessionResult(question: InterviewQuestion, answer: String, result: ScoreResult) {
        guard isMockSessionActive else { return }
        let cleanedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedAnswer.isEmpty {
            mockSessionAnswers[question.id] = cleanedAnswer
        }
        mockSessionScores[question.id] = result.score
        mockSessionMisses[question.id] = Array((result.misses + result.missingKeywords).prefix(6))
    }

    private func preview(_ answer: String) -> String {
        guard answer.count > 90 else { return answer }
        return "\(answer.prefix(90))..."
    }

    private func topWeakPoints(from summaries: [MockSessionQuestionSummary]) -> [String] {
        let counts = summaries
            .flatMap(\.misses)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String: Int]()) { output, item in
                output[item, default: 0] += 1
            }

        return counts
            .map { (text: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count { return $0.text < $1.text }
                return $0.count > $1.count
            }
            .prefix(5)
            .map(\.text)
    }

    private func nextActions(from weakPoints: [String], scoredCount: Int) -> [String] {
        if scoredCount == 0 {
            return [
                "至少选择 2 道题使用 AI 教练，生成可复述话术",
                "回到本场报告，把未评分题逐题补齐回答",
                "优先练 JD 专项或错题本，形成下一轮模拟面试"
            ]
        }

        if weakPoints.isEmpty {
            return [
                "把本场高分回答复述一遍，保持结构稳定",
                "继续做一轮更高难度追问，检查临场表达",
                "把目标岗位 JD 中的高频技能各补 1 道专项题"
            ]
        }

        return weakPoints.prefix(3).map { point in
            "围绕「\(point)」重练一次，并背诵 AI 教练稿"
        }
    }

    private func scoreResult(from recitation: RecitationResult) -> ScoreResult {
        let dimensions = ScoreDimensions(
            technical: recitation.coverage,
            structure: recitation.clarity,
            projectEvidence: recitation.coverage,
            risk: recitation.confidence,
            quantification: recitation.fluency,
            management: recitation.confidence
        )
        return ScoreResult(
            score: recitation.score,
            summary: recitation.summary,
            dimensions: dimensions,
            matchedKeywords: [],
            missingKeywords: recitation.improvements,
            misses: recitation.improvements,
            strengths: recitation.score >= 75 ? ["复述达到可面试水平"] : [],
            followUps: []
        )
    }

    private func answerEvaluation(from result: ScoreResult, question: InterviewQuestion, answer: String) -> AnswerEvaluation {
        let dimensions = [
            ScoreDimension(id: "technical", title: "技术准确性", score: result.dimensions.technical, note: "权重 28%"),
            ScoreDimension(id: "structure", title: "结构", score: result.dimensions.structure, note: "权重 20%"),
            ScoreDimension(id: "projectEvidence", title: "项目证据", score: result.dimensions.projectEvidence, note: "权重 20%"),
            ScoreDimension(id: "risk", title: "风险意识", score: result.dimensions.risk, note: "权重 14%"),
            ScoreDimension(id: "quantification", title: "量化", score: result.dimensions.quantification, note: "权重 10%"),
            ScoreDimension(id: "management", title: "管理视角", score: result.dimensions.management, note: "权重 8%")
        ]
        return AnswerEvaluation(
            questionPrompt: question.prompt,
            answerText: answer,
            overallScore: result.score,
            dimensions: dimensions,
            strengths: result.strengths,
            improvements: result.misses,
            optimizedAnswer: result.summary
        )
    }
}
