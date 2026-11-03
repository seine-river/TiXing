import Foundation
#if canImport(BuglyPro)
import BuglyPro
#endif

final class BuglyProvider: ObservabilityProvider {
    let name = "Bugly"
    private let config: ObservabilityConfig
    private var activated = false

    init(config: ObservabilityConfig) {
        self.config = config
    }

    func activate() {
        guard !activated, config.buglyConfigured else { return }
        #if canImport(BuglyPro)
        let buglyConfig = BuglyConfig(appId: config.buglyAppID, appKey: config.buglyAppKey)
        // Bugly Pro 商业化环境；默认值指向腾讯内部环境，不能用于外部产品上报。
        buglyConfig.serverHostType = BuglyServerHostType(rawValue: 1)!
        buglyConfig.clientTag = StableDeviceID.value
        buglyConfig.userIdentifier = "tixing-family"
        buglyConfig.channel = config.umengChannel
        buglyConfig.setEnableCountryCode(false)
        buglyConfig.setEnableJailbreakStatus(false)
        #if DEBUG
        buglyConfig.buildConfig = BuglyBuildConfig(rawValue: 1)
        #else
        buglyConfig.buildConfig = BuglyBuildConfig(rawValue: 3)
        #endif
        let modules = [BUGLY_MODULE_CRASH, RM_MODULE_LOOPER, RM_MODULE_MEMORY,
                       RM_MODULE_LAUNCH, BUGLY_MODUEL_PAGE_LAUNCH, BUGLY_MODUEL_NETWORK]
        Bugly.start(modules, config: buglyConfig) { }
        #endif
        activated = true
    }

    func track(_ event: ObservabilityEvent) {
        // Bugly is a stability/performance sink. Business behavior events stay in Umeng.
    }

    func reportError(_ report: ObservabilityErrorReport) {
        guard activated else { return }
        #if canImport(BuglyPro)
        BuglyCrashMonitorPlugin.reportException(
            withCategory: 3,
            name: String(report.name.prefix(256)),
            reason: String(ObservabilitySanitizer.sanitizeValue(report.message).prefix(256)),
            callStack: [String(ObservabilitySanitizer.sanitizeValue(report.detail).prefix(5000))],
            extraInfo: [:],
            terminateApp: false
        )
        #endif
    }
}
