import XCTest
@testable import InterviewCoach

final class QuestionMatcherTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearInterviewCoachDefaults()
    }

    func testMatchesResumeProfileToRelevantQuestionBank() {
        let profile = ResumeProfile(
            candidateName: "张三",
            headline: "iOS Developer",
            matchedRoles: [.iosDeveloper],
            skills: ["Swift", "SwiftUI", "UIKit", "性能优化"],
            projectKeywords: ["支付", "推送通知"],
            seniority: .mid,
            confidence: 0.82,
            rawText: "Swift SwiftUI UIKit iOS 性能优化"
        )
        let bank = [
            InterviewQuestion(
                id: "ios-swiftui",
                role: .iosDeveloper,
                category: .technical,
                difficulty: .mid,
                prompt: "请解释 SwiftUI 状态管理，并结合性能优化项目说明。",
                expectedKeywords: ["SwiftUI", "UIKit", "性能优化"]
            ),
            InterviewQuestion(
                id: "backend-cache",
                role: .backendDeveloper,
                category: .technical,
                difficulty: .mid,
                prompt: "Redis 缓存击穿如何处理？",
                expectedKeywords: ["Redis", "缓存"]
            ),
            InterviewQuestion(
                id: "general-intro",
                role: .general,
                category: .hr,
                difficulty: .junior,
                prompt: "请做一个 1 分钟自我介绍。",
                expectedKeywords: ["自我介绍", "岗位匹配"]
            )
        ]

        let questions = QuestionMatcher().match(
            profile: profile,
            questions: bank,
            limit: 2
        )

        XCTAssertEqual(questions.count, 2)
        XCTAssertEqual(questions.first?.id, "ios-swiftui")
        XCTAssertTrue(questions.contains { $0.role == .general })
    }

    func testJobDescriptionGapsRaiseTargetedQuestions() {
        let resume = ResumeProfile(
            candidateName: "张三",
            headline: "iOS Developer",
            matchedRoles: [.iosDeveloper],
            skills: ["UIKit"],
            projectKeywords: [],
            seniority: .mid,
            confidence: 0.7,
            rawText: "UIKit"
        )
        let job = JobDescriptionProfile(
            title: "iOS 开发工程师",
            matchedRoles: [.iosDeveloper],
            requiredSkills: ["SwiftUI", "Combine", "性能优化"],
            responsibilities: ["负责 SwiftUI 页面开发和性能优化"],
            gapKeywords: ["SwiftUI", "Combine", "性能优化"],
            seniority: .mid,
            confidence: 0.85,
            rawText: "SwiftUI Combine 性能优化"
        )
        let bank = [
            InterviewQuestion(
                id: "ios-swiftui-combine",
                role: .iosDeveloper,
                category: .technical,
                difficulty: .mid,
                prompt: "SwiftUI 和 Combine 在状态管理中的协作方式是什么？",
                expectedKeywords: ["SwiftUI", "Combine"]
            ),
            InterviewQuestion(
                id: "ios-uikit-basic",
                role: .iosDeveloper,
                category: .technical,
                difficulty: .mid,
                prompt: "UIKit ViewController 生命周期有哪些？",
                expectedKeywords: ["UIKit"]
            ),
            InterviewQuestion(
                id: "general-intro",
                role: .general,
                category: .hr,
                difficulty: .junior,
                prompt: "请做一个自我介绍。",
                expectedKeywords: ["自我介绍"]
            )
        ]

        let questions = QuestionMatcher().match(
            profile: resume,
            jobDescription: job,
            questions: bank,
            limit: 2
        )

        XCTAssertEqual(questions.first?.id, "ios-swiftui-combine")
    }

    func testTechStackMatchingPrioritizesStackQuestionsOverProjectKeywords() {
        let profile = ResumeProfile(
            candidateName: "匿名候选人",
            headline: "运维工程师",
            matchedRoles: [.operations],
            skills: ["Jenkins", "Docker", "Kubernetes", "Harbor"],
            techStack: [
                TechStackEntity(name: "Jenkins", category: .ciCd, confidence: 0.92, evidence: ["Jenkins"]),
                TechStackEntity(name: "Docker", category: .container, confidence: 0.9, evidence: ["Docker"]),
                TechStackEntity(name: "Kubernetes", category: .orchestrator, confidence: 0.95, evidence: ["K8S"]),
                TechStackEntity(name: "Harbor", category: .registry, confidence: 0.88, evidence: ["Harbor"])
            ],
            projectKeywords: ["支付"],
            seniority: .mid,
            confidence: 0.85,
            rawText: "Jenkins Docker K8S Harbor 支付项目"
        )
        let bank = [
            InterviewQuestion(
                id: "ops-k8s-harbor",
                role: .operations,
                category: .technical,
                difficulty: .mid,
                mode: PracticeMode.tech.rawValue,
                prompt: "Kubernetes 集群中 Harbor 镜像拉取失败，你会如何排查 imagePullSecrets、证书信任和节点配置？",
                expectedKeywords: ["Kubernetes", "Harbor", "imagePullSecrets"]
            ),
            InterviewQuestion(
                id: "ops-payment-project",
                role: .operations,
                category: .project,
                difficulty: .mid,
                mode: PracticeMode.project.rawValue,
                prompt: "请讲一个支付项目经历，重点说明项目背景、职责和结果。",
                expectedKeywords: ["支付", "项目经历"]
            ),
            InterviewQuestion(
                id: "general-intro",
                role: .general,
                category: .hr,
                difficulty: .junior,
                prompt: "请做一个自我介绍。",
                expectedKeywords: ["自我介绍"]
            )
        ]

        let questions = QuestionMatcher().match(profile: profile, questions: bank, limit: 2)

        XCTAssertEqual(questions.first?.id, "ops-k8s-harbor")
        XCTAssertFalse(questions.prefix(1).contains { $0.id == "ops-payment-project" })
    }

    @MainActor
    func testReportFollowUpStartsOnlyUnscoredQuestions() {
        let viewModel = AppViewModel()
        let report = makeReport(
            summaries: [
                MockSessionQuestionSummary(id: "ios-swiftui-state", prompt: "SwiftUI", answerPreview: "", score: nil, misses: []),
                MockSessionQuestionSummary(id: "ios-performance", prompt: "Performance", answerPreview: "answered", score: 82, misses: []),
                MockSessionQuestionSummary(id: "general-self-intro", prompt: "Intro", answerPreview: "", score: nil, misses: [])
            ],
            scoredCount: 1
        )

        viewModel.startReportFollowUp(report)

        XCTAssertTrue(viewModel.isMockSessionActive)
        XCTAssertEqual(viewModel.currentQuestions.map(\.id), ["ios-swiftui-state", "general-self-intro"])
    }

    @MainActor
    func testReportFollowUpRestartsFullReportWhenAllQuestionsScored() {
        let viewModel = AppViewModel()
        let report = makeReport(
            summaries: [
                MockSessionQuestionSummary(id: "ios-swiftui-state", prompt: "SwiftUI", answerPreview: "answered", score: 88, misses: []),
                MockSessionQuestionSummary(id: "ios-performance", prompt: "Performance", answerPreview: "answered", score: 82, misses: []),
                MockSessionQuestionSummary(id: "general-self-intro", prompt: "Intro", answerPreview: "answered", score: 91, misses: [])
            ],
            scoredCount: 3
        )

        viewModel.startReportFollowUp(report)

        XCTAssertTrue(viewModel.isMockSessionActive)
        XCTAssertEqual(viewModel.currentQuestions.map(\.id), ["ios-swiftui-state", "ios-performance", "general-self-intro"])
    }

    private func makeReport(summaries: [MockSessionQuestionSummary], scoredCount: Int) -> MockSessionReport {
        let now = Date()
        return MockSessionReport(
            title: "模拟面试报告",
            modeTitle: "测试",
            questionCount: summaries.count,
            answeredCount: summaries.filter { !$0.answerPreview.isEmpty }.count,
            scoredCount: scoredCount,
            averageScore: nil,
            startedAt: now,
            endedAt: now,
            durationSeconds: 60,
            questionSummaries: summaries,
            weakPoints: [],
            nextActions: []
        )
    }

    private func clearInterviewCoachDefaults() {
        [
            "InterviewCoach.savedJobDescription",
            "interviewCoach.attempts",
            "interviewCoach.mastery",
            "interviewCoach.sessionReports"
        ].forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}

@MainActor
final class QuestionBankLoadTests: XCTestCase {
    func testQuestionBankInitializesWithFallbackBeforeLoadingBundledJSON() {
        let bank = QuestionBank()

        XCTAssertEqual(bank.questions.count, 3)
    }

    func testQuestionBankLoadsBundledQuestionsAsynchronously() async {
        let bank = QuestionBank()

        await bank.loadBundledQuestionsIfNeeded()

        XCTAssertGreaterThan(bank.questions.count, 3)
    }
}
