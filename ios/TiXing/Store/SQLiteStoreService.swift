import Foundation
import SQLite3

private let sqliteTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteValue {
    case null
    case int(Int)
    case double(Double)
    case text(String)
}

enum SQLiteStoreError: Error, LocalizedError {
    case open(String)
    case prepare(String, sql: String)
    case step(String, sql: String)

    var errorDescription: String? {
        switch self {
        case .open(let message): return "SQLite 打开失败：\(message)"
        case .prepare(let message, let sql): return "SQLite prepare 失败：\(message)；SQL：\(sql)"
        case .step(let message, let sql): return "SQLite step 失败：\(message)；SQL：\(sql)"
        }
    }
}

/// iOS 端本地数据库。
/// 表结构对齐 HarmonyOS schema v3 的核心实体，并补齐常用查询索引；
/// JSON 快照仅作为 v3 之前数据的迁移来源，不再作为主存储。
final class SQLiteStoreService {
    static let schemaVersion = 3
    private var database: OpaquePointer?
    private let queue = DispatchQueue(label: "com.tixing.me.sqlite")
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    let databaseURL: URL

    init(url: URL) throws {
        databaseURL = url
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close_v2(handle)
            throw SQLiteStoreError.open(message)
        }
        database = handle
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA foreign_keys=ON")
        try createSchema()
    }

    deinit {
        sqlite3_close_v2(database)
    }

    // MARK: - Schema

    private func createSchema() throws {
        let statements = [
            """
            CREATE TABLE IF NOT EXISTS student (
              id TEXT PRIMARY KEY,
              nickname TEXT NOT NULL,
              grade TEXT NOT NULL,
              textbookVersion TEXT NOT NULL,
              createdAt INTEGER NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS mistake (
              id TEXT PRIMARY KEY,
              studentId TEXT NOT NULL,
              imagePath TEXT,
              question TEXT NOT NULL,
              studentAnswer TEXT NOT NULL,
              standardAnswer TEXT NOT NULL,
              knowledgeSummary TEXT NOT NULL,
              subject TEXT NOT NULL,
              answerType TEXT NOT NULL,
              errorType TEXT NOT NULL,
              tags TEXT NOT NULL,
              status TEXT NOT NULL,
              intervalIndex INTEGER NOT NULL,
              nextReviewDate INTEGER NOT NULL,
              firstReviewDuration INTEGER NOT NULL,
              notes TEXT NOT NULL,
              notesImagePath TEXT,
              createdAt INTEGER NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS review_log (
              id TEXT PRIMARY KEY,
              mistakeId TEXT NOT NULL,
              reviewTime INTEGER NOT NULL,
              correct INTEGER NOT NULL,
              durationSeconds INTEGER NOT NULL,
              pointsAwarded INTEGER NOT NULL,
              operationId TEXT NOT NULL,
              subjective INTEGER NOT NULL DEFAULT 0
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS knowledge_tag (
              id TEXT PRIMARY KEY,
              subject TEXT NOT NULL,
              grade TEXT NOT NULL,
              textbookVersion TEXT NOT NULL,
              name TEXT NOT NULL,
              parentTagId TEXT
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS knowledge_profile (
              id TEXT PRIMARY KEY,
              studentId TEXT NOT NULL,
              tag TEXT NOT NULL,
              totalMistakes INTEGER NOT NULL,
              masteredCount INTEGER NOT NULL,
              masteryScore REAL NOT NULL,
              trend TEXT NOT NULL,
              updatedAt INTEGER NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS points_log (
              id TEXT PRIMARY KEY,
              action TEXT NOT NULL,
              points INTEGER NOT NULL,
              createdAt INTEGER NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS redemption (
              id TEXT PRIMARY KEY,
              itemID TEXT NOT NULL,
              cost INTEGER NOT NULL,
              redeemedAt INTEGER NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS reminder_settings (
              id TEXT PRIMARY KEY,
              studentId TEXT NOT NULL,
              startMinutes INTEGER NOT NULL,
              endMinutes INTEGER NOT NULL,
              dailyLimit INTEGER NOT NULL,
              subjects TEXT NOT NULL,
              enabled INTEGER NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS voice_ask_record (
              id TEXT PRIMARY KEY,
              question TEXT NOT NULL,
              answer TEXT NOT NULL,
              subject TEXT NOT NULL,
              topic TEXT NOT NULL,
              interestTags TEXT NOT NULL,
              questionType TEXT NOT NULL,
              grade TEXT NOT NULL,
              audioPath TEXT,
              audioDuration INTEGER NOT NULL,
              asrStatus TEXT NOT NULL,
              aiStatus TEXT NOT NULL,
              safetyLevel TEXT NOT NULL,
              createdAt INTEGER NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS interest_insight (
              id TEXT PRIMARY KEY,
              periodStart INTEGER NOT NULL,
              periodEnd INTEGER NOT NULL,
              questionCount INTEGER NOT NULL,
              topSubjects TEXT NOT NULL,
              topTopics TEXT NOT NULL,
              interestTags TEXT NOT NULL,
              trend TEXT NOT NULL,
              childSummary TEXT NOT NULL,
              parentSummary TEXT NOT NULL,
              recommendedActivities TEXT NOT NULL,
              generatedAt INTEGER NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS analytics_event (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              studentHash TEXT NOT NULL,
              createdAt INTEGER NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS parent_account (
              id TEXT PRIMARY KEY,
              phoneHash TEXT NOT NULL,
              subscriptionStatus TEXT NOT NULL,
              createdAt INTEGER NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS community_post (
              id TEXT PRIMARY KEY,
              studentId TEXT NOT NULL,
              mistakeId TEXT NOT NULL,
              status TEXT NOT NULL,
              createdAt INTEGER NOT NULL
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_mistake_next_review ON mistake(nextReviewDate)",
            "CREATE INDEX IF NOT EXISTS idx_mistake_student ON mistake(studentId)",
            "CREATE INDEX IF NOT EXISTS idx_mistake_status ON mistake(status)",
            "CREATE INDEX IF NOT EXISTS idx_review_log_mistake ON review_log(mistakeId)",
            "CREATE INDEX IF NOT EXISTS idx_review_log_time ON review_log(reviewTime)",
            "CREATE INDEX IF NOT EXISTS idx_points_log_created ON points_log(createdAt)",
            "CREATE INDEX IF NOT EXISTS idx_analytics_event_type ON analytics_event(type)",
            "CREATE INDEX IF NOT EXISTS idx_knowledge_profile_student ON knowledge_profile(studentId)",
            "CREATE INDEX IF NOT EXISTS idx_redemption_item ON redemption(itemID)",
            "CREATE INDEX IF NOT EXISTS idx_voice_ask_created ON voice_ask_record(createdAt)",
            "PRAGMA user_version=\(SQLiteStoreService.schemaVersion)"
        ]
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            for statement in statements {
                try execute(statement)
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    // MARK: - Introspection used by tests and diagnostics

    var userVersion: Int {
        get {
            (try? scalarInt("PRAGMA user_version")) ?? 0
        }
        set {
            try? execute("PRAGMA user_version=\(newValue)")
        }
    }

    func tableNames() throws -> [String] {
        try strings("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
    }

    func indexNames() throws -> [String] {
        try strings("SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%' ORDER BY name")
    }

    func rowCount(_ table: String) throws -> Int {
        let allowed = Set([
            "student", "mistake", "review_log", "knowledge_tag", "knowledge_profile",
            "points_log", "redemption", "reminder_settings", "voice_ask_record",
            "interest_insight", "analytics_event", "parent_account", "community_post"
        ])
        guard allowed.contains(table) else { return 0 }
        return try scalarInt("SELECT COUNT(*) FROM \(table)")
    }

    private func scalarInt(_ sql: String) throws -> Int {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(lastError, sql: sql)
        }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLiteStoreError.step(lastError, sql: sql)
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func strings(_ sql: String) throws -> [String] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(lastError, sql: sql)
        }
        var result: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(String(cString: sqlite3_column_text(statement, 0)))
        }
        return result
    }

    // MARK: - Persistence

    func load() throws -> PersistentStore {
        var store = PersistentStore()
        store.hasSeededExamples = true
        try loadStudent(into: &store)
        try loadMistakes(into: &store)
        try loadReviewLogs(into: &store)
        try loadKnowledgeProfiles(into: &store)
        try loadPointsLogs(into: &store)
        try loadRedemptions(into: &store)
        try loadSettings(into: &store)
        try loadVoiceAsks(into: &store)
        try loadInsights(into: &store)
        try loadAnalytics(into: &store)
        return store
    }

    func save(_ store: PersistentStore) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let clearTables = [
                "student", "mistake", "review_log", "knowledge_profile", "points_log",
                "redemption", "reminder_settings", "voice_ask_record", "interest_insight",
                "analytics_event"
            ]
            for table in clearTables {
                try execute("DELETE FROM \(table)")
            }
            try insertStudent(store.student)
            try store.mistakes.forEach(insertMistake)
            try store.reviewLogs.forEach(insertReviewLog)
            try (store.knowledgeProfiles ?? []).forEach(insertKnowledgeProfile)
            try store.pointsLogs.forEach(insertPointsLog)
            try (store.redemptionRecords ?? []).forEach(insertRedemption)
            try insertSettings(store.settings, studentID: store.student.id)
            try store.voiceAsks.forEach(insertVoiceAsk)
            try store.insights.forEach(insertInsight)
            try store.analytics.forEach(insertAnalytics)
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    // MARK: - SQL helpers

    private var lastError: String {
        database.map { String(cString: sqlite3_errmsg($0)) } ?? "database closed"
    }

    private func execute(_ sql: String) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(lastError, sql: sql)
        }
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw SQLiteStoreError.step(lastError, sql: sql)
        }
    }

    private func run(_ sql: String, _ values: [SQLiteValue]) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(lastError, sql: sql)
        }
        try bind(values, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.step(lastError, sql: sql)
        }
    }

    private func query(_ sql: String, _ values: [SQLiteValue] = []) throws -> [[SQLiteValue]] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(lastError, sql: sql)
        }
        try bind(values, to: statement)
        var rows: [[SQLiteValue]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let count = sqlite3_column_count(statement)
            var row: [SQLiteValue] = []
            for index in 0..<Int(count) {
                switch sqlite3_column_type(statement, Int32(index)) {
                case SQLITE_NULL: row.append(.null)
                case SQLITE_INTEGER: row.append(.int(Int(sqlite3_column_int64(statement, Int32(index)))))
                case SQLITE_FLOAT: row.append(.double(sqlite3_column_double(statement, Int32(index))))
                default:
                    if let text = sqlite3_column_text(statement, Int32(index)) {
                        row.append(.text(String(cString: text)))
                    } else {
                        row.append(.null)
                    }
                }
            }
            rows.append(row)
        }
        return rows
    }

    private func bind(_ values: [SQLiteValue], to statement: OpaquePointer?) throws {
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            let result: Int32
            switch value {
            case .null: result = sqlite3_bind_null(statement, position)
            case .int(let value): result = sqlite3_bind_int64(statement, position, Int64(value))
            case .double(let value): result = sqlite3_bind_double(statement, position, value)
            case .text(let value): result = sqlite3_bind_text(statement, position, value, -1, sqliteTransientDestructor)
            }
            guard result == SQLITE_OK else {
                throw SQLiteStoreError.prepare(lastError, sql: "bind parameter \(position)")
            }
        }
    }

    private func json<T: Encodable>(_ value: T) throws -> String {
        String(data: try jsonEncoder.encode(value), encoding: .utf8) ?? "[]"
    }

    private func jsonArray(_ text: SQLiteValue) -> [String] {
        guard case .text(let text) = text,
              let data = text.data(using: .utf8),
              let values = try? jsonDecoder.decode([String].self, from: data) else {
            return []
        }
        return values
    }

    private func int(_ value: SQLiteValue, default defaultValue: Int = 0) -> Int {
        if case .int(let value) = value { return value }
        if case .double(let value) = value { return Int(value) }
        return defaultValue
    }

    private func double(_ value: SQLiteValue, default defaultValue: Double = 0) -> Double {
        if case .double(let value) = value { return value }
        if case .int(let value) = value { return Double(value) }
        return defaultValue
    }

    private func text(_ value: SQLiteValue, default defaultValue: String = "") -> String {
        if case .text(let value) = value { return value }
        return defaultValue
    }

    private func optionalText(_ value: SQLiteValue) -> String? {
        if case .text(let value) = value { return value }
        return nil
    }

    private func bool(_ value: SQLiteValue) -> Bool {
        int(value) != 0
    }

    private func date(_ value: SQLiteValue) -> Date {
        Date(timeIntervalSince1970: double(value))
    }

    private func boolValue(_ value: Bool) -> SQLiteValue {
        .int(value ? 1 : 0)
    }

    // MARK: - Inserts

    private func insertStudent(_ student: Student) throws {
        try run("""
        INSERT INTO student(id, nickname, grade, textbookVersion, createdAt)
        VALUES(?,?,?,?,?)
        """, [.text(student.id), .text(student.nickname), .text(student.grade.rawValue),
              .text(student.textbookVersion.rawValue), .double(student.createdAt.timeIntervalSince1970)])
    }

    private func insertMistake(_ mistake: Mistake) throws {
        try run("""
        INSERT INTO mistake(
          id,studentId,imagePath,question,studentAnswer,standardAnswer,knowledgeSummary,
          subject,answerType,errorType,tags,status,intervalIndex,nextReviewDate,
          firstReviewDuration,notes,notesImagePath,createdAt
        ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, [
            .text(mistake.id), .text(mistake.studentId), mistake.imagePath.map { .text($0) } ?? .null,
            .text(mistake.question), .text(mistake.studentAnswer), .text(mistake.standardAnswer),
            .text(mistake.knowledgeSummary), .text(mistake.subject.rawValue),
            .text(mistake.answerType.rawValue), .text(mistake.errorType.rawValue),
            .text(try json(mistake.tags)), .text(mistake.status.rawValue), .int(mistake.intervalIndex),
            .double(mistake.nextReviewDate.timeIntervalSince1970), .int(mistake.firstReviewDuration),
            .text(mistake.notes), mistake.notesImagePath.map { .text($0) } ?? .null,
            .double(mistake.createdAt.timeIntervalSince1970)
        ])
    }

    private func insertReviewLog(_ log: ReviewLog) throws {
        try run("""
        INSERT INTO review_log(
          id,mistakeId,reviewTime,correct,durationSeconds,pointsAwarded,operationId,subjective
        ) VALUES(?,?,?,?,?,?,?,?)
        """, [.text(log.id), .text(log.mistakeId), .double(log.reviewTime.timeIntervalSince1970),
              boolValue(log.correct), .int(log.durationSeconds), .int(log.pointsAwarded),
              .text(log.operationId), boolValue(log.subjective)])
    }

    private func insertKnowledgeProfile(_ profile: KnowledgeProfile) throws {
        try run("""
        INSERT INTO knowledge_profile(
          id,studentId,tag,totalMistakes,masteredCount,masteryScore,trend,updatedAt
        ) VALUES(?,?,?,?,?,?,?,?)
        """, [.text(profile.id), .text(profile.studentID), .text(profile.tag),
              .int(profile.totalMistakes), .int(profile.masteredCount),
              .double(profile.masteryScore), .text(profile.trend),
              .double(profile.updatedAt.timeIntervalSince1970)])
    }

    private func insertPointsLog(_ log: PointsLog) throws {
        try run("""
        INSERT INTO points_log(id,action,points,createdAt) VALUES(?,?,?,?)
        """, [.text(log.id), .text(log.action.rawValue), .int(log.points),
              .double(log.createdAt.timeIntervalSince1970)])
    }

    private func insertRedemption(_ record: RedemptionRecord) throws {
        try run("""
        INSERT INTO redemption(id,itemID,cost,redeemedAt) VALUES(?,?,?,?)
        """, [.text(record.id), .text(record.itemID), .int(record.cost),
              .double(record.redeemedAt.timeIntervalSince1970)])
    }

    private func insertSettings(_ settings: ReminderSettings, studentID: String) throws {
        try run("""
        INSERT INTO reminder_settings(
          id,studentId,startMinutes,endMinutes,dailyLimit,subjects,enabled
        ) VALUES(?,?,?,?,?,?,?)
        """, [.text("default"), .text(studentID), .int(settings.startMinutes),
              .int(settings.endMinutes), .int(settings.dailyLimit),
              .text(try json(settings.subjects.map(\.rawValue))), boolValue(settings.enabled)])
    }

    private func insertVoiceAsk(_ record: VoiceAskRecord) throws {
        try run("""
        INSERT INTO voice_ask_record(
          id,question,answer,subject,topic,interestTags,questionType,grade,
          audioPath,audioDuration,asrStatus,aiStatus,safetyLevel,createdAt
        ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, [.text(record.id), .text(record.question), .text(record.answer),
              .text(record.subject), .text(record.topic), .text(try json(record.interestTags)),
              .text(record.questionType), .text(record.grade.rawValue),
              record.audioPath.map { .text($0) } ?? .null, .int(record.audioDuration),
              .text(record.asrStatus.rawValue), .text(record.aiStatus.rawValue),
              .text(record.safetyLevel.rawValue), .double(record.createdAt.timeIntervalSince1970)])
    }

    private func insertInsight(_ insight: InterestInsight) throws {
        try run("""
        INSERT INTO interest_insight(
          id,periodStart,periodEnd,questionCount,topSubjects,topTopics,interestTags,
          trend,childSummary,parentSummary,recommendedActivities,generatedAt
        ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
        """, [.text(insight.id), .double(insight.periodStart.timeIntervalSince1970),
              .double(insight.periodEnd.timeIntervalSince1970), .int(insight.questionCount),
              .text(try json(insight.topSubjects)), .text(try json(insight.topTopics)),
              .text(try json(insight.interestTags)), .text(insight.trend),
              .text(insight.childSummary), .text(insight.parentSummary),
              .text(try json(insight.recommendedActivities)),
              .double(insight.generatedAt.timeIntervalSince1970)])
    }

    private func insertAnalytics(_ event: AnalyticsEvent) throws {
        try run("""
        INSERT INTO analytics_event(id,type,studentHash,createdAt) VALUES(?,?,?,?)
        """, [.text(event.id), .text(event.type), .text(event.studentHash),
              .double(event.createdAt.timeIntervalSince1970)])
    }

    // MARK: - Loads

    private func loadStudent(into store: inout PersistentStore) throws {
        let rows = try query("SELECT id,nickname,grade,textbookVersion,createdAt FROM student LIMIT 1")
        guard let row = rows.first else { return }
        store.student = Student(
            id: text(row[0]), nickname: text(row[1]),
            grade: Grade(rawValue: text(row[2])) ?? .three,
            textbookVersion: TextbookVersion(rawValue: text(row[3])) ?? .pep,
            createdAt: date(row[4]))
    }

    private func loadMistakes(into store: inout PersistentStore) throws {
        let rows = try query("""
        SELECT id,studentId,imagePath,question,studentAnswer,standardAnswer,knowledgeSummary,
               subject,answerType,errorType,tags,status,intervalIndex,nextReviewDate,
               firstReviewDuration,notes,notesImagePath,createdAt
        FROM mistake ORDER BY createdAt DESC
        """)
        store.mistakes = rows.map { row in
            var mistake = Mistake.new(
                question: text(row[3]),
                subject: Subject(rawValue: text(row[7])) ?? .math,
                answerType: AnswerType(rawValue: text(row[8])) ?? .text,
                standardAnswer: text(row[5]))
            mistake.id = text(row[0])
            mistake.studentId = text(row[1])
            mistake.imagePath = optionalText(row[2])
            mistake.studentAnswer = text(row[4])
            mistake.knowledgeSummary = text(row[6])
            mistake.errorType = ErrorType(rawValue: text(row[9])) ?? .other
            mistake.tags = jsonArray(row[10])
            mistake.status = MistakeStatus(rawValue: text(row[11])) ?? .unmastered
            mistake.intervalIndex = int(row[12])
            mistake.nextReviewDate = date(row[13])
            mistake.firstReviewDuration = int(row[14])
            mistake.notes = text(row[15])
            mistake.notesImagePath = optionalText(row[16])
            mistake.createdAt = date(row[17])
            return mistake
        }
    }

    private func loadReviewLogs(into store: inout PersistentStore) throws {
        let rows = try query("""
        SELECT id,mistakeId,reviewTime,correct,durationSeconds,pointsAwarded,operationId,subjective
        FROM review_log ORDER BY reviewTime DESC
        """)
        store.reviewLogs = rows.map { row in
            ReviewLog(
                id: text(row[0]), mistakeId: text(row[1]), reviewTime: date(row[2]),
                correct: bool(row[3]), durationSeconds: int(row[4]),
                pointsAwarded: int(row[5]), operationId: text(row[6]), subjective: bool(row[7]))
        }
    }

    private func loadKnowledgeProfiles(into store: inout PersistentStore) throws {
        let rows = try query("""
        SELECT id,studentId,tag,totalMistakes,masteredCount,masteryScore,trend,updatedAt
        FROM knowledge_profile ORDER BY masteryScore ASC
        """)
        store.knowledgeProfiles = rows.map { row in
            KnowledgeProfile(
                id: text(row[0]), studentID: text(row[1]), tag: text(row[2]),
                totalMistakes: int(row[3]), masteredCount: int(row[4]),
                masteryScore: double(row[5]), trend: text(row[6]), updatedAt: date(row[7]))
        }
    }

    private func loadPointsLogs(into store: inout PersistentStore) throws {
        let rows = try query("SELECT id,action,points,createdAt FROM points_log ORDER BY createdAt DESC")
        store.pointsLogs = rows.map { row in
            PointsLog(id: text(row[0]),
                      action: PointsAction(rawValue: text(row[1])) ?? .capture,
                      points: int(row[2]), createdAt: date(row[3]))
        }
    }

    private func loadRedemptions(into store: inout PersistentStore) throws {
        let rows = try query("SELECT id,itemID,cost,redeemedAt FROM redemption ORDER BY redeemedAt DESC")
        let records = rows.map { row in
            RedemptionRecord(id: text(row[0]), itemID: text(row[1]), cost: int(row[2]),
                             redeemedAt: date(row[3]))
        }
        store.redemptionRecords = records
        store.redeemedItemIds = Set(records.map(\.itemID))
    }

    private func loadSettings(into store: inout PersistentStore) throws {
        let rows = try query("""
        SELECT startMinutes,endMinutes,dailyLimit,subjects,enabled
        FROM reminder_settings LIMIT 1
        """)
        guard let row = rows.first else { return }
        var settings = ReminderSettings()
        settings.startMinutes = int(row[0])
        settings.endMinutes = int(row[1])
        settings.dailyLimit = int(row[2])
        settings.subjects = Set(jsonArray(row[3]).compactMap(Subject.init(rawValue:)))
        settings.enabled = bool(row[4])
        store.settings = settings
    }

    private func loadVoiceAsks(into store: inout PersistentStore) throws {
        let rows = try query("""
        SELECT id,question,answer,subject,topic,interestTags,questionType,grade,
               audioPath,audioDuration,asrStatus,aiStatus,safetyLevel,createdAt
        FROM voice_ask_record ORDER BY createdAt DESC
        """)
        store.voiceAsks = rows.map { row in
            var record = VoiceAskRecord()
            record.id = text(row[0])
            record.question = text(row[1])
            record.answer = text(row[2])
            record.subject = text(row[3])
            record.topic = text(row[4])
            record.interestTags = jsonArray(row[5])
            record.questionType = text(row[6])
            record.grade = Grade(rawValue: text(row[7])) ?? .three
            record.audioPath = optionalText(row[8])
            record.audioDuration = int(row[9])
            record.asrStatus = VoiceAskRecord.Status(rawValue: text(row[10])) ?? .pending
            record.aiStatus = VoiceAskRecord.Status(rawValue: text(row[11])) ?? .pending
            record.safetyLevel = VoiceAskRecord.SafetyLevel(rawValue: text(row[12])) ?? .normal
            record.createdAt = date(row[13])
            return record
        }
    }

    private func loadInsights(into store: inout PersistentStore) throws {
        let rows = try query("""
        SELECT id,periodStart,periodEnd,questionCount,topSubjects,topTopics,interestTags,
               trend,childSummary,parentSummary,recommendedActivities,generatedAt
        FROM interest_insight ORDER BY generatedAt DESC
        """)
        store.insights = rows.map { row in
            InterestInsight(
                id: text(row[0]), periodStart: date(row[1]), periodEnd: date(row[2]),
                questionCount: int(row[3]), topSubjects: jsonArray(row[4]),
                topTopics: jsonArray(row[5]), interestTags: jsonArray(row[6]),
                trend: text(row[7]), childSummary: text(row[8]), parentSummary: text(row[9]),
                recommendedActivities: jsonArray(row[10]), generatedAt: date(row[11]))
        }
    }

    private func loadAnalytics(into store: inout PersistentStore) throws {
        let rows = try query("SELECT id,type,studentHash,createdAt FROM analytics_event ORDER BY createdAt DESC")
        store.analytics = rows.map { row in
            AnalyticsEvent(id: text(row[0]), type: text(row[1]),
                           studentHash: text(row[2]), createdAt: date(row[3]))
        }
    }
}
