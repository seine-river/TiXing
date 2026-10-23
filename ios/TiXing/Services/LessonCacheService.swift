import Foundation

private struct CachedLessonRecord: Codable {
    var sourceFingerprint: String
    var savedAt: Date
    var lesson: AILesson
}

/// AI 讲解脚本本地缓存。
/// 讲解“视频”由脚本 + 本地动画 + TTS 实时渲染，因此持久化脚本即可完整复原播放内容。
struct LessonCacheService {
    static func sourceFingerprint(mistake: Mistake, grade: Grade) -> String {
        [
            grade.rawValue,
            mistake.question,
            mistake.studentAnswer,
            mistake.standardAnswer,
            mistake.knowledgeSummary,
            mistake.subject.rawValue,
            mistake.errorType.rawValue
        ].joined(separator: "\u{1F}")
    }

    static func hasCachedLesson(mistakeID: String, sourceFingerprint: String) -> Bool {
        guard !mistakeID.isEmpty else { return false }
        guard let data = try? Data(contentsOf: cacheURL(mistakeID: mistakeID)),
              let record = try? JSONDecoder().decode(CachedLessonRecord.self, from: data) else {
            return false
        }
        return record.sourceFingerprint == sourceFingerprint && !record.lesson.scenes.isEmpty
    }

    static func load(mistakeID: String, sourceFingerprint: String) -> AILesson? {
        guard !mistakeID.isEmpty else { return nil }
        let url = cacheURL(mistakeID: mistakeID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            let record = try JSONDecoder().decode(CachedLessonRecord.self, from: data)
            guard record.sourceFingerprint == sourceFingerprint else {
                remove(mistakeID: mistakeID)
                return nil
            }
            let lesson = record.lesson
            guard !lesson.scenes.isEmpty else {
                remove(mistakeID: mistakeID)
                return nil
            }
            return lesson
        } catch {
            remove(mistakeID: mistakeID)
            return nil
        }
    }

    static func save(mistakeID: String, sourceFingerprint: String, lesson: AILesson) {
        guard !mistakeID.isEmpty, !lesson.scenes.isEmpty else { return }
        do {
            try FileManager.default.createDirectory(
                at: cacheDirectory, withIntermediateDirectories: true)
            let record = CachedLessonRecord(
                sourceFingerprint: sourceFingerprint,
                savedAt: Date(),
                lesson: lesson)
            let data = try JSONEncoder().encode(record)
            try data.write(to: cacheURL(mistakeID: mistakeID), options: [.atomic, .completeFileProtection])
        } catch {
            // 缓存失败不阻断讲解播放；下次进入时会重新生成。
        }
    }

    static func remove(mistakeID: String) {
        guard !mistakeID.isEmpty else { return }
        try? FileManager.default.removeItem(at: cacheURL(mistakeID: mistakeID))
    }

    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TiXing", isDirectory: true)
            .appendingPathComponent("Lessons", isDirectory: true)
    }

    private static func cacheURL(mistakeID: String) -> URL {
        cacheDirectory.appendingPathComponent("\(mistakeID.replacingOccurrences(of: "/", with: "_")).json")
    }
}
