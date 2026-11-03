import SwiftUI

/// Umeng U-APM 的页面/弹窗监控会读取 `UIApplicationDelegate.window`。
/// SwiftUI 生命周期默认的 internal AppDelegate 没有这个 Objective-C selector，
/// 打开 PhotosPicker 这类 window 级弹窗时会触发 NSInvalidArgumentException。
/// 这里保留一个只作为兼容入口的空 window，不改变 SwiftUI 的场景生命周期。
@objc final class AppDelegate: NSObject, UIApplicationDelegate {
    @objc var window: UIWindow?
}

@main
struct TiXingApp: App {
    static let launchStartedAt = Date()
    @StateObject private var store = AppStore()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        ObservabilityService.shared.prepare()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.primary)
                .preferredColorScheme(.light)
        }
    }
}
