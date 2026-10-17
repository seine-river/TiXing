import SwiftUI

struct OpsOverviewView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SectionTitle(title: "本地聚合统计（脱敏）")
                metricCard("累计录入错题数", "\(store.mistakeStats.total)")
                metricCard("已掌握数", "\(store.mistakeStats.mastered)")
                metricCard("掌握判定通过率", "\(masteryRate)%" )
                metricCard("累计复习次数", "\(store.storage.reviewLogs.count)")
                metricCard("复习正确率", "\(reviewAccuracy)%")
                Text("注：完整运营 BI 后台为独立 Web 产品，此处为端侧本地聚合的脱敏指标预览。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("家长中心")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var masteryRate: Int {
        let stats = store.mistakeStats
        guard stats.total > 0 else { return 0 }
        return Int(Double(stats.mastered) / Double(stats.total) * 100)
    }

    private var reviewAccuracy: Int {
        guard !store.storage.reviewLogs.isEmpty else { return 0 }
        let correct = store.storage.reviewLogs.filter(\.correct).count
        return Int(Double(correct) / Double(store.storage.reviewLogs.count) * 100)
    }

    private func metricCard(_ title: String, _ value: String) -> some View {
        AppCard {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textRegular)
                Spacer()
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.primary)
            }
        }
    }
}
