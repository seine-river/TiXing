import Foundation

enum ObservabilityEventKind: String {
    case behavior
    case metric
    case fault
}

struct ObservabilityEvent {
    let kind: ObservabilityEventKind
    let name: String
    let attributes: [String: String]

    var sanitizedID: String {
        ObservabilitySanitizer.eventID(kind: kind, name: name)
    }

    var sanitizedAttributes: [String: String] {
        ObservabilitySanitizer.attributes(attributes)
    }
}

struct ObservabilityErrorReport {
    let name: String
    let message: String
    let detail: String
}

protocol ObservabilityProvider {
    var name: String { get }
    func activate()
    func track(_ event: ObservabilityEvent)
    func reportError(_ report: ObservabilityErrorReport)
}
