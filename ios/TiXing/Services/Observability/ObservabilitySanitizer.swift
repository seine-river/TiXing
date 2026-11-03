import Foundation

enum ObservabilitySanitizer {
    private static let reservedKeys: Set<String> = [
        "id", "ts", "du", "ds", "duration", "pn", "token", "device_name", "device_model",
        "device_brand", "country", "city", "channel", "province", "appkey", "app_version",
        "access", "launch", "pre_app_version", "terminate", "type"
    ]
    private static let blockedKeys: Set<String> = [
        "api_key", "apikey", "authorization", "question", "answer", "text", "content",
        "image", "imageurl", "audio", "audiopath", "nickname", "student_id", "studentid", "name"
    ]

    static func eventID(kind: ObservabilityEventKind, name: String) -> String {
        let normalized = name.lowercased()
            .map { character in
                (character.isASCII && (character.isLetter || character.isNumber)) || character == "_" ? String(character) : "_"
            }
            .joined()
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return "\(kind.rawValue)_\(normalized.isEmpty ? "unknown" : normalized)".prefix(96).description
    }

    static func attributes(_ attributes: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (rawKey, rawValue) in attributes.prefix(16) {
            let key = normalizeKey(rawKey)
            guard !key.isEmpty, !reservedKeys.contains(key), !isBlocked(key) else { continue }
            result[key] = sanitizeValue(rawValue)
        }
        return result
    }

    static func sanitizeValue(_ value: String) -> String {
        let masked = value
            .replacingOccurrences(of: "Bearer [A-Za-z0-9._-]+", with: "[token]", options: .regularExpression)
            .replacingOccurrences(of: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", with: "[email]", options: .regularExpression)
        return String(masked
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(180))
    }

    private static func normalizeKey(_ key: String) -> String {
        let normalized = key.lowercased()
            .map { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "_" ? String($0) : "_" }
            .joined()
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return String(normalized.prefix(64))
    }

    private static func isBlocked(_ key: String) -> Bool {
        for blocked in blockedKeys where key == blocked || key.hasPrefix("\(blocked)_") ||
            key.hasSuffix("_\(blocked)") || key.contains("_\(blocked)_") {
            return true
        }
        let segments = Set(key.split(separator: "_").map(String.init))
        return !blockedKeys.isDisjoint(with: segments)
    }
}
