import Foundation

enum TechStackCategory: String, CaseIterable, Identifiable, Codable {
    case ciCd = "CI/CD"
    case container = "容器"
    case orchestrator = "编排"
    case registry = "镜像仓库"
    case cloudNative = "云原生"
    case automation = "自动化"
    case operatingSystem = "操作系统"
    case database = "数据库"
    case middleware = "中间件"
    case monitoring = "监控"
    case language = "编程语言"
    case mobile = "移动端"
    case frontend = "前端"
    case backend = "后端"
    case ai = "AI"
    case other = "其他"

    var id: String { rawValue }

    static func fromAIValue(_ value: String?) -> TechStackCategory {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            ?? ""
        if let exact = allCases.first(where: { $0.rawValue.lowercased() == normalized }) {
            return exact
        }

        switch normalized {
        case "cicd", "ci cd", "devops", "流水线", "持续集成", "持续交付":
            return .ciCd
        case "container", "containers", "容器化":
            return .container
        case "orchestration", "orchestrator", "k8s", "kubernetes", "编排平台":
            return .orchestrator
        case "registry", "image registry", "仓库":
            return .registry
        case "cloud native", "cloud-native":
            return .cloudNative
        case "automation", "自动化运维", "iac":
            return .automation
        case "os", "linux", "操作系统/脚本":
            return .operatingSystem
        case "db", "database":
            return .database
        case "mq", "middleware":
            return .middleware
        case "observability", "monitoring", "可观测性":
            return .monitoring
        case "language", "programming language":
            return .language
        case "ios", "mobile":
            return .mobile
        case "front-end", "frontend":
            return .frontend
        case "back-end", "backend":
            return .backend
        case "ai", "llm", "大模型":
            return .ai
        default:
            return .other
        }
    }

    var symbolName: String {
        switch self {
        case .ciCd: return "arrow.triangle.branch"
        case .container: return "shippingbox"
        case .orchestrator: return "square.stack.3d.up"
        case .registry: return "archivebox"
        case .cloudNative: return "cloud"
        case .automation: return "gearshape.2"
        case .operatingSystem: return "terminal"
        case .database: return "cylinder.split.1x2"
        case .middleware: return "server.rack"
        case .monitoring: return "waveform.path.ecg"
        case .language: return "chevron.left.forwardslash.chevron.right"
        case .mobile: return "iphone.gen3"
        case .frontend: return "safari"
        case .backend: return "network"
        case .ai: return "sparkles"
        case .other: return "tag"
        }
    }
}

struct TechStackEntity: Equatable, Hashable, Codable, Identifiable {
    let name: String
    let category: TechStackCategory
    let confidence: Double
    let evidence: [String]

    var id: String { name.lowercased() }
}

struct ResumeProfile: Equatable, Codable {
    let candidateName: String?
    let headline: String
    let matchedRoles: [InterviewRole]
    let skills: [String]
    var techStack: [TechStackEntity] = []
    let projectKeywords: [String]
    let seniority: QuestionDifficulty
    let confidence: Double
    let rawText: String

    init(
        candidateName: String?,
        headline: String,
        matchedRoles: [InterviewRole],
        skills: [String],
        techStack: [TechStackEntity] = [],
        projectKeywords: [String],
        seniority: QuestionDifficulty,
        confidence: Double,
        rawText: String
    ) {
        self.candidateName = candidateName
        self.headline = headline
        self.matchedRoles = matchedRoles
        self.skills = skills
        self.techStack = techStack
        self.projectKeywords = projectKeywords
        self.seniority = seniority
        self.confidence = confidence
        self.rawText = rawText
    }

    enum CodingKeys: String, CodingKey {
        case candidateName, headline, matchedRoles, skills, techStack, projectKeywords, seniority, confidence, rawText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        candidateName = try container.decodeIfPresent(String.self, forKey: .candidateName)
        headline = try container.decode(String.self, forKey: .headline)
        matchedRoles = try container.decode([InterviewRole].self, forKey: .matchedRoles)
        skills = try container.decode([String].self, forKey: .skills)
        techStack = try container.decodeIfPresent([TechStackEntity].self, forKey: .techStack) ?? []
        projectKeywords = try container.decode([String].self, forKey: .projectKeywords)
        seniority = try container.decode(QuestionDifficulty.self, forKey: .seniority)
        confidence = try container.decode(Double.self, forKey: .confidence)
        rawText = try container.decode(String.self, forKey: .rawText)
    }

    var primaryRole: InterviewRole {
        matchedRoles.first ?? .general
    }

    var summary: String {
        let roleText = matchedRoles.prefix(2).map(\.rawValue).joined(separator: " / ")
        let skillText = (techStack.isEmpty ? skills : techStack.map(\.name)).prefix(5).joined(separator: "、")
        return "\(roleText.isEmpty ? "通用面试" : roleText) · \(seniority.rawValue) · \(skillText)"
    }

    func mergingTechStack(_ entities: [TechStackEntity]) -> ResumeProfile {
        guard !entities.isEmpty else { return self }
        var mergedByName: [String: TechStackEntity] = [:]

        for entity in techStack + entities {
            let key = entity.name.lowercased()
            if let current = mergedByName[key] {
                let evidence = Array(Set(current.evidence + entity.evidence)).sorted()
                mergedByName[key] = TechStackEntity(
                    name: current.name,
                    category: current.category == .other ? entity.category : current.category,
                    confidence: max(current.confidence, entity.confidence),
                    evidence: evidence
                )
            } else {
                mergedByName[key] = entity
            }
        }

        let mergedStack = mergedByName.values.sorted {
            if $0.confidence == $1.confidence { return $0.name < $1.name }
            return $0.confidence > $1.confidence
        }
        var skillSet = Set(skills.map { $0.lowercased() })
        let mergedSkills = skills + mergedStack.compactMap { entity in
            if skillSet.insert(entity.name.lowercased()).inserted {
                return entity.name
            }
            return nil
        }

        return ResumeProfile(
            candidateName: candidateName,
            headline: headline,
            matchedRoles: matchedRoles,
            skills: mergedSkills,
            techStack: mergedStack,
            projectKeywords: projectKeywords,
            seniority: seniority,
            confidence: max(confidence, mergedStack.isEmpty ? confidence : 0.72),
            rawText: rawText
        )
    }
}

struct JobDescriptionProfile: Equatable, Codable {
    let title: String
    let matchedRoles: [InterviewRole]
    let requiredSkills: [String]
    let responsibilities: [String]
    let gapKeywords: [String]
    let seniority: QuestionDifficulty
    let confidence: Double
    let rawText: String

    var primaryRole: InterviewRole {
        matchedRoles.first ?? .general
    }

    var summary: String {
        let roleText = matchedRoles.prefix(2).map(\.rawValue).joined(separator: " / ")
        let skillText = requiredSkills.prefix(5).joined(separator: "、")
        return "\(title) · \(roleText.isEmpty ? "通用面试" : roleText) · \(seniority.rawValue) · \(skillText)"
    }
}
