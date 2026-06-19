import Foundation

struct ScoreDimension: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let score: Int
    let note: String
}

struct AnswerEvaluation: Identifiable, Hashable, Codable {
    let id: UUID
    let questionPrompt: String
    let answerText: String
    let overallScore: Int
    let dimensions: [ScoreDimension]
    let strengths: [String]
    let improvements: [String]
    let optimizedAnswer: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        questionPrompt: String,
        answerText: String,
        overallScore: Int,
        dimensions: [ScoreDimension],
        strengths: [String],
        improvements: [String],
        optimizedAnswer: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.questionPrompt = questionPrompt
        self.answerText = answerText
        self.overallScore = overallScore
        self.dimensions = dimensions
        self.strengths = strengths
        self.improvements = improvements
        self.optimizedAnswer = optimizedAnswer
        self.createdAt = createdAt
    }
}

