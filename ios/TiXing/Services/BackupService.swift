import Foundation

struct BackupManifest: Codable {
    let app: String
    let version: Int
    let exportedAt: Date
    let studentId: String
}

struct BackupService {
    static let bundleVersion = 3

    @MainActor
    static func export(store: AppStore, to destination: URL) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifest = BackupManifest(app: "tixing", version: bundleVersion,
                                      exportedAt: Date(), studentId: store.student.id)
        let manifestData = try encoder.encode(manifest)
        let data = try BackupCompatibility.encode(storage: store.storage, exportedAt: Date(), studentID: store.student.id)

        var entries: [(String, Data)] = [
            ("manifest.json", manifestData),
            ("data.json", data)
        ]

        for mistake in store.mistakes {
            guard let path = mistake.imagePath,
                  FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)
            entries.append(("images/\(mistake.id).jpg", try Data(contentsOf: url)))
        }
        for mistake in store.mistakes {
            guard let path = mistake.notesImagePath,
                  FileManager.default.fileExists(atPath: path) else { continue }
            entries.append(("notes/\(mistake.id).jpg", try Data(contentsOf: URL(fileURLWithPath: path))))
        }
        for record in store.voiceAsks {
            guard let path = record.audioPath, FileManager.default.fileExists(atPath: path) else { continue }
            let ext = path.lowercased().hasSuffix(".mp3") ? "mp3" : "wav"
            entries.append(("audio/\(record.id).\(ext)", try Data(contentsOf: URL(fileURLWithPath: path))))
        }

        try ZipService.write(entries: entries.map { ($0.0, $0.1) }, to: destination)
    }

    static func preview(at url: URL, currentStudent: Student = Student()) async throws -> BackupPreview {
        let files = try ZipService.read(url: url)
        let millisDecoder = JSONDecoder()
        millisDecoder.dateDecodingStrategy = .millisecondsSince1970
        guard let manifestData = files["manifest.json"],
              let manifest = try? millisDecoder.decode(BackupManifest.self, from: manifestData),
              manifest.app == "tixing", manifest.version <= bundleVersion else {
            throw NSError(domain: "TiXing.Backup", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "不是题醒应用的有效备份文件"])
        }
        guard let dataData = files["data.json"] else {
            throw NSError(domain: "TiXing.Backup", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "备份数据解析失败"])
        }
        let storage: PersistentStore
        if let iosStorage = try? decoder.decode(PersistentStore.self, from: dataData) {
            storage = iosStorage
        } else if let harmonyData = try? millisDecoder.decode(HarmonyBackupData.self, from: dataData) {
            storage = BackupCompatibility.storage(from: harmonyData, student: currentStudent)
        } else {
            throw NSError(domain: "TiXing.Backup", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "备份数据解析失败"])
        }
        let preview = BackupPreview(
            manifest: manifest,
            sourceURL: url,
            storage: storage,
            imageData: files.filter { $0.key.hasPrefix("images/") },
            notesImageData: files.filter { $0.key.hasPrefix("notes/") },
            audioData: files.filter { $0.key.hasPrefix("audio/") })
        return preview
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

struct BackupPreview {
    let manifest: BackupManifest
    let sourceURL: URL
    let storage: PersistentStore
    let imageData: [String: Data]
    let notesImageData: [String: Data]
    let audioData: [String: Data]

    var mistakeCount: Int { storage.mistakes.count }
    var reviewCount: Int { storage.reviewLogs.count }
    var voiceCount: Int { storage.voiceAsks.count }
    var insightCount: Int { storage.insights.count }
}
