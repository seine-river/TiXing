import Foundation

struct HarmonyBackupData: Codable {
    var mistakes: [HarmonyBackupMistake]?
    var reviewLogs: [HarmonyBackupReviewLog]?
    var settings: HarmonyBackupSettings?
    var voiceAsks: [HarmonyBackupVoiceAsk]?
    var interestInsights: [HarmonyBackupInsight]?
}

struct HarmonyBackupMistake: Codable {
    var id: String
    var studentId: String?
    var imageUrl: String?
    var ocrText: String?
    var ocrConfidence: Double?
    var isConfirmed: Bool?
    var subject: String?
    var knowledgeTagIds: [String]?
    var errorType: String?
    var status: String?
    var intervalIndex: Int?
    var nextReviewDate: Double?
    var firstReviewDuration: Int?
    var standardAnswer: String?
    var studentAnswer: String?
    var knowledgeSummary: String?
    var answerType: String?
    var notes: String?
    var notesAttachmentUrl: String?
    var createdAt: Double?
}

struct HarmonyBackupReviewLog: Codable {
    var id: String
    var mistakeId: String
    var reviewTime: Double?
    var gradingMethod: String?
    var inputMethod: String?
    var correct: Bool?
    var durationSeconds: Int?
    var pointsAwarded: Int?
    var clientOperationId: String?
}

struct HarmonyBackupSettings: Codable {
    var reviewTimeStart: String?
    var reviewTimeEnd: String?
    var dailyLimit: Int?
    var mathEnabled: Bool?
    var chineseEnabled: Bool?
    var englishEnabled: Bool?
    var scienceEnabled: Bool?
    var doNotDisturb: Bool?
    var notificationEnabled: Bool?
}

struct HarmonyBackupVoiceAsk: Codable {
    var id: String
    var studentId: String?
    var questionText: String?
    var answerText: String?
    var subject: String?
    var topic: String?
    var interestTags: [String]?
    var questionType: String?
    var gradeLevel: String?
    var audioPath: String?
    var audioDuration: Int?
    var asrStatus: String?
    var aiStatus: String?
    var safetyLevel: String?
    var status: String?
    var createdAt: Double?
    var updatedAt: Double?
}

struct HarmonyBackupInsight: Codable {
    var id: String
    var studentId: String?
    var periodStart: Double?
    var periodEnd: Double?
    var questionCount: Int?
    var topSubjects: [String]?
    var topTopics: [String]?
    var interestTags: [String]?
    var trend: String?
    var childSummary: String?
    var parentSummary: String?
    var recommendedActivities: [String]?
    var generatedAt: Double?
}

enum BackupCompatibility {
    static func encode(storage: PersistentStore, exportedAt: Date, studentID: String) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(data(from: storage))
    }

    static func data(from storage: PersistentStore) -> HarmonyBackupData {
        HarmonyBackupData(
            mistakes: storage.mistakes.map { mistake in
                HarmonyBackupMistake(
                    id: mistake.id,
                    studentId: mistake.studentId,
                    imageUrl: mistake.imagePath,
                    ocrText: mistake.question,
                    ocrConfidence: 0,
                    isConfirmed: true,
                    subject: mistake.subject.rawValue,
                    knowledgeTagIds: mistake.tags,
                    errorType: mistake.errorType.rawValue,
                    status: mistake.status.rawValue,
                    intervalIndex: mistake.intervalIndex,
                    nextReviewDate: mistake.nextReviewDate.timeIntervalSince1970 * 1000,
                    firstReviewDuration: mistake.firstReviewDuration,
                    standardAnswer: mistake.standardAnswer,
                    studentAnswer: mistake.studentAnswer,
                    knowledgeSummary: mistake.knowledgeSummary,
                    answerType: mistake.answerType.rawValue,
                    notes: mistake.notes,
                    notesAttachmentUrl: mistake.notesImagePath,
                    createdAt: mistake.createdAt.timeIntervalSince1970 * 1000)
            },
            reviewLogs: storage.reviewLogs.map { log in
                HarmonyBackupReviewLog(
                    id: log.id, mistakeId: log.mistakeId,
                    reviewTime: log.reviewTime.timeIntervalSince1970 * 1000,
                    gradingMethod: "objective_auto",
                    inputMethod: "keyboard",
                    correct: log.correct,
                    durationSeconds: log.durationSeconds,
                    pointsAwarded: log.pointsAwarded,
                    clientOperationId: log.operationId)
            },
            settings: settings(from: storage.settings),
            voiceAsks: storage.voiceAsks.map { record in
                HarmonyBackupVoiceAsk(
                    id: record.id,
                    studentId: storage.student.id,
                    questionText: record.question,
                    answerText: record.answer,
                    subject: record.subject,
                    topic: record.topic,
                    interestTags: record.interestTags,
                    questionType: record.questionType,
                    gradeLevel: record.grade.rawValue,
                    audioPath: record.audioPath,
                    audioDuration: record.audioDuration,
                    asrStatus: statusText(record.asrStatus),
                    aiStatus: statusText(record.aiStatus),
                    safetyLevel: record.safetyLevel.rawValue,
                    status: "active",
                    createdAt: record.createdAt.timeIntervalSince1970 * 1000,
                    updatedAt: record.createdAt.timeIntervalSince1970 * 1000)
            },
            interestInsights: storage.insights.map { insight in
                HarmonyBackupInsight(
                    id: insight.id,
                    studentId: storage.student.id,
                    periodStart: insight.periodStart.timeIntervalSince1970 * 1000,
                    periodEnd: insight.periodEnd.timeIntervalSince1970 * 1000,
                    questionCount: insight.questionCount,
                    topSubjects: insight.topSubjects,
                    topTopics: insight.topTopics,
                    interestTags: insight.interestTags,
                    trend: insight.trend,
                    childSummary: insight.childSummary,
                    parentSummary: insight.parentSummary,
                    recommendedActivities: insight.recommendedActivities,
                    generatedAt: insight.generatedAt.timeIntervalSince1970 * 1000)
            })
    }

    static func storage(from data: HarmonyBackupData, student: Student) -> PersistentStore {
        var storage = PersistentStore()
        storage.student = student
        storage.mistakes = (data.mistakes ?? []).map { raw in
            var mistake = Mistake.new(
                question: raw.ocrText ?? "",
                subject: Subject(rawValue: raw.subject ?? "") ?? .math,
                answerType: AnswerType(rawValue: raw.answerType ?? "") ?? .text,
                standardAnswer: raw.standardAnswer ?? "")
            mistake.id = raw.id
            mistake.studentId = raw.studentId ?? student.id
            mistake.imagePath = raw.imageUrl
            mistake.studentAnswer = raw.studentAnswer ?? ""
            mistake.knowledgeSummary = raw.knowledgeSummary ?? ""
            mistake.errorType = ErrorType(rawValue: raw.errorType ?? "") ?? .other
            mistake.tags = raw.knowledgeTagIds ?? []
            mistake.status = MistakeStatus(rawValue: raw.status ?? "") ?? .unmastered
            mistake.intervalIndex = raw.intervalIndex ?? 0
            mistake.nextReviewDate = date(raw.nextReviewDate, fallback: Date().addingTimeInterval(86_400))
            mistake.firstReviewDuration = raw.firstReviewDuration ?? 60
            mistake.notes = raw.notes ?? ""
            mistake.notesImagePath = raw.notesAttachmentUrl
            mistake.createdAt = date(raw.createdAt, fallback: Date())
            return mistake
        }
        storage.reviewLogs = (data.reviewLogs ?? []).map { raw in
            ReviewLog(
                id: raw.id,
                mistakeId: raw.mistakeId,
                reviewTime: date(raw.reviewTime, fallback: Date()),
                correct: raw.correct ?? false,
                durationSeconds: raw.durationSeconds ?? 0,
                pointsAwarded: raw.pointsAwarded ?? 0,
                operationId: raw.clientOperationId ?? raw.id)
        }
        if let rawSettings = data.settings {
            storage.settings = settings(from: rawSettings)
        }
        storage.voiceAsks = (data.voiceAsks ?? []).map { raw in
            var record = VoiceAskRecord()
            record.id = raw.id
            record.question = raw.questionText ?? ""
            record.answer = raw.answerText ?? ""
            record.subject = raw.subject ?? "other"
            record.topic = raw.topic ?? ""
            record.interestTags = raw.interestTags ?? []
            record.questionType = raw.questionType ?? "fact"
            record.grade = Grade(rawValue: raw.gradeLevel ?? "") ?? student.grade
            record.audioPath = raw.audioPath
            record.audioDuration = raw.audioDuration ?? 0
            record.asrStatus = status(raw.asrStatus)
            record.aiStatus = status(raw.aiStatus)
            record.safetyLevel = raw.safetyLevel == "attention" ? .attention : .normal
            record.createdAt = date(raw.createdAt, fallback: Date())
            return record
        }
        storage.insights = (data.interestInsights ?? []).map { raw in
            InterestInsight(
                id: raw.id,
                periodStart: date(raw.periodStart, fallback: Date()),
                periodEnd: date(raw.periodEnd, fallback: Date()),
                questionCount: raw.questionCount ?? 0,
                topSubjects: raw.topSubjects ?? [],
                topTopics: raw.topTopics ?? [],
                interestTags: raw.interestTags ?? [],
                trend: raw.trend ?? "stable",
                childSummary: raw.childSummary ?? "",
                parentSummary: raw.parentSummary ?? "",
                recommendedActivities: raw.recommendedActivities ?? [],
                generatedAt: date(raw.generatedAt, fallback: Date()))
        }
        return storage
    }

    private static func settings(from settings: ReminderSettings) -> HarmonyBackupSettings {
        HarmonyBackupSettings(
            reviewTimeStart: minutesToClock(settings.startMinutes),
            reviewTimeEnd: minutesToClock(settings.endMinutes),
            dailyLimit: settings.dailyLimit,
            mathEnabled: settings.subjects.contains(.math),
            chineseEnabled: settings.subjects.contains(.chinese),
            englishEnabled: settings.subjects.contains(.english),
            scienceEnabled: settings.subjects.contains(.science),
            doNotDisturb: false,
            notificationEnabled: settings.enabled)
    }

    private static func settings(from raw: HarmonyBackupSettings) -> ReminderSettings {
        var settings = ReminderSettings()
        settings.startMinutes = clockToMinutes(raw.reviewTimeStart ?? "08:00", fallback: 480)
        settings.endMinutes = clockToMinutes(raw.reviewTimeEnd ?? "21:00", fallback: 1260)
        settings.dailyLimit = raw.dailyLimit ?? 10
        settings.subjects = []
        if raw.mathEnabled ?? true { settings.subjects.insert(.math) }
        if raw.chineseEnabled ?? true { settings.subjects.insert(.chinese) }
        if raw.englishEnabled ?? false { settings.subjects.insert(.english) }
        if raw.scienceEnabled ?? false { settings.subjects.insert(.science) }
        settings.enabled = raw.notificationEnabled ?? true
        return settings
    }

    private static func date(_ milliseconds: Double?, fallback: Date) -> Date {
        guard let milliseconds else { return fallback }
        return Date(timeIntervalSince1970: milliseconds / 1000)
    }

    private static func minutesToClock(_ value: Int) -> String {
        String(format: "%02d:%02d", value / 60, value % 60)
    }

    private static func clockToMinutes(_ value: String, fallback: Int) -> Int {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return fallback }
        return hour * 60 + minute
    }

    private static func statusText(_ value: VoiceAskRecord.Status) -> String {
        switch value {
        case .pending: return "pending"
        case .processing: return "processing"
        case .done: return "done"
        case .failed: return "failed"
        }
    }

    private static func status(_ value: String?) -> VoiceAskRecord.Status {
        switch value {
        case "done": return .done
        case "failed": return .failed
        case "processing": return .processing
        default: return .pending
        }
    }
}
