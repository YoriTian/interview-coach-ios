import Foundation

@MainActor
protocol InterviewAIProviding {
    func evaluate(answer: String, for question: InterviewQuestion, profile: ResumeProfile?) async throws -> AnswerEvaluation
    func scoreAnswer(question: InterviewQuestion, answer: String) async throws -> ScoreResult
    func coachAnswer(question: InterviewQuestion, answer: String) async throws -> CoachingResult
    func evaluateRecitation(question: InterviewQuestion, targetAnswer: String, originalAnswer: String, recitation: String) async throws -> RecitationResult
    func extractTechStackEntities(from resumeText: String) async throws -> [TechStackEntity]
}

struct DeepSeekInterviewAIService: InterviewAIProviding {
    let model: String

    func evaluate(answer: String, for question: InterviewQuestion, profile: ResumeProfile?) async throws -> AnswerEvaluation {
        try await DeepSeekClient.evaluate(answer: answer, for: question, profile: profile, model: model)
    }

    func scoreAnswer(question: InterviewQuestion, answer: String) async throws -> ScoreResult {
        try await DeepSeekClient.score(question: question, answer: answer, model: model)
    }

    func coachAnswer(question: InterviewQuestion, answer: String) async throws -> CoachingResult {
        try await DeepSeekClient.coach(question: question, answer: answer, model: model)
    }

    func evaluateRecitation(question: InterviewQuestion, targetAnswer: String, originalAnswer: String, recitation: String) async throws -> RecitationResult {
        try await DeepSeekClient.scoreRecitation(question: question, targetAnswer: targetAnswer, originalAnswer: originalAnswer, recitation: recitation, model: model)
    }

    func extractTechStackEntities(from resumeText: String) async throws -> [TechStackEntity] {
        try await DeepSeekClient.extractTechStackEntities(from: resumeText, model: model)
    }
}
