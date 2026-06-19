import Foundation

// MARK: - Enums

enum InterviewRole: String, CaseIterable, Identifiable, Codable {
    case productManager = "产品经理"
    case iosDeveloper = "iOS 开发"
    case frontendDeveloper = "前端开发"
    case backendDeveloper = "后端开发"
    case aiEngineer = "AI 工程师"
    case operations = "运维"
    case sales = "销售"
    case general = "通用面试"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .productManager: return "rectangle.3.group.bubble.left"
        case .iosDeveloper: return "iphone.gen3"
        case .frontendDeveloper: return "safari"
        case .backendDeveloper: return "server.rack"
        case .aiEngineer: return "sparkles"
        case .operations: return "wrench.and.screwdriver"
        case .sales: return "person.2.wave.2"
        case .general: return "briefcase"
        }
    }
}

enum InterviewCategory: String, CaseIterable, Identifiable, Codable {
    case behavioral = "行为面试"
    case technical = "专业能力"
    case project = "项目经历"
    case systemDesign = "方案设计"
    case caseStudy = "案例分析"
    case hr = "HR 通用"

    var id: String { rawValue }

    init(fromTrainerString string: String) {
        self = InterviewCategory.allCases.first { $0.rawValue == string }
            ?? .technical
    }
}

enum QuestionDifficulty: String, CaseIterable, Identifiable, Codable {
    case junior = "初级"
    case mid = "中级"
    case senior = "高级"

    var id: String { rawValue }

    init(fromTrainerString string: String) {
        switch string {
        case "中", "中级": self = .mid
        case "高", "高级": self = .senior
        case "初", "初级": self = .junior
        default: self = .mid
        }
    }
}

enum PracticeMode: String, CaseIterable, Identifiable, Hashable {
    case resume
    case jobTarget
    case tech
    case project
    case delivery
    case product
    case implementation
    case wrong
    case drill
    case review
    case flashcard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .resume: "简历追问"
        case .jobTarget: "岗位JD"
        case .tech: "技术专项"
        case .project: "项目复盘"
        case .delivery: "方案投标"
        case .product: "产品经理"
        case .implementation: "实施工程师"
        case .wrong: "错题本"
        case .drill: "今日10题"
        case .review: "复习计划"
        case .flashcard: "闪卡模式"
        }
    }

    var systemImage: String {
        switch self {
        case .resume: "person.text.rectangle"
        case .jobTarget: "scope"
        case .tech: "terminal"
        case .project: "folder"
        case .delivery: "shippingbox"
        case .product: "rectangle.and.pencil.and.ellipsis"
        case .implementation: "wrench.and.screwdriver"
        case .wrong: "exclamationmark.triangle"
        case .drill: "timer"
        case .review: "calendar.badge.clock"
        case .flashcard: "rectangle.on.rectangle.angled"
        }
    }

    /// Content modes that map to actual question bank entries
    static var contentModes: [PracticeMode] {
        [.resume, .tech, .project, .delivery, .product, .implementation]
    }

    /// Virtual modes that derive questions from review state
    static var virtualModes: [PracticeMode] {
        [.jobTarget, .wrong, .drill, .review, .flashcard]
    }
}

// MARK: - Learning Resource

struct LearningResource: Codable, Hashable {
    let label: String
    let url: String
}

// MARK: - Interview Question

struct InterviewQuestion: Identifiable, Hashable, Codable {
    let id: String
    let role: InterviewRole
    let category: InterviewCategory
    let difficulty: QuestionDifficulty
    let mode: String
    let prompt: String
    let expectedKeywords: [String]
    let keywords: [String]
    let idealPoints: [String]
    let sampleAnswer: String
    let followUps: [String]
    let timeLimitSeconds: Int
    let resources: [LearningResource]

    // Primary initializer for Coach-style (enum-based) creation
    init(
        id: String,
        role: InterviewRole = .general,
        category: InterviewCategory = .technical,
        difficulty: QuestionDifficulty = .mid,
        mode: String = "general",
        prompt: String,
        expectedKeywords: [String] = [],
        keywords: [String]? = nil,
        idealPoints: [String] = [],
        sampleAnswer: String = "",
        followUps: [String] = [],
        timeLimitSeconds: Int = 300,
        resources: [LearningResource] = []
    ) {
        self.id = id
        self.role = role
        self.category = category
        self.difficulty = difficulty
        self.mode = mode
        self.prompt = prompt
        self.expectedKeywords = expectedKeywords
        self.keywords = keywords ?? expectedKeywords
        self.idealPoints = idealPoints
        self.sampleAnswer = sampleAnswer
        self.followUps = followUps
        self.timeLimitSeconds = timeLimitSeconds
        self.resources = resources
    }

    // Custom Codable to handle Trainer JSON format (string-based enums)
    enum CodingKeys: String, CodingKey {
        case id, mode, category, difficulty, prompt
        case expectedKeywords, keywords, idealPoints
        case sampleAnswer, followUps, timeLimitSeconds
        case resources, role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        prompt = try container.decode(String.self, forKey: .prompt)
        mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? "general"

        // Decode category: try enum first, then string mapping
        if let cat = try? container.decode(InterviewCategory.self, forKey: .category) {
            category = cat
        } else {
            let catString = try container.decodeIfPresent(String.self, forKey: .category) ?? "专业能力"
            category = InterviewCategory(fromTrainerString: catString)
        }

        // Decode difficulty: try enum first, then string mapping
        if let diff = try? container.decode(QuestionDifficulty.self, forKey: .difficulty) {
            difficulty = diff
        } else {
            let diffString = try container.decodeIfPresent(String.self, forKey: .difficulty) ?? "中"
            difficulty = QuestionDifficulty(fromTrainerString: diffString)
        }

        // Decode role: try enum first, then map from mode
        if let r = try? container.decode(InterviewRole.self, forKey: .role) {
            role = r
        } else {
            // Map mode string to role
            switch mode {
            case "resume", "tech", "project", "delivery", "implementation":
                role = .operations
            case "product":
                role = .productManager
            default:
                role = .general
            }
        }

        expectedKeywords = try container.decodeIfPresent([String].self, forKey: .expectedKeywords) ?? []
        let decodedKeywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
        keywords = decodedKeywords.isEmpty ? expectedKeywords : decodedKeywords
        idealPoints = try container.decodeIfPresent([String].self, forKey: .idealPoints) ?? []
        sampleAnswer = try container.decodeIfPresent(String.self, forKey: .sampleAnswer) ?? ""
        followUps = try container.decodeIfPresent([String].self, forKey: .followUps) ?? []
        timeLimitSeconds = try container.decodeIfPresent(Int.self, forKey: .timeLimitSeconds) ?? 300
        resources = try container.decodeIfPresent([LearningResource].self, forKey: .resources) ?? []
    }
}

// MARK: - Score Types

struct ScoreDimensions: Codable, Hashable {
    var technical: Int
    var structure: Int
    var projectEvidence: Int
    var risk: Int
    var quantification: Int
    var management: Int
}

struct ScoreResult: Codable {
    var score: Int
    var summary: String
    var dimensions: ScoreDimensions
    var matchedKeywords: [String]
    var missingKeywords: [String]
    var misses: [String]
    var strengths: [String]
    var followUps: [String]
}

struct CoachingResult: Codable {
    var scoreResult: ScoreResult
    var targetAnswer: String
    var answerFramework: [String]
    var keyPhrases: [String]
    var memorizationTips: [String]
    var rehearsalChecklist: [String]
}

struct RecitationResult: Codable {
    var score: Int
    var summary: String
    var coverage: Int
    var clarity: Int
    var fluency: Int
    var confidence: Int
    var improvements: [String]
    var correctedVersion: String
}

// MARK: - Review & Tracking

enum ReviewStatus: String, Codable {
    case learning
    case mastered
}

struct ReviewState: Codable {
    var status: ReviewStatus
    var intervalDays: Int
    var lastScore: Int
    var attempts: Int
    var lastReviewedAt: Date
    var nextReviewAt: Date
}

struct AttemptRecord: Codable, Identifiable {
    var id = UUID()
    let questionId: String
    let prompt: String
    let category: String
    let mode: String
    let score: Int
    let dimensions: ScoreDimensions
    let missingKeywords: [String]
    let date: Date
}

struct MockSessionQuestionSummary: Codable, Identifiable, Hashable {
    let id: String
    let prompt: String
    let answerPreview: String
    let score: Int?
    let misses: [String]
}

struct MockSessionReport: Codable, Identifiable, Hashable {
    var id = UUID()
    let title: String
    let modeTitle: String
    let questionCount: Int
    let answeredCount: Int
    let scoredCount: Int
    let averageScore: Int?
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let questionSummaries: [MockSessionQuestionSummary]
    let weakPoints: [String]
    let nextActions: [String]

    var shareText: String {
        var lines: [String] = [
            title,
            "模式：\(modeTitle)",
            "时间：\(Self.dateFormatter.string(from: endedAt))",
            "用时：\(Self.durationText(durationSeconds))",
            "完成：\(answeredCount)/\(questionCount) 题",
            "AI评分：\(averageScore.map { "\($0) 分" } ?? "待评分")"
        ]

        if !weakPoints.isEmpty {
            lines.append("")
            lines.append("需要强化")
            lines.append(contentsOf: weakPoints.map { "- \($0)" })
        }

        if !nextActions.isEmpty {
            lines.append("")
            lines.append("下一步")
            lines.append(contentsOf: nextActions.map { "- \($0)" })
        }

        lines.append("")
        lines.append("逐题记录")
        for item in questionSummaries {
            lines.append("- \(item.prompt)")
            lines.append("  得分：\(item.score.map { "\($0)" } ?? "待评分")")
            if !item.answerPreview.isEmpty {
                lines.append("  回答：\(item.answerPreview)")
            }
        }

        return lines.joined(separator: "\n")
    }

    static func durationText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes == 0 { return "\(remainder) 秒" }
        return "\(minutes) 分 \(remainder) 秒"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

// MARK: - Expression Metrics

struct ExpressionMetrics {
    var characterCount: Int = 0
    var durationSeconds: Int = 0
    var fillerWordCount: Int = 0
    var speakingRate: Double = 0

    static let fillerWords = ["然后", "就是", "这个", "那个", "嗯", "呃", "其实", "可能"]

    static func detect(in text: String, durationSeconds: Int = 0) -> ExpressionMetrics {
        let count = text.count
        let fillers = fillerWords.reduce(0) { total, word in
            total + text.components(separatedBy: word).count - 1
        }
        let rate = durationSeconds > 0 ? Double(count) / Double(durationSeconds) * 60.0 : 0
        return ExpressionMetrics(
            characterCount: count,
            durationSeconds: durationSeconds,
            fillerWordCount: fillers,
            speakingRate: rate
        )
    }
}
