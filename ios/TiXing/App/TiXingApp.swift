import SwiftUI

@main
struct TiXingApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.primary)
                .preferredColorScheme(.light)
        }
    }
}
