import XCTest
@testable import InterviewCoach

final class ResumeAnalyzerTests: XCTestCase {
    func testAnalyzesIOSResumeIntoRoleAndSkills() {
        let text = """
        张三
        iOS Developer with 4 years experience.
        熟悉 Swift、SwiftUI、UIKit、Combine，负责 App 架构、性能优化和 App Store 发布。
        项目：电商 iOS App，完成支付流程、推送通知、崩溃率治理。
        """

        let profile = ResumeAnalyzer().analyze(text: text)

        XCTAssertEqual(profile.candidateName, "张三")
        XCTAssertEqual(profile.primaryRole, .iosDeveloper)
        XCTAssertTrue(profile.skills.contains("SwiftUI"))
        XCTAssertTrue(profile.skills.contains("UIKit"))
        XCTAssertEqual(profile.seniority, .mid)
        XCTAssertGreaterThan(profile.confidence, 0.55)
    }

    func testAnalyzesProductManagerResumeIntoProductRole() {
        let text = """
        李四
        高级产品经理，6年经验，负责用户增长、需求分析、PRD、A/B Test、数据分析和跨部门协作。
        主导会员转化项目，提升留存和付费率。
        """

        let profile = ResumeAnalyzer().analyze(text: text)

        XCTAssertEqual(profile.primaryRole, .productManager)
        XCTAssertTrue(profile.skills.contains("PRD"))
        XCTAssertTrue(profile.skills.contains("A/B Test"))
        XCTAssertEqual(profile.seniority, .senior)
    }

    func testAnalyzesOperationsResumeIntoTechStackEntities() {
        let text = """
        匿名候选人
        高级运维工程师，5年经验。
        熟悉 Jenkins、CI/CD、Docker、K8S、Kubernetes、Harbor、Helm、Linux、Shell、Prometheus、Grafana。
        负责容器平台、镜像仓库、流水线、监控告警和上线验收。
        """

        let profile = ResumeAnalyzer().analyze(text: text)
        let entities = Dictionary(uniqueKeysWithValues: profile.techStack.map { ($0.name, $0) })

        XCTAssertEqual(profile.primaryRole, .operations)
        XCTAssertEqual(entities["Jenkins"]?.category, .ciCd)
        XCTAssertEqual(entities["Docker"]?.category, .container)
        XCTAssertEqual(entities["Kubernetes"]?.category, .orchestrator)
        XCTAssertEqual(entities["Harbor"]?.category, .registry)
        XCTAssertTrue(profile.skills.contains("CI/CD"))
        XCTAssertGreaterThan(profile.techStack.count, 6)
    }

    func testAnalyzesJobDescriptionAndFindsResumeGaps() {
        let resume = ResumeProfile(
            candidateName: "张三",
            headline: "iOS Developer",
            matchedRoles: [.iosDeveloper],
            skills: ["Swift", "UIKit"],
            projectKeywords: ["支付"],
            seniority: .mid,
            confidence: 0.8,
            rawText: "Swift UIKit 支付"
        )
        let text = """
        iOS 开发工程师
        岗位职责：负责 SwiftUI 页面开发、性能优化、埋点数据分析和 App Store 上架。
        任职要求：3 年以上 iOS 开发经验，熟悉 Swift、SwiftUI、UIKit、Combine 和 Instruments。
        """

        let profile = JobDescriptionAnalyzer().analyze(text: text, resumeProfile: resume)

        XCTAssertEqual(profile.primaryRole, .iosDeveloper)
        XCTAssertTrue(profile.requiredSkills.contains("SwiftUI"))
        XCTAssertTrue(profile.requiredSkills.contains("Combine"))
        XCTAssertTrue(profile.gapKeywords.contains("SwiftUI"))
        XCTAssertFalse(profile.gapKeywords.contains("Swift"))
        XCTAssertEqual(profile.seniority, .mid)
    }
}
