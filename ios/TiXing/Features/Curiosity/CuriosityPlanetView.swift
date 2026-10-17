import SwiftUI

struct CuriosityPlanetView: View {
    @EnvironmentObject private var store: AppStore
    @State private var busy = false
    @State private var errorText = ""

    private var stats: CuriosityStats { store.curiosityStats() }

    var body: some View {
        ScrollView {
            VStack(spacing: 13) {
                hero
                if !errorText.isEmpty { ErrorBanner(message: errorText) }
                if let latest = store.insights.first {
                    reportCard(latest)
                } else {
                    AppCard {
                        EmptyBlock(message: "点亮后，醒醒会把孩子的问题变成一份有趣的成长观察")
                    }
                }
                signals
                if store.insights.count > 1 {
                    history
                }
            }
            .padding(16)
            .padding(.bottom, 65)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("好奇星球")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Text("🪐")
                .font(.system(size: 54))
                .frame(width: 112, height: 112)
                .background(Color.white.opacity(0.16))
                .clipShape(Circle())
                .scaleEffect(busy ? 1.05 : 1)
                .animation(.spring(response: 0.7, dampingFraction: 0.5).repeatForever(autoreverses: true), value: busy)
            Text(busy ? "醒醒正在阅读问题…" : "点亮好奇星球")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.white)
            Text("已经收集 \(stats.total) 个问题 · 本周 +\(stats.weekCount)")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.86))
            Button {
                Task { await generate() }
            } label: {
                if busy { ProgressView().tint(.white) } else { Text("点亮好奇星球") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(busy || stats.total == 0)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 30).fill(Theme.heroGradient))
    }

    private func reportCard(_ insight: InterestInsight) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("孩子看到的星球")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.primary)
                Text(insight.childSummary)
                    .font(.system(size: 16))
                    .lineSpacing(6)
                Divider()
                Text("家长看到的观察")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                Text(insight.parentSummary)
                    .font(.system(size: 14))
                    .lineSpacing(5)
                if !insight.recommendedActivities.isEmpty {
                    Text("可以一起做")
                        .font(.system(size: 13, weight: .bold))
                    ForEach(insight.recommendedActivities, id: \.self) { activity in
                        Label(activity, systemImage: "leaf")
                            .font(.system(size: 13))
                    }
                }
                Text("生成于 \(insight.generatedAt.formatted(.dateTime.year().month().day())) · 覆盖 \(insight.questionCount) 个问题")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var signals: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("星球信号").font(.system(size: 16, weight: .bold))
                statRow("最爱领域", stats.subjects)
                statRow("高频主题", stats.topics)
                statRow("兴趣星标", stats.tags)
            }
        }
    }

    private var history: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 7) {
                Text("历史报告").font(.system(size: 16, weight: .bold))
                ForEach(store.insights.dropFirst()) { item in
                    HStack {
                        Text(item.generatedAt.formatted(.dateTime.year().month().day()))
                        Spacer()
                        Text("\(item.questionCount) 个问题")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .font(.system(size: 13))
                }
            }
        }
    }

    private func statRow(_ title: String, _ items: [CuriosityStats.CountItem]) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 68, alignment: .leading)
            Text(items.prefix(4).map { "\($0.key) \($0.count)" }.joined(separator: " · "))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
    }

    private func generate() async {
        busy = true
        errorText = ""
        do {
            let report = try await AIService.shared.curiosityReport(records: store.voiceAsks, grade: store.student.grade)
            store.insert(store.buildInsight(report: report))
        } catch {
            errorText = error.localizedDescription
        }
        busy = false
    }
}
