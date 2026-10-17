import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                hero
                curiosityCard
                menuCard
            }
            .padding(16)
            .padding(.bottom, 72)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.student.nickname)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(store.student.grade.label) · \(store.student.textbookVersion.label)")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.86))
                }
                Spacer()
                Text("⭐")
                    .font(.system(size: 28))
            }
            HStack(spacing: 9) {
                profileStat("\(store.totalPoints)", "积分")
                profileStat("\(store.todayPoints)", "今日")
                profileStat("\(store.streakDays)", "连击")
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 28).fill(Theme.heroGradient))
    }

    private func profileStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity)
    }

    private var curiosityCard: some View {
        NavigationLink {
            CuriosityPlanetView()
        } label: {
            HStack(spacing: 12) {
                Text("🪐")
                    .font(.system(size: 30))
                    .frame(width: 60, height: 60)
                    .background(Theme.softPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                VStack(alignment: .leading, spacing: 3) {
                    Text("好奇星球")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text("已经收集 \(store.voiceAsks.count) 个问题，点亮看看孩子最爱问什么")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(15)
            .background(RoundedRectangle(cornerRadius: 24).fill(Theme.buttonGradient))
        }
        .buttonStyle(.plain)
    }

    private var menuCard: some View {
        AppCard {
            VStack(spacing: 0) {
                menuRow("📚", "学习档案", destination: ProfileSettingView())
                Divider().padding(.leading, 52)
                menuRow("⏰", "复习提醒设置", destination: ReminderSettingView())
                Divider().padding(.leading, 52)
                menuRow("🎁", "积分中心", destination: PointsCenterView())
                Divider().padding(.leading, 52)
                menuRow("🎤", "我的问一问", destination: VoiceAskListView())
                Divider().padding(.leading, 52)
                menuRow("🔄", "导出与导入", destination: DataManagementView())
                Divider().padding(.leading, 52)
                menuRow("👨‍👩‍👧", "家长中心", destination: OpsOverviewView())
                Divider().padding(.leading, 52)
                menuRow("ℹ️", "关于题醒", destination: AboutView())
            }
        }
    }

    private func menuRow<Destination: View>(_ icon: String, _ title: String,
                                            destination: @autoclosure @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 18))
                    .frame(width: 38, height: 38)
                    .background(Theme.softPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }
}
