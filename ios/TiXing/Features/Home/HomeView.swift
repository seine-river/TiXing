import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showCapture = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                statGrid
                Button {
                    showCapture = true
                } label: {
                    Label("AI 录入错题", systemImage: "camera.viewfinder")
                }
                .buttonStyle(PrimaryButtonStyle())

                recent
            }
            .padding(16)
            .padding(.bottom, 10)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("题醒")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCapture) {
            NavigationStack { CaptureFlowView() }
                .environmentObject(store)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(greeting)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(.white)
                    Text(todayText)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.88))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("⭐ \(store.totalPoints)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("积分")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.todayReviewQueue.count)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                    Text(store.todayReviewQueue.isEmpty ? "今日复习已完成" : "题待复习")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Text("🦉")
                    .font(.system(size: 58))
                    .frame(width: 84, height: 84)
                    .background(Color.white.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 26))
            }

            if !store.todayReviewQueue.isEmpty {
                NavigationLink {
                    ReviewView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.white.opacity(0.22)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("开始复习")
                                .font(.system(size: 18, weight: .bold))
                            Text("\(store.todayReviewQueue.count) 道题已经准备好")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.88))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.18)))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .frame(height: 66)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.00, green: 0.82, blue: 0.40),
                                        Color(red: 1.00, green: 0.47, blue: 0.21),
                                        Color(red: 0.93, green: 0.27, blue: 0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 0.93, green: 0.27, blue: 0.15).opacity(0.28), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("开始复习今日错题")
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 28).fill(Theme.heroGradient))
        .shadow(color: Theme.primary.opacity(0.25), radius: 16, y: 8)
    }

    private var statGrid: some View {
        let stats = store.mistakeStats
        return HStack(spacing: 10) {
            statCard(emoji: "📒", value: stats.total, label: "总错题", color: Theme.softPrimary)
            statCard(emoji: "✅", value: stats.mastered, label: "已掌握", color: Theme.softSecondary)
            statCard(emoji: "🔁", value: stats.reviewing, label: "复习中", color: Theme.softWarning)
        }
    }

    private func statCard(emoji: String, value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(emoji).font(.system(size: 24))
            Text("\(value)")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18).fill(color))
    }

    private var recent: some View {
        VStack(spacing: 8) {
            SectionTitle(title: "最近错题")
            if store.mistakes.isEmpty {
                AppCard {
                    EmptyBlock(message: "还没有错题，点击上方按钮录入吧")
                }
            } else {
                ForEach(store.mistakes.prefix(3)) { mistake in
                    NavigationLink {
                        MistakeDetailView(mistakeID: mistake.id)
                    } label: {
                        MistakeRow(mistake: mistake)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 11 { return "上午好，\(store.student.nickname)" }
        if hour < 18 { return "下午好，\(store.student.nickname)" }
        return "晚上好，\(store.student.nickname)"
    }

    private var todayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-CN")
        formatter.dateFormat = "M月d日 · EEEE"
        return formatter.string(from: Date())
    }
}
