import SwiftUI

struct PointsCenterView: View {
    @EnvironmentObject private var store: AppStore

    private let items: [RedeemableItem] = [
        RedeemableItem(id: "cat", emoji: "🐱", name: "猫咪头像", category: "头像", cost: 30),
        RedeemableItem(id: "rocket", emoji: "🚀", name: "火箭头像", category: "头像", cost: 50),
        RedeemableItem(id: "cover", emoji: "🟦", name: "蓝色封面", category: "封面", cost: 40),
        RedeemableItem(id: "master", emoji: "🏆", name: "错题大师称号", category: "称号", cost: 80),
        RedeemableItem(id: "tree", emoji: "🌳", name: "橡树成长树", category: "成长树", cost: 60)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                hero
                SectionTitle(title: "积分兑换")
                ForEach(items) { item in
                    itemRow(item)
                }
                SectionTitle(title: "积分明细")
                ForEach(store.pointsLogs.prefix(30)) { log in
                    AppCard {
                        HStack {
                            Text(label(for: log.action))
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("+\(log.points)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                }
                Text("积分仅可兑换应用内虚拟内容，不可充值购买")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("积分中心")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(spacing: 0) {
            Text("\(store.totalPoints)")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(.white)
            Text("可用积分")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.86))
            HStack(spacing: 18) {
                smallStat("+\(store.todayPoints)", "今日获得")
                smallStat("\(store.streakDays)", "连续学习(天)")
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(RoundedRectangle(cornerRadius: 28).fill(Theme.heroGradient))
    }

    private func smallStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private func itemRow(_ item: RedeemableItem) -> some View {
        AppCard {
            HStack(spacing: 11) {
                Text(item.emoji)
                    .font(.system(size: 27))
                    .frame(width: 52, height: 52)
                    .background(Theme.softPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.system(size: 15, weight: .semibold))
                    Text(item.category).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button(store.isRedeemed(item) ? "已兑换" : "\(item.cost)积分") {
                    _ = store.redeem(item)
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(store.isRedeemed(item) ? Theme.textSecondary : Theme.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule().fill(store.isRedeemed(item) ? Theme.chip : Theme.softPrimary))
                .disabled(store.isRedeemed(item) || store.totalPoints < item.cost)
            }
        }
    }

    private func label(for action: PointsAction) -> String {
        switch action {
        case .capture: return "录入错题"
        case .onTimeReview: return "按时复习"
        case .masteryAchieved: return "掌握判定通过"
        case .streak: return "连续打卡"
        case .communityContribution: return "社区贡献"
        }
    }
}
