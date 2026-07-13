import Foundation

// MARK: - Model & Error

enum DeepSeekModel: String, CaseIterable, Identifiable {
    case flash = "deepseek-v4-flash"
    case pro = "deepseek-v4-pro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash: return "DeepSeek V4 Flash"
        case .pro: return "DeepSeek V4 Pro"
        }
    }

    var detail: String {
        switch self {
        case .flash: return "响应更快，适合日常练习"
        case .pro: return "深度思考，适合严格评分与专项出题"
        }
    }

    var usesDeepThinking: Bool { self == .pro }
}

enum DeepSeekAPIError: LocalizedError {
    case noAPIKey
    case invalidHTTPResponse
    case httpStatus(code: Int, message: String)
    case emptyChoice
    case invalidJSON
    case network(String)
    case noGeneratedQuestions

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "请先在设置里保存 DeepSeek API Key。"
        case .invalidHTTPResponse:
            return "DeepSeek 返回了无效的网络响应。"
        case .httpStatus(let code, let message):
            return "DeepSeek 请求失败（\(code)）：\(message)"
        case .emptyChoice:
            return "DeepSeek 没有返回可用回答。"
        case .invalidJSON:
            return "DeepSeek 返回的 JSON 格式不符合预期。"
        case .network(let message):
            return "网络请求失败：\(message)"
        case .noGeneratedQuestions:
            return "DeepSeek 没有生成可用题目，请稍后重试。"
        }
    }
}

// MARK: - Public API

enum DeepSeekClient {
    static func makeChatCompletionRequest(apiKey: String, model: String, system: String, user: String, maxTokens: Int) throws -> URLRequest {
        let selectedModel = DeepSeekModel(rawValue: model) ?? .pro
        let body = ChatCompletionRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: system),
                ChatMessage(role: "user", content: user)
            ],
            responseFormat: ResponseFormat(type: "json_object"),
            thinking: Thinking(type: selectedModel.usesDeepThinking ? "enabled" : "disabled"),
            reasoningEffort: selectedModel.usesDeepThinking ? "high" : nil,
            maxTokens: maxTokens
        )
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = selectedModel.usesDeepThinking ? 120 : 60
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    static func decodeChatCompletionResponse<T: Decodable>(_ type: T.Type, data: Data, response: URLResponse) throws -> T {
        guard let http = response as? HTTPURLResponse else {
            throw DeepSeekAPIError.invalidHTTPResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(DeepSeekErrorResponse.self, from: data).error.message)
                ?? String(data: data, encoding: .utf8)
                ?? "未知错误"
            throw DeepSeekAPIError.httpStatus(code: http.statusCode, message: message)
        }
        let chat = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chat.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeepSeekAPIError.emptyChoice
        }
        return try decodeJSON(type, from: content)
    }

    static func score(question: InterviewQuestion, answer: String, model: String) async throws -> ScoreResult {
        let ai = try await requestJSON(
            model: model,
            system: "你是严谨的中文面试考官，关注技术准确性、项目证据、风险意识和表达结构。",
            user: """
            你是中文高级面试官。只输出 JSON，不要 Markdown。
            题目：\(question.prompt)
            候选人回答：\(answer)
            请返回：{"score":0-100,"summary":"一句话评价","dimensions":{"technical":0-100,"structure":0-100,"projectEvidence":0-100,"risk":0-100,"quantification":0-100,"management":0-100},"strengths":["..."],"misses":["..."],"followUps":["..."]}
            """,
            maxTokens: 1400,
            as: AIScore.self
        )
        return aiScoreResult(ai, fallback: aiFallbackScore(question: question))
    }

    static func coach(question: InterviewQuestion, answer: String, model: String) async throws -> CoachingResult {
        let keywords = question.keywords.prefix(10).joined(separator: "、")
        let points = question.idealPoints.joined(separator: "；")
        let ai = try await requestJSON(
            model: model,
            system: "你是中文高级面试教练。你的目标不是写书面答案，而是把候选人的回答改成面试现场可自然说出的表达。",
            user: """
            只输出 JSON，不要 Markdown。
            面试题：\(question.prompt)
            题目分类：\(question.category.rawValue)
            关键词：\(keywords)
            理想要点：\(points)
            候选人原回答：\(answer)

            请先严格评分，再教他怎么说。targetAnswer 必须是 70 到 110 秒口述版本，像真人面试回答，不要像文章。
            返回 JSON：
            {
              "score":0-100,
              "summary":"一句话指出当前最大问题",
              "dimensions":{"technical":0-100,"structure":0-100,"projectEvidence":0-100,"risk":0-100,"quantification":0-100,"management":0-100},
              "strengths":["已经做对的点"],
              "misses":["必须强化的点"],
              "followUps":["面试官可能追问"],
              "targetAnswer":"可直接背诵的口述答案",
              "answerFramework":["第一句怎么开头","项目证据怎么接","结果和复盘怎么收尾"],
              "keyPhrases":["可背诵短句"],
              "memorizationTips":["怎么背更快"],
              "rehearsalChecklist":["复述时自查项"]
            }
            """,
            maxTokens: 2200,
            as: AICoaching.self
        )
        return CoachingResult(
            scoreResult: aiScoreResult(ai, fallback: aiFallbackScore(question: question)),
            targetAnswer: ai.targetAnswer?.nilIfBlank ?? fallbackTargetAnswer(question: question),
            answerFramework: limited(ai.answerFramework, fallback: [
                "先用一句话给出岗位匹配结论。",
                "再用一个真实项目说明职责、动作和结果。",
                "最后补风险控制、复盘和团队协同。"
            ]),
            keyPhrases: limited(ai.keyPhrases, fallback: ["我先讲结论", "项目里我主要负责", "最后我会做复盘固化"]),
            memorizationTips: limited(ai.memorizationTips, fallback: ["先背结构，再背关键词，不要逐字背。"]),
            rehearsalChecklist: limited(ai.rehearsalChecklist, fallback: ["是否有结论", "是否有项目证据", "是否有量化结果"])
        )
    }

    static func scoreRecitation(question: InterviewQuestion, targetAnswer: String, originalAnswer: String, recitation: String, model: String) async throws -> RecitationResult {
        try await requestJSON(
            model: model,
            system: "你是中文面试表达教练，专门评估候选人是否把示范答案复述成自然、可信、可面试的表达。",
            user: """
            只输出 JSON，不要 Markdown。
            面试题：\(question.prompt)
            原回答：\(originalAnswer)
            示范说法：\(targetAnswer)
            候选人复述：\(recitation)

            请按复述完整度、表达清晰度、流畅度、信心感评分。不要要求逐字一致，重点看是否说出了结构、项目证据、处理动作和结果复盘。
            返回 JSON：
            {
              "score":0-100,
              "summary":"一句话评价复述水平",
              "coverage":0-100,
              "clarity":0-100,
              "fluency":0-100,
              "confidence":0-100,
              "improvements":["下一遍要改的点"],
              "correctedVersion":"下一遍建议照着说的更自然版本"
            }
            """,
            maxTokens: 1600,
            as: RecitationResult.self
        )
    }

    static func extractTechStackEntities(from resumeText: String, model: String) async throws -> [TechStackEntity] {
        let clippedResume = String(resumeText.prefix(12_000))
        let ai = try await requestJSON(
            model: model,
            system: "你是技术面试题库产品的简历解析器，只负责抽取技术栈实体。",
            user: """
            只输出 JSON，不要 Markdown。
            你的任务：从简历中抽取技术栈实体，用于后续按技术栈出面试题。
            必须抽取：工具、平台、框架、中间件、数据库、容器、CI/CD、云原生、操作系统、编程语言、AI 工具。
            必须忽略：项目名称、公司名称、业务场景、职责描述、个人评价、证书、客户名称、数量指标。
            例子：Jenkins、CI/CD、Kubernetes、K8S、Harbor、Docker、Nginx、Redis、Prometheus、Grafana、Linux、Shell。

            分类只能从这些值里选：
            CI/CD、容器、编排、镜像仓库、云原生、自动化、操作系统、数据库、中间件、监控、编程语言、移动端、前端、后端、AI、其他。

            简历全文：
            \(clippedResume)

            返回 JSON：
            {
              "entities": [
                {"name":"Jenkins","category":"CI/CD","confidence":0.0到1.0,"evidence":["简历中命中的原词"]}
              ]
            }
            """,
            maxTokens: 1800,
            as: AITechStackExtraction.self
        )
        return techStackEntities(from: ai)
    }

    static func generateTechnicalQuestions(
        for techStack: [TechStackEntity],
        role: InterviewRole,
        seniority: QuestionDifficulty,
        count: Int,
        model: String
    ) async throws -> [InterviewQuestion] {
        let selectedStack = Array(techStack.prefix(16))
        let stackDescription = selectedStack
            .map { "\($0.name)（\($0.category.rawValue)）" }
            .joined(separator: "、")
        let requestedCount = min(20, max(6, count))
        let ai = try await requestJSON(
            model: model,
            system: "你是高级技术面试题库专家，只围绕候选人的技术栈生成可验证、可追问的技术题。",
            user: """
            只输出 JSON，不要 Markdown。
            候选岗位：\(role.rawValue)
            能力级别：\(seniority.rawValue)
            技术栈：\(stackDescription)

            生成 \(requestedCount) 道中文面试题。只考技术原理、实际配置、故障排查、架构取舍、安全、性能和发布回滚；不要询问公司名、客户名、具体项目名称或简历经历。
            要求：
            1. 覆盖尽可能多的技术栈，每道题标明主要 stack。
            2. 至少三分之一是故障排查题，至少两道是跨技术栈联动题。
            3. 问题必须能区分背概念和真正做过，避免“请简单介绍”这种空题。
            4. idealPoints 给出 3 到 6 个评分要点；sampleAnswer 是 60 到 90 秒口述思路，不虚构候选人经历。
            5. category 只能是“专业能力”“方案设计”“案例分析”；difficulty 只能是“初级”“中级”“高级”。

            返回 JSON：
            {
              "questions":[
                {
                  "stack":"Kubernetes",
                  "category":"案例分析",
                  "difficulty":"高级",
                  "prompt":"题目",
                  "keywords":["关键词"],
                  "idealPoints":["评分要点"],
                  "sampleAnswer":"口述思路",
                  "followUps":["追问"],
                  "timeLimitSeconds":240
                }
              ]
            }
            """,
            maxTokens: 7_000,
            as: AIGeneratedQuestionSet.self
        )

        let questions = generatedQuestions(from: ai, role: role, fallbackDifficulty: seniority)
        guard !questions.isEmpty else { throw DeepSeekAPIError.noGeneratedQuestions }
        return Array(questions.prefix(requestedCount))
    }

    static func decodeGeneratedQuestionsJSON(
        _ content: String,
        role: InterviewRole,
        fallbackDifficulty: QuestionDifficulty
    ) throws -> [InterviewQuestion] {
        let payload = try decodeJSON(AIGeneratedQuestionSet.self, from: content)
        return generatedQuestions(from: payload, role: role, fallbackDifficulty: fallbackDifficulty)
    }

    /// Backward-compatible evaluate for AnswerEvaluation
    static func evaluate(answer: String, for question: InterviewQuestion, profile: ResumeProfile?, model: String) async throws -> AnswerEvaluation {
        let result = try await score(question: question, answer: answer, model: model)

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

    // MARK: - Private Helpers

    private static func requestJSON<T: Decodable>(model: String, system: String, user: String, maxTokens: Int, as type: T.Type) async throws -> T {
        guard let apiKey = AIServiceFactory.currentDeepSeekKey(), !apiKey.isEmpty else {
            throw DeepSeekAPIError.noAPIKey
        }
        let request = try makeChatCompletionRequest(
            apiKey: apiKey,
            model: model,
            system: system,
            user: user,
            maxTokens: maxTokens
        )
        let (data, response) = try await performRequest(request)
        return try decodeChatCompletionResponse(type, data: data, response: response)
    }

    private static func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let maximumAttempts = 2

        for attempt in 1...maximumAttempts {
            try Task.checkCancellation()
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let statusCode = (response as? HTTPURLResponse)?.statusCode,
                   isRetryableStatus(statusCode),
                   attempt < maximumAttempts {
                    try await Task.sleep(nanoseconds: 700_000_000)
                    continue
                }
                return (data, response)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard attempt < maximumAttempts, isRetryableNetworkError(error) else {
                    throw friendlyNetworkError(error)
                }
                try await Task.sleep(nanoseconds: 700_000_000)
            }
        }

        throw DeepSeekAPIError.network("请求未完成，请检查网络后重试。")
    }

    private static func isRetryableStatus(_ statusCode: Int) -> Bool {
        statusCode == 408 || statusCode == 429 || (500...599).contains(statusCode)
    }

    private static func isRetryableNetworkError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        return [.timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost, .dnsLookupFailed]
            .contains(urlError.code)
    }

    private static func friendlyNetworkError(_ error: Error) -> Error {
        guard let urlError = error as? URLError else { return error }
        switch urlError.code {
        case .timedOut:
            return DeepSeekAPIError.network("AI 思考超时，请重新提交。")
        case .notConnectedToInternet:
            return DeepSeekAPIError.network("当前没有可用网络。")
        default:
            return DeepSeekAPIError.network(urlError.localizedDescription)
        }
    }

    private static func aiScoreResult<T: AIScorePayload>(_ ai: T, fallback: ScoreResult) -> ScoreResult {
        ScoreResult(
            score: ai.score ?? fallback.score,
            summary: ai.summary ?? fallback.summary,
            dimensions: ai.dimensions?.scoreDimensions ?? fallback.dimensions,
            matchedKeywords: fallback.matchedKeywords,
            missingKeywords: limited(ai.misses, fallback: fallback.missingKeywords),
            misses: ai.misses ?? fallback.misses,
            strengths: ai.strengths ?? fallback.strengths,
            followUps: ai.followUps ?? fallback.followUps
        )
    }

    private static func aiFallbackScore(question: InterviewQuestion) -> ScoreResult {
        ScoreResult(
            score: 0,
            summary: "AI 返回内容不完整，请重新提交评分。",
            dimensions: ScoreDimensions(
                technical: 0,
                structure: 0,
                projectEvidence: 0,
                risk: 0,
                quantification: 0,
                management: 0
            ),
            matchedKeywords: [],
            missingKeywords: question.keywords,
            misses: ["AI 返回内容不完整"],
            strengths: [],
            followUps: []
        )
    }

    private static func decodeJSON<T: Decodable>(_ type: T.Type, from content: String) throws -> T {
        let decoder = JSONDecoder()
        if let data = content.data(using: .utf8), let decoded = try? decoder.decode(T.self, from: data) {
            return decoded
        }
        guard let start = content.firstIndex(of: "{"), let end = content.lastIndex(of: "}"), start <= end else {
            throw DeepSeekAPIError.invalidJSON
        }
        let json = String(content[start...end])
        do {
            return try decoder.decode(T.self, from: Data(json.utf8))
        } catch {
            throw DeepSeekAPIError.invalidJSON
        }
    }

    private static func limited(_ values: [String]?, fallback: [String]) -> [String] {
        let cleaned = values?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
        return cleaned.isEmpty ? fallback : Array(cleaned.prefix(6))
    }

    private static func fallbackTargetAnswer(question: InterviewQuestion) -> String {
        "我先讲结论，这道题我会从场景、问题、动作、结果和复盘五个部分回答。结合 \(question.category.rawValue) 场景，我会先确认影响范围和关键风险，再根据告警、日志、配置和最近变更逐层定位。处理上先做止血，保证业务可用，再推进根因修复和验证。最后我会把结果量化，并沉淀到巡检、监控、SOP 和团队复盘里。"
    }

    private static func techStackEntities(from ai: AITechStackExtraction) -> [TechStackEntity] {
        var seen = Set<String>()
        return (ai.entities ?? [])
            .compactMap { entity -> TechStackEntity? in
                guard let rawName = entity.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !rawName.isEmpty
                else { return nil }

                let name = canonicalTechName(rawName)
                guard !name.contains("项目"),
                      !name.contains("平台建设"),
                      !name.contains("负责"),
                      seen.insert(name.lowercased()).inserted
                else { return nil }

                let confidence = min(0.99, max(0.35, entity.confidence ?? 0.72))
                let evidence = (entity.evidence ?? [])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                return TechStackEntity(
                    name: name,
                    category: TechStackCategory.fromAIValue(entity.category),
                    confidence: confidence,
                    evidence: Array(evidence.prefix(4))
                )
            }
            .sorted {
                if $0.confidence == $1.confidence { return $0.name < $1.name }
                return $0.confidence > $1.confidence
            }
    }

    private static func canonicalTechName(_ rawName: String) -> String {
        switch rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "k8s": return "Kubernetes"
        case "cicd", "ci cd": return "CI/CD"
        case "gitlab-ci": return "GitLab CI"
        case "argocd": return "Argo CD"
        case "harbor/registry", "registry": return "Harbor"
        default: return rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func generatedQuestions(
        from payload: AIGeneratedQuestionSet,
        role: InterviewRole,
        fallbackDifficulty: QuestionDifficulty
    ) -> [InterviewQuestion] {
        var seenPrompts = Set<String>()
        return (payload.questions ?? []).compactMap { item in
            guard let rawPrompt = item.prompt?.trimmingCharacters(in: .whitespacesAndNewlines),
                  rawPrompt.count >= 8 else { return nil }
            let normalizedPrompt = rawPrompt.lowercased().filter { !$0.isWhitespace }
            guard seenPrompts.insert(normalizedPrompt).inserted else { return nil }

            let stack = item.stack?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
            let keywords = cleaned(item.keywords, limit: 10)
            let combinedKeywords = uniqueStrings((stack.map { [$0] } ?? []) + keywords, limit: 10)
            let idealPoints = cleaned(item.idealPoints, limit: 6)
            let followUps = cleaned(item.followUps, limit: 4)
            let difficulty = QuestionDifficulty(fromTrainerString: item.difficulty ?? fallbackDifficulty.rawValue)
            let category = InterviewCategory(fromTrainerString: item.category ?? InterviewCategory.technical.rawValue)
            let timeLimit = min(600, max(90, item.timeLimitSeconds ?? 240))

            return InterviewQuestion(
                id: "ai-\(stableIdentifier(stack: stack ?? "tech", prompt: rawPrompt))",
                role: role,
                category: category,
                difficulty: difficulty,
                mode: PracticeMode.tech.rawValue,
                prompt: rawPrompt,
                expectedKeywords: combinedKeywords,
                keywords: combinedKeywords,
                idealPoints: idealPoints,
                sampleAnswer: item.sampleAnswer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                followUps: followUps,
                timeLimitSeconds: timeLimit,
                resources: []
            )
        }
    }

    private static func cleaned(_ values: [String]?, limit: Int) -> [String] {
        uniqueStrings(
            (values ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            limit: limit
        )
    }

    private static func uniqueStrings(_ values: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        return Array(values.filter { seen.insert($0.lowercased()).inserted }.prefix(limit))
    }

    private static func stableIdentifier(stack: String, prompt: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in "\(stack)|\(prompt)".utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

// MARK: - Private Types

private protocol AIScorePayload {
    var score: Int? { get }
    var summary: String? { get }
    var dimensions: AIDimensions? { get }
    var strengths: [String]? { get }
    var misses: [String]? { get }
    var followUps: [String]? { get }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let responseFormat: ResponseFormat
    let thinking: Thinking
    let reasoningEffort: String?
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, thinking
        case responseFormat = "response_format"
        case reasoningEffort = "reasoning_effort"
        case maxTokens = "max_tokens"
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ResponseFormat: Encodable {
    let type: String
}

private struct Thinking: Encodable {
    let type: String
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        let message: ChatMessage
    }
    let choices: [Choice]
}

private struct AIDimensions: Decodable {
    let technical: Int?
    let structure: Int?
    let projectEvidence: Int?
    let risk: Int?
    let quantification: Int?
    let management: Int?

    var scoreDimensions: ScoreDimensions {
        ScoreDimensions(
            technical: technical ?? 0,
            structure: structure ?? 0,
            projectEvidence: projectEvidence ?? 0,
            risk: risk ?? 0,
            quantification: quantification ?? 0,
            management: management ?? 0
        )
    }
}

private struct AIScore: Decodable, AIScorePayload {
    let score: Int?
    let summary: String?
    let dimensions: AIDimensions?
    let strengths: [String]?
    let misses: [String]?
    let followUps: [String]?
}

private struct AICoaching: Decodable, AIScorePayload {
    let score: Int?
    let summary: String?
    let dimensions: AIDimensions?
    let strengths: [String]?
    let misses: [String]?
    let followUps: [String]?
    let targetAnswer: String?
    let answerFramework: [String]?
    let keyPhrases: [String]?
    let memorizationTips: [String]?
    let rehearsalChecklist: [String]?
}

private struct AITechStackExtraction: Decodable {
    let entities: [AITechStackEntity]?
}

private struct AITechStackEntity: Decodable {
    let name: String?
    let category: String?
    let confidence: Double?
    let evidence: [String]?
}

private struct AIGeneratedQuestionSet: Decodable {
    let questions: [AIGeneratedQuestion]?
}

private struct AIGeneratedQuestion: Decodable {
    let stack: String?
    let category: String?
    let difficulty: String?
    let prompt: String?
    let keywords: [String]?
    let idealPoints: [String]?
    let sampleAnswer: String?
    let followUps: [String]?
    let timeLimitSeconds: Int?
}

private struct DeepSeekErrorResponse: Decodable {
    let error: APIError
    struct APIError: Decodable {
        let message: String
    }
}

private extension String {
    var nilIfBlank: String? {
        let cleaned = trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}
