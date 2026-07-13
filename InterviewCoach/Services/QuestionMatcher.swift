import Foundation

struct QuestionMatcher {
    func match(profile: ResumeProfile, questions: [InterviewQuestion], limit: Int = 8) -> [InterviewQuestion] {
        match(profile: profile, jobDescription: nil, questions: questions, limit: limit)
    }

    func match(techStack: [TechStackEntity], questions: [InterviewQuestion], limit: Int = 12) -> [InterviewQuestion] {
        let scored = questions.map { question in
            (question, score(question: question, profile: nil, jobDescription: nil, explicitTechStack: techStack))
        }

        return scored
            .sorted { left, right in
                if left.1 == right.1 {
                    return left.0.id < right.0.id
                }
                return left.1 > right.1
            }
            .prefix(limit)
            .map(\.0)
    }

    func match(profile: ResumeProfile?, jobDescription: JobDescriptionProfile?, questions: [InterviewQuestion], limit: Int = 8) -> [InterviewQuestion] {
        let scored = questions.map { question in
            (question, score(question: question, profile: profile, jobDescription: jobDescription, explicitTechStack: nil))
        }

        return scored
            .sorted { left, right in
                if left.1 == right.1 {
                    return left.0.id < right.0.id
                }
                return left.1 > right.1
            }
            .prefix(limit)
            .map(\.0)
    }

    private func score(question: InterviewQuestion, profile: ResumeProfile?, jobDescription: JobDescriptionProfile?, explicitTechStack: [TechStackEntity]?) -> Double {
        var value = 0.0
        let techStack = explicitTechStack ?? profile?.techStack ?? []
        let hasTechStack = !techStack.isEmpty

        if profile?.matchedRoles.contains(question.role) == true {
            value += 7.0
        }

        if jobDescription?.matchedRoles.contains(question.role) == true {
            value += 8.0
        }

        if jobDescription != nil, question.mode == PracticeMode.jobTarget.rawValue {
            value += 12.0
        }

        if question.role == .general {
            value += 2.5
        }

        if question.difficulty == profile?.seniority {
            value += 2.0
        }

        if question.difficulty == jobDescription?.seniority {
            value += 2.2
        }

        let searchableQuestion = ([question.prompt, question.sampleAnswer] + question.expectedKeywords + question.keywords + question.idealPoints + question.followUps)
            .joined(separator: " ")
            .lowercased()

        if hasTechStack {
            if question.mode == PracticeMode.tech.rawValue {
                value += 3.0
            }
            if question.category == .technical || question.category == .systemDesign {
                value += 2.0
            }
            if question.category == .project {
                value -= 2.5
            }
        }

        for entity in techStack {
            let terms = entityTerms(for: entity)
            if terms.contains(where: { searchableQuestion.contains($0) }) {
                value += 3.8 * max(0.5, entity.confidence)
            }
            if categoryTerms(for: entity.category).contains(where: { searchableQuestion.contains($0) }) {
                value += 0.9
            }
        }

        if !hasTechStack {
            for skill in profile?.skills ?? [] {
                if searchableQuestion.contains(skill.lowercased()) {
                    value += 1.6
                }
            }
        }

        for skill in jobDescription?.requiredSkills ?? [] {
            if searchableQuestion.contains(skill.lowercased()) {
                value += 2.0
            }
        }

        for gap in jobDescription?.gapKeywords ?? [] {
            if searchableQuestion.contains(gap.lowercased()) {
                value += 2.6
            }
        }

        for responsibility in jobDescription?.responsibilities ?? [] {
            let tokens = responsibility
                .components(separatedBy: CharacterSet(charactersIn: "，。；、,.;/ "))
                .filter { $0.count >= 2 }
            if tokens.contains(where: { searchableQuestion.contains($0.lowercased()) }) {
                value += 0.9
            }
        }

        if question.category == .project {
            value += jobDescription != nil ? 1.0 : 0.2
        }

        if question.category == .caseStudy, jobDescription != nil {
            value += 1.0
        }

        return value
    }

    private func entityTerms(for entity: TechStackEntity) -> [String] {
        var terms = Set(([entity.name] + entity.evidence).map { $0.lowercased() })
        switch entity.name.lowercased() {
        case "kubernetes":
            terms.formUnion(["kubernetes", "k8s", "pod", "kubectl", "kubelet", "service", "ingress"])
        case "docker":
            terms.formUnion(["docker", "dockerfile", "容器", "容器化", "镜像"])
        case "harbor":
            terms.formUnion(["harbor", "registry", "镜像仓库", "imagepullsecrets", "镜像拉取"])
        case "jenkins":
            terms.formUnion(["jenkins", "流水线", "pipeline", "持续集成", "持续交付"])
        case "ci/cd":
            terms.formUnion(["ci/cd", "cicd", "流水线", "pipeline", "持续集成", "持续交付", "发布"])
        case "helm":
            terms.formUnion(["helm", "chart", "values.yaml"])
        case "prometheus":
            terms.formUnion(["prometheus", "promql", "告警", "指标"])
        case "grafana":
            terms.formUnion(["grafana", "仪表盘", "看板"])
        case "linux":
            terms.formUnion(["linux", "centos", "ubuntu", "rhel", "系统"])
        case "shell":
            terms.formUnion(["shell", "bash", "脚本"])
        default:
            break
        }
        return terms.filter { !$0.isEmpty }
    }

    private func categoryTerms(for category: TechStackCategory) -> [String] {
        switch category {
        case .ciCd:
            return ["ci/cd", "cicd", "流水线", "持续集成", "持续交付", "发布", "部署"]
        case .container:
            return ["docker", "容器", "镜像", "dockerfile"]
        case .orchestrator:
            return ["kubernetes", "k8s", "pod", "编排", "集群", "ingress"]
        case .registry:
            return ["harbor", "registry", "镜像仓库", "imagepullsecrets"]
        case .cloudNative:
            return ["云原生", "helm", "ceph", "rook", "operator"]
        case .automation:
            return ["自动化", "ansible", "terraform", "iac", "脚本"]
        case .operatingSystem:
            return ["linux", "系统", "shell", "bash", "内核"]
        case .database:
            return ["数据库", "mysql", "postgresql", "达梦", "sql"]
        case .middleware:
            return ["中间件", "nginx", "redis", "kafka", "rabbitmq"]
        case .monitoring:
            return ["监控", "告警", "prometheus", "grafana", "日志", "elk"]
        case .language:
            return ["java", "python", "swift", "语言"]
        case .mobile:
            return ["ios", "swiftui", "uikit", "app"]
        case .frontend:
            return ["前端", "react", "vue", "next.js"]
        case .backend:
            return ["后端", "spring", "api", "服务"]
        case .ai:
            return ["ai", "llm", "大模型", "rag", "agent"]
        case .other:
            return []
        }
    }
}
