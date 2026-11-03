import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTab = 0
    @State private var showVoiceAsk = false
    @State private var showObservabilityConsent = false
    @State private var hasTrackedLaunch = false

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
        .overlay {
            if showObservabilityConsent {
                observabilityConsentCard
            }
        }
        .onAppear {
            showObservabilityConsent = ObservabilityService.shared.consent == .unknown
            guard !hasTrackedLaunch else { return }
            hasTrackedLaunch = true
            ObservabilityService.shared.trackDuration(
                "app_first_frame",
                milliseconds: Int(Date().timeIntervalSince(TiXingApp.launchStartedAt) * 1000)
            )
        }
        .task {
            // SwiftUI task 可能在首帧提交前执行；延迟一拍确保首页先可见。
            try? await Task.sleep(nanoseconds: 100_000_000)
            store.loadDeferredDataIfNeeded()
        }
        .fullScreenCover(isPresented: $showVoiceAsk) {
            NavigationStack { VoiceAskView() }
                .environmentObject(store)
        }
    }

    private var observabilityConsentCard: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("🛡️")
                    .font(.system(size: 38))
                Text("帮助题醒变得更稳定")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("我们会匿名统计启动、页面、性能和崩溃信息。不会上传题目照片、语音内容、答案、姓名或联系方式。")
                    .font(.system(size: 13.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .foregroundStyle(Theme.textSecondary)
                Button {
                    showObservabilityConsent = false
                    ObservabilityService.shared.setConsent(.granted)
                } label: {
                    Text("同意并帮助改进")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Capsule().fill(Theme.primary))
                }
                .buttonStyle(.plain)
                Button {
                    showObservabilityConsent = false
                    ObservabilityService.shared.setConsent(.denied)
                } label: {
                    Text("暂不")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Capsule().fill(Theme.primary.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 24).fill(.white).shadow(color: .black.opacity(0.14), radius: 24, y: 10))
            .padding(.horizontal, 38)
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
