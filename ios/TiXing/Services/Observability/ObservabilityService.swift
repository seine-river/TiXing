import Foundation
import OSLog

enum ObservabilityConsent: String {
    case unknown
    case granted
    case denied
}

final class ObservabilityService {
    static let shared = ObservabilityService()
    private static let consentKey = "tixing.observability.consent"

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.tixing.me.ios", category: "Observability")
    private var providers: [ObservabilityProvider]
    private var config: ObservabilityConfig
    private var prepared = false

    private(set) var consent: ObservabilityConsent = .unknown

    init(defaults: UserDefaults = .standard,
         config: ObservabilityConfig = ObservabilityConfig.load(),
         providers: [ObservabilityProvider]? = nil) {
        self.defaults = defaults
        self.config = config
        self.providers = providers ?? [
            BuglyProvider(config: config),
            UmengProvider(config: config)
        ]
        if let raw = defaults.string(forKey: Self.consentKey),
           let saved = ObservabilityConsent(rawValue: raw) {
            consent = saved
        }
    }

    func prepare() {
        guard !prepared else { return }
        prepared = true
        if consent == .granted {
            activateProviders()
        }
    }

    func setConsent(_ next: ObservabilityConsent) {
        consent = next
        defaults.set(next.rawValue, forKey: Self.consentKey)
        guard next == .granted else { return }
        activateProviders()
        track(kind: .behavior, name: "telemetry_consent", attributes: ["granted": "1"])
    }

    func track(kind: ObservabilityEventKind, name: String, attributes: [String: String] = [:]) {
        prepare()
        guard consent == .granted else { return }
        let event = ObservabilityEvent(kind: kind, name: name, attributes: attributes)
        providers.forEach { $0.track(event) }
        logger.debug("observability event \(event.sanitizedID, privacy: .public)")
    }

    func trackDuration(_ name: String, milliseconds: Int, attributes: [String: String] = [:]) {
        var merged = attributes
        merged["duration_ms"] = String(milliseconds)
        track(kind: .metric, name: name, attributes: merged)
    }

    func reportError(_ error: Error, context: String) {
        let nsError = error as NSError
        reportError(name: "\(nsError.domain).\(nsError.code)",
                    message: nsError.localizedDescription,
                    detail: "context=\(context)")
    }

    func reportError(name: String, message: String, detail: String = "") {
        prepare()
        guard consent == .granted else { return }
        let report = ObservabilityErrorReport(name: name,
                                               message: ObservabilitySanitizer.sanitizeValue(message),
                                               detail: ObservabilitySanitizer.sanitizeValue(detail))
        providers.forEach { $0.reportError(report) }
        logger.error("observability fault \(report.name, privacy: .public)")
    }

    private func activateProviders() {
        providers.forEach { $0.activate() }
    }
}
