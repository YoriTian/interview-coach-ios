import SwiftUI
import UIKit

struct Components_Previews: PreviewProvider {
    static var previews: some View { EmptyView() }
}

enum KeyboardDismissal {
    @MainActor
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - Question Row

struct QuestionRow: View {
    let question: InterviewQuestion
    var reviewStore: ReviewStore?

    var body: some View {
        SurfacePanel {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: question.role.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(question.role.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.blue)
                        Spacer()
                        if let reviewStore {
                            MasteryBadge(text: reviewStore.statusText(for: question))
                        } else {
                            Text(question.difficulty.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                        }
                    }

                    Text(question.prompt)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
            }
        }
    }
}

// MARK: - Brand Header

struct BrandHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image("LogoMark")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 32, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 12)
    }
}

// MARK: - Surface Panel

struct SurfacePanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.primary.opacity(0.06), lineWidth: 1)
            }
    }
}

// MARK: - Metric Pill

struct MetricPill: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Score Ring

struct ScoreRing: View {
    let score: Int
    var size: CGFloat = 78

    var body: some View {
        ZStack {
            Circle()
                .stroke(scoreColor.opacity(0.14), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(min(score, 100)) / 100)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: score)
            Text("\(score)")
                .font(.system(size: size * 0.28, weight: .semibold))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("评分 \(score) 分")
    }

    private var scoreColor: Color {
        if score >= 85 { return .green }
        if score >= 70 { return .blue }
        if score >= 45 { return .orange }
        return .red
    }
}

// MARK: - Primary Action Button

struct PrimaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

// MARK: - Role Badge

struct RoleBadge: View {
    let role: InterviewRole

    var body: some View {
        Label(role.rawValue, systemImage: role.symbolName)
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.blue.opacity(0.1), in: Capsule())
            .foregroundStyle(.blue)
    }
}

// MARK: - Mastery Badge

struct MasteryBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.12), in: Capsule())
            .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        if text.contains("已掌握") { return .green }
        if text.contains("学习中") { return .orange }
        return .secondary
    }
}

// MARK: - Streak Badge

struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: days > 0 ? "flame.fill" : "flame")
                .foregroundStyle(days > 0 ? .orange : .secondary)
            Text("\(days) 天")
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(days > 0 ? 0.1 : 0.05), in: Capsule())
    }
}

// MARK: - Expression Metrics Panel

struct ExpressionMetricsPanel: View {
    let metrics: ExpressionMetrics

    var body: some View {
        HStack(spacing: 0) {
            metricItem(icon: "character.cursor.ibeam", title: "字数", value: "\(metrics.characterCount)")
            Divider().frame(height: 30)
            metricItem(icon: "clock", title: "时长", value: "\(metrics.durationSeconds)s")
            Divider().frame(height: 30)
            metricItem(icon: "waveform", title: "语速", value: metrics.speakingRate > 0 ? "\(Int(metrics.speakingRate))字/分" : "-")
            Divider().frame(height: 30)
            metricItem(icon: "exclamationmark.bubble", title: "填充词", value: "\(metrics.fillerWordCount)")
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func metricItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.blue)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Coaching Result Card

struct CoachingResultCard: View {
    let coaching: CoachingResult

    var body: some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "graduationcap.fill")
                        .foregroundStyle(.purple)
                    Text("AI 教练")
                        .font(.system(size: 22, weight: .semibold))
                    Spacer()
                    Text("\(coaching.scoreResult.score) 分")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                }

                if !coaching.scoreResult.summary.isEmpty {
                    Text(coaching.scoreResult.summary)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !coaching.scoreResult.misses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("必须强化")
                            .font(.system(size: 17, weight: .semibold))
                        ForEach(coaching.scoreResult.misses.prefix(4), id: \.self) { item in
                            Label(item, systemImage: "exclamationmark.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("目标答案")
                        .font(.system(size: 17, weight: .semibold))
                    Text(coaching.targetAnswer)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("答题框架")
                        .font(.system(size: 17, weight: .semibold))
                    ForEach(Array(coaching.answerFramework.enumerated()), id: \.offset) { idx, step in
                        Label("\(idx + 1). \(step)", systemImage: "arrow.right.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }

                if !coaching.keyPhrases.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("关键短句")
                            .font(.system(size: 17, weight: .semibold))
                        FlowLayout(spacing: 8) {
                            ForEach(coaching.keyPhrases, id: \.self) { phrase in
                                Text(phrase)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.1), in: Capsule())
                                    .foregroundStyle(.purple)
                            }
                        }
                    }
                }

                if !coaching.rehearsalChecklist.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("复述自查")
                            .font(.system(size: 17, weight: .semibold))
                        ForEach(coaching.rehearsalChecklist, id: \.self) { item in
                            Label(item, systemImage: "checkmark.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if !coaching.memorizationTips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("记忆技巧")
                            .font(.system(size: 17, weight: .semibold))
                        ForEach(coaching.memorizationTips, id: \.self) { tip in
                            Label(tip, systemImage: "lightbulb")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if !coaching.scoreResult.followUps.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("可能追问")
                            .font(.system(size: 17, weight: .semibold))
                        ForEach(coaching.scoreResult.followUps.prefix(4), id: \.self) { item in
                            Label(item, systemImage: "bubble.left")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Recitation Panel

struct RecitationPanel: View {
    let result: RecitationResult

    var body: some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "mouth.fill")
                        .foregroundStyle(.green)
                    Text("背诵评估")
                        .font(.system(size: 22, weight: .semibold))
                    Spacer()
                    ScoreRing(score: result.score, size: 56)
                }

                HStack(spacing: 12) {
                    miniScore(title: "覆盖", score: result.coverage)
                    miniScore(title: "清晰", score: result.clarity)
                    miniScore(title: "流畅", score: result.fluency)
                    miniScore(title: "自信", score: result.confidence)
                }

                Text(result.summary)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !result.improvements.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("下次改进")
                            .font(.system(size: 15, weight: .semibold))
                        ForEach(result.improvements, id: \.self) { item in
                            Label(item, systemImage: "arrow.up.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !result.correctedVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("下一遍怎么说")
                            .font(.system(size: 15, weight: .semibold))
                        Text(result.correctedVersion)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func miniScore(title: String, score: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(score)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Flow Layout (for tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalSize: CGSize = .zero

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalSize.width = max(totalSize.width, x - spacing)
            totalSize.height = max(totalSize.height, y + rowHeight)
        }
        return (positions, totalSize)
    }
}

// MARK: - Practice Mode Selector

struct PracticeModeSelector: View {
    @Binding var selection: PracticeMode
    let countProvider: (PracticeMode) -> Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PracticeMode.allCases) { mode in
                    Button {
                        selection = mode
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.systemImage)
                                .font(.system(size: 20, weight: .semibold))
                            Text(mode.title)
                                .font(.system(size: 12, weight: .medium))
                            Text("\(countProvider(mode))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 72, height: 78)
                        .background(
                            selection == mode ? Color.blue : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .foregroundStyle(selection == mode ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Script Toggle

struct ScriptToggle: View {
    @Binding var selectedScript: Int

    var body: some View {
        Picker("话术", selection: $selectedScript) {
            Text("30秒").tag(0)
            Text("90秒").tag(1)
            Text("深度").tag(2)
        }
        .pickerStyle(.segmented)
    }
}
