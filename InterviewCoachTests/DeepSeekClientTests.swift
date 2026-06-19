import XCTest
@testable import InterviewCoach

final class DeepSeekClientTests: XCTestCase {
    func testBuildsJSONModeRequestForFlashModel() throws {
        let question = makeQuestion()
        let request = try DeepSeekClient.makeChatCompletionRequest(
            apiKey: "test-key",
            model: DeepSeekModel.flash.rawValue,
            system: "你是严谨的中文面试考官。",
            user: "题目：\(question.prompt)\n候选人回答：我负责过 SwiftUI 页面性能优化。\n只输出 JSON。",
            maxTokens: 600
        )

        XCTAssertEqual(request.url?.absoluteString, "https://api.deepseek.com/chat/completions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "deepseek-v4-flash")
        XCTAssertEqual(json["max_tokens"] as? Int, 600)
        XCTAssertEqual((json["response_format"] as? [String: Any])?["type"] as? String, "json_object")
        XCTAssertEqual((json["thinking"] as? [String: Any])?["type"] as? String, "disabled")

        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let prompt = messages.compactMap { $0["content"] as? String }.joined(separator: "\n")
        XCTAssertTrue(prompt.contains("JSON"))
        XCTAssertTrue(prompt.contains(question.prompt))
    }

    func testDecodesSuccessfulChatCompletionPayload() throws {
        let content = """
        {
          "score": 88,
          "summary": "结构清晰",
          "dimensions": {
            "technical": 90,
            "structure": 86,
            "projectEvidence": 82,
            "risk": 80,
            "quantification": 78,
            "management": 70
          },
          "strengths": ["结构清晰"],
          "misses": ["补充量化结果"],
          "followUps": ["如果线上已受影响，你如何止血？"]
        }
        """
        let responseBody = chatCompletionBody(content: content)

        let payload = try DeepSeekClient.decodeChatCompletionResponse(
            TestScorePayload.self,
            data: Data(responseBody.utf8),
            response: httpResponse(statusCode: 200)
        )

        XCTAssertEqual(payload.score, 88)
        XCTAssertEqual(payload.summary, "结构清晰")
        XCTAssertEqual(payload.dimensions.technical, 90)
        XCTAssertEqual(payload.strengths, ["结构清晰"])
        XCTAssertEqual(payload.misses, ["补充量化结果"])
    }

    func testThrowsFriendlyErrorForHTTPFailure() {
        let body = """
        {
          "error": {
            "message": "Authentication fails due to the wrong API key."
          }
        }
        """

        XCTAssertThrowsError(
            try DeepSeekClient.decodeChatCompletionResponse(
                TestScorePayload.self,
                data: Data(body.utf8),
                response: httpResponse(statusCode: 401)
            )
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("401"))
            XCTAssertTrue(error.localizedDescription.contains("Authentication fails"))
        }
    }

    func testRejectsMalformedEvaluationPayload() {
        let responseBody = chatCompletionBody(content: "{\"score\": 88}")

        XCTAssertThrowsError(
            try DeepSeekClient.decodeChatCompletionResponse(
                StrictEvaluationPayload.self,
                data: Data(responseBody.utf8),
                response: httpResponse(statusCode: 200)
            )
        ) { error in
            XCTAssertEqual(error.localizedDescription, DeepSeekAPIError.invalidJSON.localizedDescription)
        }
    }

    private func makeQuestion() -> InterviewQuestion {
        InterviewQuestion(
            id: "ios-performance",
            role: .iosDeveloper,
            category: .project,
            difficulty: .mid,
            prompt: "讲一个你做过的 iOS 性能优化项目，你如何定位问题、验证效果，并防止回归？",
            expectedKeywords: ["SwiftUI", "Instruments", "性能优化"]
        )
    }

    private func httpResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.deepseek.com/chat/completions")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    private func chatCompletionBody(content: String) -> String {
        let encoded = try! String(data: JSONEncoder().encode(content), encoding: .utf8)!
        return """
        {
          "choices": [
            {
              "message": {
                "role": "assistant",
                "content": \(encoded)
              }
            }
          ]
        }
        """
    }
}

private struct TestScorePayload: Decodable {
    let score: Int
    let summary: String
    let dimensions: TestDimensions
    let strengths: [String]
    let misses: [String]
}

private struct TestDimensions: Decodable {
    let technical: Int
}

private struct StrictEvaluationPayload: Decodable {
    let overallScore: Int
    let strengths: [String]
    let improvements: [String]
    let optimizedAnswer: String
}
