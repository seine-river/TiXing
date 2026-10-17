import SwiftUI

struct ReportView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 13) {
                hero
                stats
                subjectDistribution
                weakPoints
                knowledgeProfilesCard
                premiumBanner
            }
            .padding(16)
            .padding(.bottom, 70)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("学习报告")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var masteryRate: Double {
        let stats = store.mistakeStats
        guard stats.total > 0 else { return 0 }
        return Double(stats.mastered) / Double(stats.total)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("学习报告")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            Text("看看你的进步与薄弱点")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.86))
            HStack(alignment: .bottom) {
                Text("总掌握率")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("\(Int(masteryRate * 100))%")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)
            }
            ProgressView(value: masteryRate)
                .tint(.white)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 27).fill(Theme.heroGradient))
    }

    private var stats: some View {
        let values = store.mistakeStats
        return VStack(spacing: 9) {
            HStack(spacing: 9) {
                reportStat("📒", values.total, "总错题", Theme.softPrimary)
                reportStat("✅", values.mastered, "已掌握", Theme.softSecondary)
            }
            HStack(spacing: 9) {
                reportStat("🔁", values.reviewing, "复习中", Theme.softWarning)
                reportStat("⚠️", values.unmastered, "未掌握", Theme.softDanger)
            }
        }
    }

    private func reportStat(_ emoji: String, _ value: Int, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Text(emoji).font(.system(size: 25))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)").font(.system(size: 21, weight: .bold))
                Text(label).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(color))
    }

    private var subjectDistribution: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 9) {
                Text("学科分布").font(.system(size: 16, weight: .bold))
                ForEach(Subject.allCases) { subject in
                    let count = store.mistakes.filter { $0.subject == subject }.count
                    HStack {
                        Text("\(subject.emoji) \(subject.label)").font(.system(size: 13))
                        Spacer()
                        Text("\(count)题").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    }
                    let total = max(store.mistakes.count, 1)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.chip)
                            Capsule().fill(Theme.primary)
                                .frame(width: proxy.size.width * Double(count) / Double(total))
                        }
                    }.frame(height: 8)
                }
            }
        }
    }

    private var weakPoints: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("薄弱知识点 Top3").font(.system(size: 16, weight: .bold))
                let items = Array(Dictionary(grouping: store.mistakes, by: { $0.knowledgeSummary.isEmpty ? "未分类" : $0.knowledgeSummary })
                    .map { key, list in (key, list.count) }
                    .sorted { $0.1 > $1.1 }
                    .prefix(3))
                if items.isEmpty {
                    Text("录入错题后，这里会展示薄弱知识点")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Theme.primary))
                            Text(item.0)
                            Spacer()
                            Text("错题\(item.1)题")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var premiumBanner: some View {
        Text("💡 深度分析报告需要家长订阅解锁")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 6)
    }

    private var knowledgeProfilesCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("知识点画像").font(.system(size: 16, weight: .bold))
                if store.knowledgeProfiles.isEmpty {
                    Text("保存错题后会自动生成知识点掌握趋势")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(store.knowledgeProfiles.prefix(5)) { profile in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(profile.tag)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(Int(profile.masteryScore * 100))%")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.primary)
                            }
                            ProgressView(value: profile.masteryScore)
                                .tint(profile.masteryScore >= 0.7 ? Theme.secondary : Theme.primary)
                            Text("\(profile.masteredCount)/\(profile.totalMistakes) 已掌握 · \(trendLabel(profile.trend))")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func trendLabel(_ value: String) -> String {
        if value == "improving" { return "上升" }
        if value == "declining" { return "需加强" }
        return "稳定"
    }
}
