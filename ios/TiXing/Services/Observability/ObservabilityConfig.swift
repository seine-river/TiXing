import Foundation

struct ObservabilityConfig {
    let umengAppKey = "6ae5a2846545637cd62c8fb5"
    let umengChannel = "App Store"
    let buglyAppID: String
    let buglyAppKey: String

    var buglyConfigured: Bool {
        !buglyAppID.isEmpty && !buglyAppKey.isEmpty
    }

    static func load(bundle: Bundle = .main) -> ObservabilityConfig {
        guard let url = bundle.url(forResource: "buglyconfig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let appID = object["appId"],
              let appKey = object["appKey"] else {
            return ObservabilityConfig(buglyAppID: "", buglyAppKey: "")
        }
        return ObservabilityConfig(buglyAppID: appID.trimmingCharacters(in: .whitespacesAndNewlines),
                                   buglyAppKey: appKey.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
