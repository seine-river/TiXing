import Foundation

enum StableDeviceID {
    private static let key = "tixing.observability.deviceID"

    static var value: String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let generated = "tixing-" + UUID().uuidString.lowercased().prefix(18)
        UserDefaults.standard.set(generated, forKey: key)
        return String(generated)
    }
}
