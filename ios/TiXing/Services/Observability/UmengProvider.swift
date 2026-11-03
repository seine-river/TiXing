import Foundation
#if canImport(UMCommon)
import UMCommon
#endif
#if canImport(UMAPM)
import UMAPM
#endif

final class UmengProvider: ObservabilityProvider {
    let name = "Umeng"
    private let config: ObservabilityConfig
    private var activated = false

    init(config: ObservabilityConfig) {
        self.config = config
    }

    func activate() {
        guard !activated else { return }
        #if canImport(UMCommon)
        UMConfigure.setLogEnabled(false)
        UMConfigure.initWithAppkey(config.umengAppKey, channel: config.umengChannel)
        #endif
        activated = true
    }

    func track(_ event: ObservabilityEvent) {
        guard activated else { return }
        #if canImport(UMCommon)
        MobClick.event(event.sanitizedID, attributes: event.sanitizedAttributes)
        #endif
    }

    func reportError(_ report: ObservabilityErrorReport) {
        guard activated else { return }
        track(ObservabilityEvent(kind: .fault, name: "provider_error", attributes: [
            "provider": name,
            "error_name": report.name,
            "success": "0"
        ]))
        #if canImport(UMAPM)
        UMCrashConfigure.reportException(
            withName: String(report.name.prefix(256)),
            reason: String(ObservabilitySanitizer.sanitizeValue(report.message).prefix(256)),
            stackTrace: [String(ObservabilitySanitizer.sanitizeValue(report.detail).prefix(5000))]
        )
        #endif
    }
}
