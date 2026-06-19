import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Binding var selectedTab: Int

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("复盘")
                        .font(.system(size: 34, weight: .semibold))
                        .padding(.top, 12)

                    // Overview Card
                    SurfacePanel {
                        HStack(spacing: 16) {
                            ScoreRing(score: viewModel.reviewStore.averageScore)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("平均得分")
                                    .font(.system(size: 22, weight: .semibold))
                                let total = viewModel.reviewStore.attempts.count
                                Text(total == 0 ? "完成一次评分后显示进步趋势" : "已完成 \(total) 次回答评分")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }

                    // Stats Row
                    HStack(spacing: 8) {
                        MetricPill(icon: "checkmark.seal", title: "已掌握", value: "\(viewModel.reviewStore.masteredCount)")
                        MetricPill(icon: "book", title: "学习中", value: "\(viewModel.reviewStore.learningCount)")
                        MetricPill(icon: "flame", title: "连续天数", value: "\(viewModel.reviewStore.streakDays)")
                    }

                    weaknessFocusCard

                    // Tab Selector
                    Picker("", selection: $viewModel.selectedReviewSection) {
                        Text("练习历史").tag(0)
                        Text("错题本").tag(1)
                        Text("复习计划").tag(2)
                        Text("面试报告").tag(3)
                    }
                    .pickerStyle(.segmented)

                    switch viewModel.selectedReviewSection {
                    case 0: practiceHistory
                    case 1: wrongAnswerBook
                    case 2: reviewPlan
                    case 3: sessionReports
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Weakness Focus

    private var weaknessFocusCard: some View {
        let weaknesses = viewModel.reviewStore.weaknessSummary()
        let wrongCount = viewModel.wrongQuestionCount

        return SurfacePanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "scope")
                        .foregroundStyle(.orange)
                    Text("强化重点")
                        .font(.system(size: 20, weight: .semibold))
                    Spacer()
                    Text(weaknesses.isEmpty ? "待生成" : "\(weaknesses.count) 项")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }

                if weaknesses.isEmpty {
                    Text("完成 AI 教练或复述评分后，这里会自动汇总你最常缺的结构、证据、量化和风险表达。")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(weaknesses.enumerated()), id: \.offset) { index, item in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Color.orange, in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.text)
                                        .font(.system(size: 15, weight: .medium))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("出现 \(item.count) 次")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }

                Button {
                    if wrongCount > 0 {
                        viewModel.startPracticeForMode(.wrong)
                    } else {
                        viewModel.startPracticeForMode(.drill)
                    }
                    selectedTab = 2
                } label: {
                    Label(wrongCount > 0 ? "按错题强化" : "开始今日强化", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Practice History

    @ViewBuilder
    private var practiceHistory: some View {
        if viewModel.evaluations.isEmpty && viewModel.reviewStore.attempts.isEmpty {
            emptyCard(icon: "chart.line.uptrend.xyaxis", title: "还没有练习记录", subtitle: "去模拟面试里回答一题，AI 会保存评分和建议。")
        } else {
            ForEach(viewModel.evaluations) { evaluation in
                SurfacePanel {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("\(evaluation.overallScore) 分")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.blue)
                            Spacer()
                            Text(evaluation.createdAt, style: .time)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        Text(evaluation.questionPrompt)
                            .font(.system(size: 16, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)

                        Text(evaluation.improvements.prefix(2).joined(separator: "\n"))
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !viewModel.reviewStore.attempts.isEmpty {
                Text("历史记录")
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.top, 8)
                ForEach(viewModel.reviewStore.attempts.suffix(20).reversed()) { attempt in
                    SurfacePanel {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(attempt.prompt)
                                    .font(.system(size: 15, weight: .medium))
                                    .lineLimit(1)
                                HStack(spacing: 8) {
                                    Text(attempt.category)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    Text(attempt.date, style: .date)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(attempt.score)")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(attempt.score >= 75 ? .blue : .orange)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Wrong Answer Book

    @ViewBuilder
    private var wrongAnswerBook: some View {
        let wrongQuestions = viewModel.wrongReviewQuestions
        if wrongQuestions.isEmpty {
            emptyCard(icon: "checkmark.circle", title: "没有错题", subtitle: "所有练习过的题目都得分 75 分以上。")
        } else {
            Text("\(wrongQuestions.count) 道题需要巩固")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            ForEach(wrongQuestions) { question in
                SurfacePanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(question.prompt)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(2)
                        HStack {
                            MasteryBadge(text: viewModel.reviewStore.statusText(for: question))
                            Spacer()
                            Button {
                                viewModel.startPractice(with: [question])
                                selectedTab = 2
                            } label: {
                                Label("重做", systemImage: "arrow.counterclockwise")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Review Plan

    @ViewBuilder
    private var reviewPlan: some View {
        let dueQuestions = viewModel.dueReviewQuestions
        if dueQuestions.isEmpty {
            emptyCard(icon: "calendar.badge.checkmark", title: "没有待复习题", subtitle: "间隔重复系统会自动安排复习时间。")
        } else {
            Text("\(dueQuestions.count) 道题已到复习时间")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            Button {
                viewModel.startPractice(with: dueQuestions)
                selectedTab = 2
            } label: {
                Label("开始复习全部", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)

            ForEach(dueQuestions) { question in
                QuestionRow(question: question, reviewStore: viewModel.reviewStore)
            }
        }
    }

    // MARK: - Session Reports

    @ViewBuilder
    private var sessionReports: some View {
        if viewModel.reviewStore.sessionReports.isEmpty {
            emptyCard(icon: "doc.text.magnifyingglass", title: "还没有面试报告", subtitle: "从首页点击“开始模拟面试”，结束后会自动生成整场报告。")
        } else {
            ForEach(viewModel.reviewStore.sessionReports) { report in
                let hasUnscoredQuestions = report.scoredCount < report.questionCount
                SurfacePanel {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(report.title)
                                    .font(.system(size: 20, weight: .semibold))
                                Text(report.endedAt, style: .date)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(report.averageScore.map { "\($0) 分" } ?? "待评分")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.blue)
                        }

                        HStack(spacing: 8) {
                            reportMetric(title: "完成", value: "\(report.answeredCount)/\(report.questionCount)", icon: "text.bubble")
                            reportMetric(title: "AI评分", value: "\(report.scoredCount)", icon: "checkmark.seal")
                            reportMetric(title: "用时", value: MockSessionReport.durationText(report.durationSeconds), icon: "clock")
                        }

                        if !report.weakPoints.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("需要强化")
                                    .font(.system(size: 15, weight: .semibold))
                                FlowLayout(spacing: 8) {
                                    ForEach(report.weakPoints.prefix(6), id: \.self) { point in
                                        Text(point)
                                            .font(.system(size: 13, weight: .medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.orange.opacity(0.1), in: Capsule())
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("下一步")
                                .font(.system(size: 15, weight: .semibold))
                            ForEach(report.nextActions.prefix(3), id: \.self) { action in
                                Label(action, systemImage: "arrow.right.circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if !report.questionSummaries.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("逐题摘要")
                                    .font(.system(size: 15, weight: .semibold))
                                ForEach(report.questionSummaries.prefix(3)) { item in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(item.score.map { "\($0)" } ?? "-")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .frame(width: 28, height: 24)
                                            .background(item.score == nil ? Color.secondary : Color.blue, in: Capsule())
                                        Text(item.prompt)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }

                        HStack(spacing: 10) {
                            ShareLink(item: report.shareText) {
                                Label("导出报告", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                viewModel.startReportFollowUp(report)
                                selectedTab = 2
                            } label: {
                                Label(
                                    hasUnscoredQuestions ? "补齐未评分" : "重练本场",
                                    systemImage: hasUnscoredQuestions ? "checklist" : "arrow.counterclockwise"
                                )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Button {
                            viewModel.startMockInterview()
                            selectedTab = 2
                        } label: {
                            Label("新一轮模拟面试", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func reportMetric(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.blue)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func emptyCard(icon: String, title: String, subtitle: String) -> some View {
        SurfacePanel {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
