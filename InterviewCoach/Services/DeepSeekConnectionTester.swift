import Foundation

struct DeepSeekConnectionTester {
    @MainActor
    func test(apiKey: String, model: DeepSeekModel) async throws -> AnswerEvaluation {
        let question = InterviewQuestion(
            id: "deepseek-connection-test",
            role: .iosDeveloper,
            category: .technical,
            difficulty: .mid,
            prompt: "讲一个你做过的 iOS 性能优化项目，你如何定位问题、验证效果，并防止回归？",
            expectedKeywords: ["iOS", "性能优化", "Instruments"],
            sampleAnswer: "",
            followUps: [],
            timeLimitSeconds: 180
        )
        let profile = ResumeProfile(
            candidateName: "测试候选人",
            headline: "iOS Developer",
            matchedRoles: [.iosDeveloper],
            skills: ["SwiftUI", "UIKit", "性能优化"],
            projectKeywords: ["启动优化"],
            seniority: .mid,
            confidence: 0.85,
            rawText: "SwiftUI UIKit 性能优化"
        )

        // Temporarily save the key for the test
        try SecureAPIKeyStore.saveDeepSeekKey(apiKey)

        let service = DeepSeekInterviewAIService(model: model.rawValue)
        return try await service.evaluate(
            answer: "我负责过在线教育 App 的启动性能优化，使用 Instruments 和日志定位冷启动慢的问题，最后通过延迟初始化和缓存预热把启动时间降低了 28%。",
            for: question,
            profile: profile
        )
    }
}
