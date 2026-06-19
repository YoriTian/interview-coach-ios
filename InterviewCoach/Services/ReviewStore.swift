import Foundation

@MainActor
final class ReviewStore: ObservableObject {
    @Published private(set) var attempts: [AttemptRecord] = []
    @Published private(set) var mastery: [String: ReviewState] = [:]
    @Published private(set) var sessionReports: [MockSessionReport] = []

    private let attemptsKey = "interviewCoach.attempts"
    private let masteryKey = "interviewCoach.mastery"
    private let sessionsKey = "interviewCoach.sessionReports"

    init() {
        attempts = Self.load([AttemptRecord].self, key: attemptsKey) ?? []
        mastery = Self.load([String: ReviewState].self, key: masteryKey) ?? [:]
        sessionReports = Self.load([MockSessionReport].self, key: sessionsKey) ?? []
    }

    var averageScore: Int {
        guard !attempts.isEmpty else { return 0 }
        return attempts.map(\.score).reduce(0, +) / attempts.count
    }

    var masteredCount: Int {
        mastery.values.filter { $0.status == .mastered }.count
    }

    var learningCount: Int {
        mastery.values.filter { $0.status != .mastered }.count
    }

    var streakDays: Int {
        let days = Set(attempts.map { Calendar.current.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }
        var cursor = Calendar.current.startOfDay(for: Date())
        var streak = 0
        for offset in 0..<365 {
            if !days.contains(cursor) {
                if streak == 0, offset == 0 {
                    cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor
                    continue
                }
                break
            }
            streak += 1
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    func record(question: InterviewQuestion, result: ScoreResult) {
        attempts.append(AttemptRecord(
            questionId: question.id,
            prompt: question.prompt,
            category: question.category.rawValue,
            mode: question.mode,
            score: result.score,
            dimensions: result.dimensions,
            missingKeywords: result.missingKeywords,
            date: Date()
        ))
        updateMastery(question: question, score: result.score)
        persist()
    }

    func recordSession(_ report: MockSessionReport) {
        sessionReports.insert(report, at: 0)
        if sessionReports.count > 30 {
            sessionReports = Array(sessionReports.prefix(30))
        }
        persist()
    }

    func markMastered(_ question: InterviewQuestion) {
        let previous = mastery[question.id]
        let interval = min(30, max(14, (previous?.intervalDays ?? 0) * 2))
        mastery[question.id] = ReviewState(
            status: .mastered,
            intervalDays: interval,
            lastScore: max(90, previous?.lastScore ?? 0),
            attempts: previous?.attempts ?? 0,
            lastReviewedAt: Date(),
            nextReviewAt: Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
        )
        persist()
    }

    func statusText(for question: InterviewQuestion) -> String {
        guard let state = mastery[question.id] else { return "未练" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        let title = state.status == .mastered ? "已掌握" : "学习中"
        return "\(title) · 下次 \(formatter.string(from: state.nextReviewAt))"
    }

    func dueQuestions(from questions: [InterviewQuestion]) -> [InterviewQuestion] {
        let now = Date()
        return questions
            .filter { mastery[$0.id]?.nextReviewAt ?? .distantFuture <= now }
            .sorted {
                let left = mastery[$0.id]?.nextReviewAt ?? .distantFuture
                let right = mastery[$1.id]?.nextReviewAt ?? .distantFuture
                return left < right
            }
    }

    func wrongQuestions(from questions: [InterviewQuestion]) -> [InterviewQuestion] {
        let latest = latestAttempts()
        return questions
            .filter { (latest[$0.id]?.score ?? 100) < 75 }
            .sorted { (latest[$0.id]?.score ?? 0) < (latest[$1.id]?.score ?? 0) }
    }

    func dailyDrill(from questions: [InterviewQuestion]) -> [InterviewQuestion] {
        let latest = latestAttempts()
        let wrong = wrongQuestions(from: questions)
        let due = dueQuestions(from: questions)
        let fresh = questions.filter { latest[$0.id] == nil && $0.mode == "tech" }
        return unique(due + wrong + fresh + questions).prefix(10).map { $0 }
    }

    func weaknessSummary(limit: Int = 5) -> [(text: String, count: Int)] {
        let cleaned = attempts
            .flatMap(\.missingKeywords)
            .compactMap(normalizedWeakness)

        let counts = cleaned.reduce(into: [String: Int]()) { output, item in
            output[item, default: 0] += 1
        }

        return counts
            .map { (text: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count { return $0.text < $1.text }
                return $0.count > $1.count
            }
            .prefix(limit)
            .map { $0 }
    }

    func reset() {
        attempts = []
        mastery = [:]
        sessionReports = []
        persist()
    }

    private func updateMastery(question: InterviewQuestion, score: Int) {
        let previous = mastery[question.id]
        let previousInterval = previous?.intervalDays ?? 0
        let status: ReviewStatus
        let interval: Int
        if score >= 90 {
            status = .mastered
            interval = min(30, max(7, previousInterval == 0 ? 7 : previousInterval * 2))
        } else if score >= 75 {
            status = previous?.status == .mastered ? .mastered : .learning
            interval = min(14, max(2, Int(ceil(Double(previousInterval) * 1.5))))
        } else {
            status = .learning
            interval = 0
        }
        mastery[question.id] = ReviewState(
            status: status,
            intervalDays: interval,
            lastScore: score,
            attempts: (previous?.attempts ?? 0) + 1,
            lastReviewedAt: Date(),
            nextReviewAt: Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
        )
    }

    private func latestAttempts() -> [String: AttemptRecord] {
        attempts.reduce(into: [:]) { output, attempt in
            if let old = output[attempt.questionId], old.date > attempt.date { return }
            output[attempt.questionId] = attempt
        }
    }

    private func unique(_ questions: [InterviewQuestion]) -> [InterviewQuestion] {
        var seen: Set<String> = []
        return questions.filter { seen.insert($0.id).inserted }
    }

    private func normalizedWeakness(_ raw: String) -> String? {
        let text = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard text.count >= 3 else { return nil }
        let ignored = ["...", "无", "暂无", "没有", "AI 返回内容不完整"]
        guard !ignored.contains(text) else { return nil }
        return text.count > 48 ? "\(text.prefix(48))..." : text
    }

    private func persist() {
        Self.save(attempts, key: attemptsKey)
        Self.save(mastery, key: masteryKey)
        Self.save(sessionReports, key: sessionsKey)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
