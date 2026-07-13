import Foundation

@MainActor
final class QuestionBank: ObservableObject {
    @Published private(set) var questions: [InterviewQuestion]
    private var bundledQuestions: [InterviewQuestion]
    private var generatedQuestions: [InterviewQuestion]
    private var hasLoadedBundledQuestions = false
    private static let generatedQuestionsKey = "InterviewCoach.generatedQuestions.v1"

    init(
        questions: [InterviewQuestion] = QuestionBankLoader.fallbackQuestions,
        loadsPersistedGeneratedQuestions: Bool = false
    ) {
        bundledQuestions = questions
        generatedQuestions = loadsPersistedGeneratedQuestions ? Self.loadGeneratedQuestions() : []
        self.questions = Self.merged(bundled: questions, generated: generatedQuestions)
    }

    func loadBundledQuestionsIfNeeded() async {
        guard !hasLoadedBundledQuestions else { return }
        hasLoadedBundledQuestions = true

        guard let bundledQuestions = await QuestionBankLoader.loadBundledQuestions(),
              !bundledQuestions.isEmpty else {
            return
        }
        self.bundledQuestions = bundledQuestions
        rebuildQuestions()
    }

    var aiGeneratedCount: Int { generatedQuestions.count }

    func upsertGeneratedQuestions(_ newQuestions: [InterviewQuestion]) {
        guard !newQuestions.isEmpty else { return }
        var promptIndex: [String: InterviewQuestion] = [:]
        for question in generatedQuestions {
            promptIndex[Self.normalizedPrompt(question.prompt)] = question
        }
        for question in newQuestions {
            promptIndex[Self.normalizedPrompt(question.prompt)] = question
        }
        generatedQuestions = promptIndex.values.sorted { $0.id < $1.id }
        persistGeneratedQuestions()
        rebuildQuestions()
    }

    func clearGeneratedQuestions() {
        generatedQuestions = []
        UserDefaults.standard.removeObject(forKey: Self.generatedQuestionsKey)
        rebuildQuestions()
    }

    func questions(for role: InterviewRole) -> [InterviewQuestion] {
        questions.filter { $0.role == role || $0.role == .general }
    }

    func questions(for mode: PracticeMode) -> [InterviewQuestion] {
        switch mode {
        case .jobTarget, .wrong, .drill, .review, .flashcard:
            return []
        default:
            return questions.filter { $0.mode == mode.rawValue }
        }
    }

    func search(keyword: String, category: String = "全部", difficulty: String = "全部") -> [InterviewQuestion] {
        questions.filter { q in
            let matchKeyword = keyword.isEmpty || q.prompt.localizedCaseInsensitiveContains(keyword) || q.keywords.contains { $0.localizedCaseInsensitiveContains(keyword) }
            let matchCategory = category == "全部" || q.category.rawValue == category
            let matchDifficulty = difficulty == "全部" || q.difficulty.rawValue == difficulty
            return matchKeyword && matchCategory && matchDifficulty
        }
    }

    var categories: [String] {
        ["全部"] + Array(Set(questions.map { $0.category.rawValue })).sorted()
    }

    var difficulties: [String] {
        ["全部"] + QuestionDifficulty.allCases.map(\.rawValue)
    }

    private func rebuildQuestions() {
        questions = Self.merged(bundled: bundledQuestions, generated: generatedQuestions)
    }

    private func persistGeneratedQuestions() {
        guard let data = try? JSONEncoder().encode(generatedQuestions) else { return }
        UserDefaults.standard.set(data, forKey: Self.generatedQuestionsKey)
    }

    private static func loadGeneratedQuestions() -> [InterviewQuestion] {
        guard let data = UserDefaults.standard.data(forKey: generatedQuestionsKey),
              let decoded = try? JSONDecoder().decode([InterviewQuestion].self, from: data)
        else { return [] }
        return decoded
    }

    private static func merged(bundled: [InterviewQuestion], generated: [InterviewQuestion]) -> [InterviewQuestion] {
        var seenIDs = Set<String>()
        return (bundled + generated).filter { seenIDs.insert($0.id).inserted }
    }

    private static func normalizedPrompt(_ prompt: String) -> String {
        prompt.lowercased().filter { !$0.isWhitespace }
    }

}

enum QuestionBankLoader {
    static let fallbackQuestions: [InterviewQuestion] = [
        InterviewQuestion(
            id: "ios-swiftui-state",
            role: .iosDeveloper,
            category: .technical,
            difficulty: .mid,
            prompt: "请解释 SwiftUI 中 @State、@Binding、@StateObject 和 @ObservedObject 的区别，并举一个项目中的使用例子。",
            expectedKeywords: ["SwiftUI", "@State", "@Binding", "状态管理"],
            sampleAnswer: "可以从状态归属、生命周期、父子视图传递和引用类型对象四个角度回答。",
            followUps: ["如果 View 被重新创建，@StateObject 和 @ObservedObject 的表现有什么不同？"],
            timeLimitSeconds: 240
        ),
        InterviewQuestion(
            id: "ios-performance",
            role: .iosDeveloper,
            category: .project,
            difficulty: .mid,
            prompt: "讲一个你做过的 iOS 性能优化项目，你如何定位问题、验证效果，并防止回归？",
            expectedKeywords: ["性能优化", "Instruments", "启动时间", "卡顿", "崩溃率"],
            sampleAnswer: "用 STAR 结构说明场景、指标、工具、优化动作和量化结果。",
            followUps: ["如果优化后用户仍反馈卡顿，你下一步会看什么指标？"],
            timeLimitSeconds: 300
        ),
        InterviewQuestion(
            id: "general-self-intro",
            role: .general,
            category: .hr,
            difficulty: .junior,
            prompt: "请做一个 1 分钟自我介绍，突出你和目标岗位最相关的经历。",
            expectedKeywords: ["自我介绍", "岗位匹配", "项目经历", "优势"],
            sampleAnswer: "建议用当前身份、核心能力、代表项目、求职动机四段式。",
            followUps: ["为什么这段经历能证明你适合这个岗位？"],
            timeLimitSeconds: 90
        )
    ]

    static func loadBundledQuestions() async -> [InterviewQuestion]? {
        await Task.detached(priority: .userInitiated) {
            loadFromJSON()
        }.value
    }

    private static func loadFromJSON() -> [InterviewQuestion]? {
        if let url = Bundle.main.url(forResource: "questions", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let questions = try? JSONDecoder().decode([InterviewQuestion].self, from: data),
           !questions.isEmpty {
            return questions
        }
        return nil
    }
}

typealias BuiltInQuestionBank = QuestionBank
