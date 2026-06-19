import Foundation

struct ResumeAnalyzer {
    private struct Signal {
        let skill: String
        let aliases: [String]
        let roles: [InterviewRole]
        let weight: Double
        let category: TechStackCategory

        init(
            skill: String,
            aliases: [String],
            roles: [InterviewRole],
            weight: Double,
            category: TechStackCategory = .other
        ) {
            self.skill = skill
            self.aliases = aliases
            self.roles = roles
            self.weight = weight
            self.category = category
        }
    }

    private let signals: [Signal] = [
        Signal(skill: "Jenkins", aliases: ["jenkins"], roles: [.operations, .backendDeveloper], weight: 2.8, category: .ciCd),
        Signal(skill: "CI/CD", aliases: ["ci/cd", "cicd", "持续集成", "持续交付", "流水线", "pipeline"], roles: [.operations, .backendDeveloper], weight: 2.7, category: .ciCd),
        Signal(skill: "GitLab CI", aliases: ["gitlab ci", "gitlab-ci", ".gitlab-ci"], roles: [.operations, .backendDeveloper], weight: 2.3, category: .ciCd),
        Signal(skill: "GitHub Actions", aliases: ["github actions", "action workflow"], roles: [.operations, .backendDeveloper], weight: 2.0, category: .ciCd),
        Signal(skill: "Argo CD", aliases: ["argo cd", "argocd"], roles: [.operations], weight: 2.4, category: .ciCd),
        Signal(skill: "Docker", aliases: ["docker", "容器化", "dockerfile"], roles: [.operations, .backendDeveloper], weight: 2.7, category: .container),
        Signal(skill: "Kubernetes", aliases: ["kubernetes", "k8s", "kubelet", "kubectl"], roles: [.operations, .backendDeveloper], weight: 3.0, category: .orchestrator),
        Signal(skill: "OpenShift", aliases: ["openshift", "ocp"], roles: [.operations], weight: 2.5, category: .orchestrator),
        Signal(skill: "Harbor", aliases: ["harbor", "镜像仓库", "image registry"], roles: [.operations], weight: 2.6, category: .registry),
        Signal(skill: "Helm", aliases: ["helm", "chart"], roles: [.operations], weight: 2.1, category: .cloudNative),
        Signal(skill: "Nginx", aliases: ["nginx", "反向代理"], roles: [.operations, .backendDeveloper], weight: 2.0, category: .middleware),
        Signal(skill: "Ansible", aliases: ["ansible"], roles: [.operations], weight: 2.2, category: .automation),
        Signal(skill: "Terraform", aliases: ["terraform", "iac"], roles: [.operations], weight: 2.1, category: .automation),
        Signal(skill: "Linux", aliases: ["linux", "centos", "ubuntu", "redhat", "rhel"], roles: [.operations, .backendDeveloper], weight: 2.1, category: .operatingSystem),
        Signal(skill: "Shell", aliases: ["shell", "bash", "脚本"], roles: [.operations, .backendDeveloper], weight: 1.8, category: .operatingSystem),
        Signal(skill: "Prometheus", aliases: ["prometheus", "promql"], roles: [.operations], weight: 2.3, category: .monitoring),
        Signal(skill: "Grafana", aliases: ["grafana"], roles: [.operations], weight: 2.1, category: .monitoring),
        Signal(skill: "ELK", aliases: ["elk", "elasticsearch", "logstash", "kibana"], roles: [.operations, .backendDeveloper], weight: 2.0, category: .monitoring),
        Signal(skill: "Ceph", aliases: ["ceph", "rook"], roles: [.operations], weight: 2.4, category: .cloudNative),
        Signal(skill: "MySQL", aliases: ["mysql"], roles: [.backendDeveloper, .operations], weight: 1.9, category: .database),
        Signal(skill: "PostgreSQL", aliases: ["postgresql", "postgres"], roles: [.backendDeveloper, .operations], weight: 1.8, category: .database),
        Signal(skill: "Redis", aliases: ["redis"], roles: [.backendDeveloper, .operations], weight: 1.8, category: .middleware),
        Signal(skill: "Kafka", aliases: ["kafka"], roles: [.backendDeveloper, .operations], weight: 1.9, category: .middleware),
        Signal(skill: "RabbitMQ", aliases: ["rabbitmq", "rabbit mq"], roles: [.backendDeveloper, .operations], weight: 1.7, category: .middleware),
        Signal(skill: "达梦数据库", aliases: ["达梦", "dm8", "dameng"], roles: [.backendDeveloper, .operations], weight: 1.8, category: .database),
        Signal(skill: "Swift", aliases: ["swift"], roles: [.iosDeveloper], weight: 2.4, category: .language),
        Signal(skill: "SwiftUI", aliases: ["swiftui"], roles: [.iosDeveloper], weight: 2.6, category: .mobile),
        Signal(skill: "UIKit", aliases: ["uikit"], roles: [.iosDeveloper], weight: 2.2, category: .mobile),
        Signal(skill: "Combine", aliases: ["combine"], roles: [.iosDeveloper], weight: 1.8, category: .mobile),
        Signal(skill: "性能优化", aliases: ["性能优化", "performance", "启动优化", "卡顿", "崩溃率"], roles: [.iosDeveloper, .frontendDeveloper, .backendDeveloper], weight: 1.6, category: .other),
        Signal(skill: "App Store", aliases: ["app store", "testflight", "上架"], roles: [.iosDeveloper], weight: 1.5, category: .mobile),
        Signal(skill: "PRD", aliases: ["prd", "需求文档", "产品文档"], roles: [.productManager], weight: 2.3, category: .other),
        Signal(skill: "需求分析", aliases: ["需求分析", "需求调研", "用户访谈"], roles: [.productManager], weight: 2.0, category: .other),
        Signal(skill: "A/B Test", aliases: ["a/b", "ab test", "实验", "灰度实验"], roles: [.productManager, .operations], weight: 2.0, category: .other),
        Signal(skill: "数据分析", aliases: ["数据分析", "sql", "指标", "漏斗", "留存", "转化"], roles: [.productManager, .operations, .aiEngineer], weight: 1.7, category: .other),
        Signal(skill: "用户增长", aliases: ["用户增长", "增长", "拉新", "促活", "留存"], roles: [.productManager, .operations], weight: 1.9, category: .other),
        Signal(skill: "React", aliases: ["react", "next.js", "vue", "前端"], roles: [.frontendDeveloper], weight: 2.2, category: .frontend),
        Signal(skill: "Node.js", aliases: ["node", "node.js", "express", "nestjs"], roles: [.backendDeveloper, .frontendDeveloper], weight: 1.8, category: .backend),
        Signal(skill: "Java", aliases: ["java", "spring", "spring boot"], roles: [.backendDeveloper], weight: 2.1, category: .language),
        Signal(skill: "Python", aliases: ["python", "fastapi", "flask"], roles: [.backendDeveloper, .aiEngineer], weight: 1.9, category: .language),
        Signal(skill: "LLM", aliases: ["llm", "大模型", "rag", "prompt", "agent"], roles: [.aiEngineer], weight: 2.4, category: .ai),
        Signal(skill: "机器学习", aliases: ["机器学习", "深度学习", "pytorch", "tensorflow"], roles: [.aiEngineer], weight: 2.2, category: .ai),
        Signal(skill: "销售转化", aliases: ["销售", "客户", "商机", "crm", "成交"], roles: [.sales], weight: 2.0, category: .other)
    ]

    func analyze(text: String) -> ResumeProfile {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchable = cleaned.lowercased()
        var roleScores: [InterviewRole: Double] = [:]
        var foundSkills: [String: Double] = [:]
        var foundCategories: [String: TechStackCategory] = [:]
        var foundEvidence: [String: Set<String>] = [:]
        var projectKeywords: Set<String> = []

        for signal in signals {
            let matchedAliases = signal.aliases.filter { alias in
                searchable.contains(alias.lowercased())
            }
            let hitCount = matchedAliases.count

            guard hitCount > 0 else { continue }
            foundSkills[signal.skill, default: 0] += Double(hitCount) * signal.weight
            foundCategories[signal.skill] = signal.category
            foundEvidence[signal.skill, default: []].formUnion(matchedAliases)
            for role in signal.roles {
                roleScores[role, default: 0] += Double(hitCount) * signal.weight
            }
        }

        for keyword in ["支付", "推送", "会员", "留存", "转化", "架构", "推荐", "搜索", "订单", "客服", "增长"] {
            if cleaned.contains(keyword) {
                projectKeywords.insert(keyword)
            }
        }

        let matchedRoles = roleScores
            .sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }
            .prefix(3)
            .map(\.key)

        let rankedSkills = foundSkills
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        let skills = rankedSkills.map(\.key)
        let techStack = rankedSkills.map { item in
            TechStackEntity(
                name: item.key,
                category: foundCategories[item.key] ?? .other,
                confidence: min(0.98, max(0.55, item.value / 5.0)),
                evidence: Array(foundEvidence[item.key] ?? []).sorted()
            )
        }

        let primaryScore = roleScores.values.max() ?? 0
        let confidence = min(0.98, max(0.25, primaryScore / 10.0))
        let seniority = inferSeniority(from: cleaned)
        let headline = inferHeadline(from: cleaned, role: matchedRoles.first ?? .general)

        return ResumeProfile(
            candidateName: inferCandidateName(from: cleaned),
            headline: headline,
            matchedRoles: matchedRoles.isEmpty ? [.general] : Array(matchedRoles),
            skills: skills.isEmpty ? ["沟通表达", "项目复盘"] : skills,
            techStack: techStack,
            projectKeywords: Array(projectKeywords).sorted(),
            seniority: seniority,
            confidence: confidence,
            rawText: cleaned
        )
    }

    private func inferCandidateName(from text: String) -> String? {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { line in
                !line.isEmpty &&
                line.count <= 12 &&
                !line.localizedCaseInsensitiveContains("resume") &&
                !line.contains("简历") &&
                !line.contains("@")
            }
    }

    private func inferHeadline(from text: String, role: InterviewRole) -> String {
        let firstMeaningfulLine = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.count > 12 && !$0.contains("@") }

        return firstMeaningfulLine ?? "\(role.rawValue)候选人"
    }

    private func inferSeniority(from text: String) -> QuestionDifficulty {
        let lowercased = text.lowercased()
        if lowercased.contains("高级") || lowercased.contains("leader") || lowercased.contains("负责人") {
            return .senior
        }

        let patterns = ["(\\d+)\\s*年", "(\\d+)\\+?\\s*years?"]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(lowercased.startIndex..<lowercased.endIndex, in: lowercased)
            guard let match = regex.firstMatch(in: lowercased, range: range),
                  let valueRange = Range(match.range(at: 1), in: lowercased),
                  let years = Int(lowercased[valueRange])
            else { continue }

            if years >= 6 { return .senior }
            if years >= 2 { return .mid }
            return .junior
        }

        return .mid
    }
}

struct JobDescriptionAnalyzer {
    private struct Signal {
        let skill: String
        let aliases: [String]
        let roles: [InterviewRole]
        let weight: Double
    }

    private let signals: [Signal] = [
        Signal(skill: "Swift", aliases: ["swift"], roles: [.iosDeveloper], weight: 2.2),
        Signal(skill: "SwiftUI", aliases: ["swiftui"], roles: [.iosDeveloper], weight: 2.4),
        Signal(skill: "UIKit", aliases: ["uikit"], roles: [.iosDeveloper], weight: 2.0),
        Signal(skill: "Combine", aliases: ["combine"], roles: [.iosDeveloper], weight: 1.8),
        Signal(skill: "性能优化", aliases: ["性能优化", "启动优化", "卡顿", "崩溃", "performance"], roles: [.iosDeveloper, .frontendDeveloper, .backendDeveloper], weight: 1.7),
        Signal(skill: "PRD", aliases: ["prd", "产品文档", "需求文档"], roles: [.productManager], weight: 2.4),
        Signal(skill: "需求分析", aliases: ["需求分析", "需求调研", "用户调研", "竞品分析"], roles: [.productManager], weight: 2.1),
        Signal(skill: "数据分析", aliases: ["数据分析", "sql", "指标", "漏斗", "留存", "转化"], roles: [.productManager, .operations, .aiEngineer], weight: 1.9),
        Signal(skill: "项目管理", aliases: ["项目管理", "里程碑", "排期", "风险管理", "交付"], roles: [.productManager, .operations], weight: 1.8),
        Signal(skill: "实施交付", aliases: ["实施", "交付", "部署", "验收", "客户现场", "上线"], roles: [.operations], weight: 2.2),
        Signal(skill: "Linux", aliases: ["linux", "centos", "ubuntu", "shell"], roles: [.operations, .backendDeveloper], weight: 1.8),
        Signal(skill: "数据库", aliases: ["mysql", "postgresql", "oracle", "达梦", "数据库", "sql"], roles: [.backendDeveloper, .operations], weight: 1.8),
        Signal(skill: "Java", aliases: ["java", "spring", "spring boot"], roles: [.backendDeveloper], weight: 2.0),
        Signal(skill: "Python", aliases: ["python", "fastapi", "flask"], roles: [.backendDeveloper, .aiEngineer, .operations], weight: 1.8),
        Signal(skill: "React", aliases: ["react", "vue", "next.js", "前端"], roles: [.frontendDeveloper], weight: 2.0),
        Signal(skill: "LLM", aliases: ["llm", "大模型", "rag", "prompt", "agent"], roles: [.aiEngineer], weight: 2.2),
        Signal(skill: "销售转化", aliases: ["销售", "客户", "商机", "crm", "成交"], roles: [.sales], weight: 2.0)
    ]

    func analyze(text: String, resumeProfile: ResumeProfile?) -> JobDescriptionProfile {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchable = cleaned.lowercased()
        var roleScores: [InterviewRole: Double] = [:]
        var foundSkills: [String: Double] = [:]

        for signal in signals {
            let hitCount = signal.aliases.reduce(0) { count, alias in
                searchable.contains(alias.lowercased()) ? count + 1 : count
            }
            guard hitCount > 0 else { continue }
            foundSkills[signal.skill, default: 0] += Double(hitCount) * signal.weight
            for role in signal.roles {
                roleScores[role, default: 0] += Double(hitCount) * signal.weight
            }
        }

        let requiredSkills = foundSkills
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map(\.key)

        let matchedRoles = roleScores
            .sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }
            .prefix(3)
            .map(\.key)

        let resumeSkillSet = Set(((resumeProfile?.skills ?? []) + (resumeProfile?.techStack.map(\.name) ?? [])).map { $0.lowercased() })
        let gaps = requiredSkills.filter { !resumeSkillSet.contains($0.lowercased()) }
        let primaryScore = roleScores.values.max() ?? 0

        return JobDescriptionProfile(
            title: inferTitle(from: cleaned, role: matchedRoles.first ?? .general),
            matchedRoles: matchedRoles.isEmpty ? [.general] : Array(matchedRoles),
            requiredSkills: requiredSkills.isEmpty ? ["沟通表达", "项目复盘", "岗位匹配"] : requiredSkills,
            responsibilities: inferResponsibilities(from: cleaned),
            gapKeywords: gaps.isEmpty ? Array(requiredSkills.prefix(3)) : Array(gaps.prefix(8)),
            seniority: inferSeniority(from: cleaned),
            confidence: min(0.98, max(0.25, primaryScore / 10.0)),
            rawText: cleaned
        )
    }

    private func inferTitle(from text: String, role: InterviewRole) -> String {
        let titleHints = ["岗位", "职位", "招聘", "职责", "要求", "任职"]
        let firstLine = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { line in
                !line.isEmpty &&
                line.count <= 28 &&
                !titleHints.contains { line.contains($0) && line.count > 18 }
            }

        if let firstLine { return firstLine }
        return "\(role.rawValue)目标岗位"
    }

    private func inferResponsibilities(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
            .map { line in
                line.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n-•*0123456789.、"))
            }
            .filter { line in
                line.count >= 8 &&
                line.count <= 80 &&
                !line.localizedCaseInsensitiveContains("任职资格") &&
                !line.localizedCaseInsensitiveContains("岗位要求")
            }

        return Array(lines.prefix(5))
    }

    private func inferSeniority(from text: String) -> QuestionDifficulty {
        let lowercased = text.lowercased()
        if lowercased.contains("高级") || lowercased.contains("专家") || lowercased.contains("leader") || lowercased.contains("负责人") {
            return .senior
        }
        if lowercased.contains("实习") || lowercased.contains("应届") || lowercased.contains("初级") {
            return .junior
        }

        let patterns = ["(\\d+)\\s*年", "(\\d+)\\+?\\s*years?"]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(lowercased.startIndex..<lowercased.endIndex, in: lowercased)
            guard let match = regex.firstMatch(in: lowercased, range: range),
                  let valueRange = Range(match.range(at: 1), in: lowercased),
                  let years = Int(lowercased[valueRange])
            else { continue }

            if years >= 6 { return .senior }
            if years >= 2 { return .mid }
            return .junior
        }

        return .mid
    }
}
