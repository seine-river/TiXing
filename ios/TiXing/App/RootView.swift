import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTab = 0
    @State private var showVoiceAsk = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0: NavigationStack { HomeView() }
                case 1: NavigationStack { MistakesView() }
                case 2: NavigationStack { ReportView() }
                default: NavigationStack { ProfileView() }
                }
            }
            .padding(.bottom, 68)

            tabBar
        }
        .background(Theme.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showVoiceAsk) {
            NavigationStack { VoiceAskView() }
                .environmentObject(store)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabItem(title: "首页", icon: "house.fill", index: 0)
            tabItem(title: "错题本", icon: "book.fill", index: 1)

            Button {
                showVoiceAsk = true
            } label: {
                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(red: 1, green: 0.82, blue: 0.4), Color(red: 1, green: 0.54, blue: 0.24), Color(red: 0.94, green: 0.32, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 58, height: 58)
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            .shadow(color: Color(red: 0.94, green: 0.32, blue: 0.18).opacity(0.35), radius: 12, y: 6)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(y: -12)
                    Text("问一问")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .offset(y: -8)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("问一问")

            tabItem(title: "报告", icon: "chart.bar.fill", index: 2)
            tabItem(title: "我的", icon: "person.fill", index: 3)
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Color.black.opacity(0.07)).frame(height: 0.5) }
    }

    private func tabItem(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 21))
                    .symbolVariant(.fill)
                    .foregroundStyle(selectedTab == index ? Theme.primary : Theme.textSecondary)
                Text(title)
                    .font(.system(size: 10.5, weight: selectedTab == index ? .bold : .medium))
                    .foregroundStyle(selectedTab == index ? Theme.primary : Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
    }
}
