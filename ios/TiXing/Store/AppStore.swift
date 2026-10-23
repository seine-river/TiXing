import Foundation

struct PersistentStore: Codable {
    var schemaVersion: Int = 3
    var student = Student()
    var mistakes: [Mistake] = []
    var reviewLogs: [ReviewLog] = []
    var pointsLogs: [PointsLog] = []
    var settings = ReminderSettings()
    var voiceAsks: [VoiceAskRecord] = []
    var insights: [InterestInsight] = []
    var analytics: [AnalyticsEvent] = []
    var redeemedItemIds: Set<String> = []
    var redemptionRecords: [RedemptionRecord]?
    var knowledgeProfiles: [KnowledgeProfile]?
    var hasSeededExamples: Bool?
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var storage: PersistentStore
    @Published var lastError: String?

    private let legacyFileURL: URL
    private let database: SQLiteStoreService?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TiXing", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        legacyFileURL = base.appendingPathComponent("store-v3.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        var initializedDatabase: SQLiteStoreService?
        var initializedStorage = PersistentStore()
        var initializationError: Error?
        do {
            let sqlite = try SQLiteStoreService(url: base.appendingPathComponent("tixing-v3.db"))
            initializedDatabase = sqlite
            var databaseIsEmpty = true
            for table in ["student", "mistake", "review_log", "points_log", "voice_ask_record",
                          "interest_insight", "reminder_settings", "redemption", "analytics_event"] {
                if try sqlite.rowCount(table) > 0 {
                    databaseIsEmpty = false
                    break
                }
            }

            if databaseIsEmpty,
               let data = try? Data(contentsOf: legacyFileURL),
               let legacy = try? decoder.decode(PersistentStore.self, from: data) {
                initializedStorage = legacy
                initializedStorage.knowledgeProfiles = KnowledgeProfileAggregator.aggregate(initializedStorage)
                try sqlite.save(initializedStorage)
            } else {
                var loaded = try sqlite.load()
                if databaseIsEmpty {
                    loaded.hasSeededExamples = nil
                }
                initializedStorage = loaded
            }
        } catch {
            initializationError = error
        }

        if initializationError != nil,
           let data = try? Data(contentsOf: legacyFileURL),
           let legacy = try? decoder.decode(PersistentStore.self, from: data) {
            initializedStorage = legacy
        }
        storage = initializedStorage
        database = initializedDatabase
        if let initializationError {
            lastError = "本地数据库初始化失败，已临时使用备用数据：\(initializationError.localizedDescription)"
        }
        seedInitialExamplesIfNeeded()
    }

    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var mistakesDirectory: URL {
        documentsDirectory.appendingPathComponent("Mistakes", isDirectory: true)
    }

    var voiceDirectory: URL {
        documentsDirectory.appendingPathComponent("VoiceAsks", isDirectory: true)
    }

    var student: Student { storage.student }
    var settings: ReminderSettings { storage.settings }
    var mistakes: [Mistake] { storage.mistakes }
    var voiceAsks: [VoiceAskRecord] { storage.voiceAsks }
    var insights: [InterestInsight] { storage.insights }
    var pointsLogs: [PointsLog] { storage.pointsLogs }
    var knowledgeProfiles: [KnowledgeProfile] { storage.knowledgeProfiles ?? [] }

    func save() {
        do {
            guard let database else {
                storage.knowledgeProfiles = KnowledgeProfileAggregator.aggregate(storage)
                let data = try encoder.encode(storage)
                try data.write(to: legacyFileURL, options: [.atomic, .completeFileProtection])
                return
            }
            storage.knowledgeProfiles = KnowledgeProfileAggregator.aggregate(storage)
            try database.save(storage)
            lastError = nil
        } catch {
            lastError = "本地数据保存失败：\(error.localizedDescription)"
        }
    }

    func replaceStorage(_ value: PersistentStore) {
        storage = value
        save()
    }

    func importBackup(_ preview: BackupPreview) {
        var incoming = preview.storage
        var existing = storage

        for var mistake in incoming.mistakes {
            guard !existing.mistakes.contains(where: { $0.id == mistake.id }) else { continue }
            if let data = preview.imageData["images/\(mistake.id).jpg"] {
                let name = "import-\(mistake.id)"
                if let path = try? saveImage(data, id: name) {
                    mistake.imagePath = path
                }
            } else {
                mistake.imagePath = nil
            }
            if let data = preview.notesImageData["notes/\(mistake.id).jpg"] {
                mistake.notesImagePath = try? saveNoteImage(data, mistakeID: mistake.id)
            } else {
                mistake.notesImagePath = nil
            }
            existing.mistakes.append(mistake)
        }

        for var record in incoming.voiceAsks {
            guard !existing.voiceAsks.contains(where: { $0.id == record.id }) else { continue }
            let wav = preview.audioData["audio/\(record.id).wav"]
            let mp3 = preview.audioData["audio/\(record.id).mp3"]
            if let data = wav ?? mp3 {
                let ext = wav == nil ? "mp3" : "wav"
                do {
                    try FileManager.default.createDirectory(at: voiceDirectory, withIntermediateDirectories: true)
                    let url = voiceDirectory.appendingPathComponent("import-\(record.id).\(ext)")
                    try data.write(to: url, options: [.atomic])
                    record.audioPath = url.path
                } catch {
                    record.audioPath = nil
                }
            } else {
                record.audioPath = nil
            }
            existing.voiceAsks.append(record)
        }

        for log in incoming.reviewLogs where !existing.reviewLogs.contains(where: { $0.id == log.id }) {
            existing.reviewLogs.append(log)
        }
        for log in incoming.pointsLogs where !existing.pointsLogs.contains(where: { $0.id == log.id }) {
            existing.pointsLogs.append(log)
        }
        for insight in incoming.insights where !existing.insights.contains(where: { $0.id == insight.id }) {
            existing.insights.append(insight)
        }
        for event in incoming.analytics where !existing.analytics.contains(where: { $0.id == event.id }) {
            existing.analytics.append(event)
        }
        let existingRedemptions = existing.redemptionRecords ?? []
        let incomingRedemptions = incoming.redemptionRecords ?? []
        var mergedRedemptions = existingRedemptions
        for record in incomingRedemptions where !existingRedemptions.contains(where: { $0.id == record.id }) {
            mergedRedemptions.append(record)
        }
        existing.redemptionRecords = mergedRedemptions
        existing.settings = incoming.settings
        existing.student = incoming.student
        existing.redeemedItemIds.formUnion(Set(mergedRedemptions.map(\.itemID)))
        existing.mistakes.sort { $0.createdAt > $1.createdAt }
        existing.voiceAsks.sort { $0.createdAt > $1.createdAt }
        incoming = existing
        storage = incoming
        save()
    }

    // MARK: - Student and settings

    /// 与 HarmonyOS 首次演示数据保持一致：空库时提供 3 条典型错题、
    /// 2 条已掌握记录和基础积分，让新用户能理解首页、错题本和复习流程。
    private func seedInitialExamplesIfNeeded() {
        if storage.hasSeededExamples == true {
            return
        }
        storage.hasSeededExamples = true

        if !storage.mistakes.isEmpty || !storage.reviewLogs.isEmpty {
            save()
            return
        }

        let now = Date()
        let sixDaysAgo = now.addingTimeInterval(-6 * 86_400)
        let threeDaysAgo = now.addingTimeInterval(-3 * 86_400)
        let twoDaysAgo = now.addingTimeInterval(-2 * 86_400)
        let yesterday = now.addingTimeInterval(-86_400)

        var train = Mistake.new(
            question: "一列火车每小时行驶 120 千米，行驶 5 小时后休息 30 分钟。这列火车一共行驶了多少千米？",
            subject: .math,
            answerType: .numeric,
            standardAnswer: "600 千米")
        train.id = "demo_m_01"
        train.studentAnswer = "550 千米"
        train.knowledgeSummary = "需要先忽略休息时间，再用“速度 × 时间 = 路程”计算。"
        train.errorType = .misread
        train.status = .reviewing
        train.intervalIndex = 1
        train.nextReviewDate = now.addingTimeInterval(-3_600)
        train.firstReviewDuration = 60
        train.createdAt = sixDaysAgo

        var fish = Mistake.new(
            question: "读一读句子：“小鱼在水里游来游去。”这句话主要写了谁在做什么？",
            subject: .chinese,
            answerType: .text,
            standardAnswer: "小鱼在水里游。")
        fish.id = "demo_m_02"
        fish.studentAnswer = "小鱼在水里游。"
        fish.knowledgeSummary = "抓住“谁 + 在哪里 + 做什么”概括句子意思。"
        fish.errorType = .other
        fish.status = .mastered
        fish.intervalIndex = 4
        fish.nextReviewDate = now.addingTimeInterval(30 * 86_400)
        fish.firstReviewDuration = 60
        fish.createdAt = now.addingTimeInterval(-20 * 86_400)

        var photosynthesis = Mistake.new(
            question: "植物进行光合作用需要吸收二氧化碳和什么气体？",
            subject: .science,
            answerType: .text,
            standardAnswer: "氧气")
        photosynthesis.id = "demo_m_03"
        photosynthesis.studentAnswer = "氮气"
        photosynthesis.knowledgeSummary = "光合作用吸收二氧化碳，释放氧气。"
        photosynthesis.errorType = .concept
        photosynthesis.status = .unmastered
        photosynthesis.nextReviewDate = now.addingTimeInterval(-1_800)
        photosynthesis.firstReviewDuration = 60
        photosynthesis.createdAt = now.addingTimeInterval(-2 * 86_400)

        storage.mistakes = [photosynthesis, train, fish]
        storage.reviewLogs = [
            ReviewLog(
                id: "demo_r_01",
                mistakeId: fish.id,
                reviewTime: threeDaysAgo,
                correct: true,
                durationSeconds: 28,
                pointsAwarded: 10,
                operationId: "demo_r_01"),
            ReviewLog(
                id: "demo_r_02",
                mistakeId: fish.id,
                reviewTime: twoDaysAgo,
                correct: true,
                durationSeconds: 22,
                pointsAwarded: 10,
                operationId: "demo_r_02"),
            ReviewLog(
                id: "demo_r_03",
                mistakeId: train.id,
                reviewTime: yesterday,
                correct: false,
                durationSeconds: 35,
                pointsAwarded: 0,
                operationId: "demo_r_03")
        ]
        storage.pointsLogs = [
            PointsLog(id: "demo_p_01", action: .capture, points: 5, createdAt: sixDaysAgo),
            PointsLog(id: "demo_p_02", action: .onTimeReview, points: 20, createdAt: twoDaysAgo),
            PointsLog(id: "demo_p_03", action: .masteryAchieved, points: 20, createdAt: yesterday)
        ]
        storage.analytics = [
            AnalyticsEvent(id: "demo_a_capture", type: "capture", studentHash: student.id.sha256Hash, createdAt: sixDaysAgo),
            AnalyticsEvent(id: "demo_a_review", type: "review_submit", studentHash: student.id.sha256Hash, createdAt: yesterday)
        ]
        save()
    }

    func updateStudent(_ value: Student) {
        storage.student = value
        save()
    }

    func updateSettings(_ value: ReminderSettings) {
        storage.settings = value
        save()
    }

    // MARK: - Mistakes

    @discardableResult
    func insert(_ mistake: Mistake) -> Bool {
        guard !storage.mistakes.contains(where: { $0.id == mistake.id }) else { return false }
        storage.mistakes.insert(mistake, at: 0)
        award(.capture, id: "capture-\(mistake.id)")
        track("capture")
        save()
        return true
    }

    func update(_ mistake: Mistake) {
        guard let index = storage.mistakes.firstIndex(where: { $0.id == mistake.id }) else { return }
        storage.mistakes[index] = mistake
        save()
    }

    func delete(_ mistake: Mistake) {
        storage.mistakes.removeAll { $0.id == mistake.id }
        storage.reviewLogs.removeAll { $0.mistakeId == mistake.id }
        if let path = mistake.imagePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        save()
    }

    func mistake(id: String) -> Mistake? {
        storage.mistakes.first { $0.id == id }
    }

    var todayReviewQueue: [Mistake] {
        let now = Date()
        return storage.mistakes
            .filter { $0.nextReviewDate <= now && $0.status != .mastered && storage.settings.subjects.contains($0.subject) }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
            .prefix(storage.settings.dailyLimit)
            .map { $0 }
    }

    var mistakeStats: (total: Int, mastered: Int, reviewing: Int, unmastered: Int) {
        let grouped = Dictionary(grouping: storage.mistakes, by: \.status)
        let mastered = grouped[.mastered]?.count ?? 0
        let reviewing = grouped[.reviewing]?.count ?? 0
        let unmastered = grouped[.unmastered]?.count ?? 0
        return (storage.mistakes.count, mastered, reviewing, unmastered)
    }

    // MARK: - Review

    struct ReviewResult: Equatable {
        var correct: Bool
        var status: MistakeStatus
        var points: Int
    }

    @discardableResult
    func submitReview(mistakeID: String, answer: String, duration: Int,
                      subjectiveCorrect: Bool? = nil) -> ReviewResult? {
        guard var mistake = mistake(id: mistakeID) else { return nil }
        let correct: Bool
        if mistake.answerType == .subjective {
            correct = subjectiveCorrect ?? false
        } else if mistake.standardAnswer.isEmpty {
            correct = subjectiveCorrect ?? false
        } else {
            correct = ReviewAlgorithms.isCorrect(answer, standard: mistake.standardAnswer)
        }

        let operationId = "review-\(UUID().uuidString)"
        if mistake.firstReviewDuration == 60 && storage.reviewLogs.filter({ $0.mistakeId == mistake.id }).isEmpty {
            mistake.firstReviewDuration = max(duration, 1)
        }
        ReviewAlgorithms.schedule(&mistake, correct: correct)

        var points = 0
        if correct {
            points += award(.onTimeReview, id: "review-\(operationId)")
        }
        if shouldAwardStreakToday {
            points += award(.streak, id: "streak-\(todayString())")
        }

        var log = ReviewLog(id: UUID().uuidString, mistakeId: mistake.id, reviewTime: Date(),
                            correct: correct, durationSeconds: duration, pointsAwarded: points,
                            operationId: operationId,
                            subjective: mistake.answerType == .subjective || subjectiveCorrect != nil)
        storage.reviewLogs.insert(log, at: 0)
        mistake.status = ReviewAlgorithms.mastery(for: mistake, logs: storage.reviewLogs)
        if mistake.status == .mastered {
            mistake.nextReviewDate = .distantFuture
            points += award(.masteryAchieved, id: "mastery-\(mistake.id)")
            log.pointsAwarded = points
        }
        update(mistake)
        track("review_submit")
        save()
        return ReviewResult(correct: correct, status: mistake.status, points: points)
    }

    func reviewLogs(mistakeID: String) -> [ReviewLog] {
        storage.reviewLogs.filter { $0.mistakeId == mistakeID }.sorted { $0.reviewTime > $1.reviewTime }
    }

    // MARK: - Points

    var totalPoints: Int {
        storage.pointsLogs.reduce(0) { $0 + $1.points } - totalSpent
    }

    var totalSpent: Int {
        (storage.redemptionRecords ?? []).reduce(0) { $0 + $1.cost }
    }

    var todayPoints: Int {
        let start = Calendar.current.startOfDay(for: Date())
        return storage.pointsLogs.filter { $0.createdAt >= start }.reduce(0) { $0 + $1.points }
    }

    var streakDays: Int {
        let days = Set(activeDays)
        var cursor = Calendar.current.startOfDay(for: Date())
        if !days.contains(cursor) {
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    private var activeDays: [Date] {
        let reviewDays = storage.reviewLogs.map { Calendar.current.startOfDay(for: $0.reviewTime) }
        let captureDays = storage.mistakes.map { Calendar.current.startOfDay(for: $0.createdAt) }
        return reviewDays + captureDays
    }

    private var shouldAwardStreakToday: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let active = Set(activeDays)
        let already = storage.pointsLogs.contains {
            $0.action == .streak && Calendar.current.isDate($0.createdAt, inSameDayAs: today)
        }
        return active.contains(today) && !already
    }

    @discardableResult
    private func award(_ action: PointsAction, id: String) -> Int {
        guard !storage.pointsLogs.contains(where: { $0.id == id }) else { return 0 }
        storage.pointsLogs.insert(PointsLog(id: id, action: action, points: action.points, createdAt: Date()), at: 0)
        return action.points
    }

    func redeem(_ item: RedeemableItem) -> Bool {
        guard totalPoints >= item.cost, !storage.redeemedItemIds.contains(item.id) else { return false }
        storage.redeemedItemIds.insert(item.id)
        storage.redemptionRecords?.append(RedemptionRecord(itemID: item.id, cost: item.cost))
        if storage.redemptionRecords == nil {
            storage.redemptionRecords = [RedemptionRecord(itemID: item.id, cost: item.cost)]
        }
        save()
        return true
    }

    func isRedeemed(_ item: RedeemableItem) -> Bool {
        storage.redeemedItemIds.contains(item.id)
            || (storage.redemptionRecords ?? []).contains { $0.itemID == item.id }
    }

    // MARK: - Voice ask and curiosity

    func insert(_ record: VoiceAskRecord) {
        storage.voiceAsks.insert(record, at: 0)
        track("voice_ask_saved")
        save()
    }

    func update(_ record: VoiceAskRecord) {
        guard let index = storage.voiceAsks.firstIndex(where: { $0.id == record.id }) else { return }
        storage.voiceAsks[index] = record
        save()
    }

    func insert(_ insight: InterestInsight) {
        storage.insights.insert(insight, at: 0)
        save()
    }

    func curiosityStats() -> CuriosityStats {
        var stats = CuriosityStats()
        stats.total = storage.voiceAsks.count
        let weekStart = Date().addingTimeInterval(-7 * 86_400)
        stats.weekCount = storage.voiceAsks.filter { $0.createdAt >= weekStart }.count
        stats.subjects = CuriosityAggregator.count(storage.voiceAsks.map(\.subject))
        stats.topics = CuriosityAggregator.count(storage.voiceAsks.map(\.topic).filter { !$0.isEmpty })
        let tags = storage.voiceAsks.flatMap { $0.interestTags }.filter { !$0.isEmpty }
        stats.tags = CuriosityAggregator.count(tags)
        return stats
    }

    func buildInsight(report: AICuriosityReport) -> InterestInsight {
        let stats = curiosityStats()
        return InterestInsight(
            periodStart: Date().addingTimeInterval(-30 * 86_400), periodEnd: Date(),
            questionCount: stats.total,
            topSubjects: stats.subjects.map(\.key),
            topTopics: stats.topics.map(\.key),
            interestTags: stats.tags.map(\.key),
            trend: report.trend, childSummary: report.childSummary,
            parentSummary: report.parentSummary,
            recommendedActivities: report.recommendedActivities,
            generatedAt: Date())
    }

    // MARK: - Files and events

    func saveImage(_ data: Data, id: String) throws -> String {
        try FileManager.default.createDirectory(at: mistakesDirectory, withIntermediateDirectories: true)
        let url = mistakesDirectory.appendingPathComponent("\(id).jpg")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url.path
    }

    func saveNoteImage(_ data: Data, mistakeID: String) throws -> String {
        try FileManager.default.createDirectory(at: mistakesDirectory, withIntermediateDirectories: true)
        let url = mistakesDirectory.appendingPathComponent("note-\(mistakeID)-\(UUID().uuidString).jpg")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url.path
    }

    func track(_ type: String) {
        let hash = student.id.sha256Hash
        storage.analytics.insert(AnalyticsEvent(type: type, studentHash: hash), at: 0)
        if storage.analytics.count > 1_000 {
            storage.analytics.removeLast(storage.analytics.count - 1_000)
        }
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

enum CuriosityAggregator {
    static func count(_ values: [String]) -> [CuriosityStats.CountItem] {
        Dictionary(grouping: values, by: { $0 }).map { key, list in
            CuriosityStats.CountItem(key: key, count: list.count)
        }
        .sorted { lhs, rhs in
            lhs.count == rhs.count ? lhs.key < rhs.key : lhs.count > rhs.count
        }
    }
}

enum KnowledgeProfileAggregator {
    static func aggregate(_ store: PersistentStore, now: Date = Date()) -> [KnowledgeProfile] {
        struct Key: Hashable {
            let studentID: String
            let tag: String
        }

        let grouped = Dictionary(grouping: store.mistakes) { mistake -> Key in
            let tags = mistake.tags.filter { !$0.isEmpty }
            let tag = tags.first ?? (mistake.knowledgeSummary.isEmpty ? "未分类" : mistake.knowledgeSummary)
            return Key(studentID: mistake.studentId, tag: tag)
        }

        return grouped.map { key, mistakes in
            let mastered = mistakes.filter { $0.status == .mastered }.count
            let score = mistakes.isEmpty ? 0 : Double(mastered) / Double(mistakes.count)
            let trend = score >= 0.7 ? "improving" : (score >= 0.35 ? "stable" : "declining")
            let digest = "\(key.studentID)-\(key.tag)".sha256Hash.prefix(24)
            return KnowledgeProfile(
                id: "kp-\(digest)",
                studentID: key.studentID,
                tag: key.tag,
                totalMistakes: mistakes.count,
                masteredCount: mastered,
                masteryScore: score,
                trend: trend,
                updatedAt: now)
        }
        .sorted { lhs, rhs in
            if lhs.masteryScore == rhs.masteryScore {
                return lhs.tag < rhs.tag
            }
            return lhs.masteryScore < rhs.masteryScore
        }
    }
}
