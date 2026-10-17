import XCTest
@testable import TiXing

final class HarmonyParityTests: XCTestCase {
    func testReviewIntervalsMatchHarmonyBaseline() {
        XCTAssertEqual(ReviewAlgorithms.intervals, [1, 3, 7, 15, 30])
    }

    func testScheduleWrongResetsIntervalAndStatus() {
        var mistake = Mistake.new(question: "题")
        mistake.intervalIndex = 4
        mistake.status = .reviewing
        ReviewAlgorithms.schedule(&mistake, correct: false)
        XCTAssertEqual(mistake.intervalIndex, 0)
        XCTAssertEqual(mistake.status, .unmastered)
        XCTAssertEqual(mistake.nextReviewDate.timeIntervalSince(Date()), 86_400, accuracy: 0.1)
    }

    func testScheduleCorrectAtMaxStaysAtMax() {
        var mistake = Mistake.new(question: "题")
        mistake.intervalIndex = 4
        ReviewAlgorithms.schedule(&mistake, correct: true)
        XCTAssertEqual(mistake.intervalIndex, 4)
        XCTAssertEqual(mistake.status, .reviewing)
        XCTAssertEqual(mistake.nextReviewDate.timeIntervalSince(Date()), 30 * 86_400, accuracy: 0.1)
    }

    func testObjectiveMasteryRequiresTwoDistinctDays() {
        let mistake = makeMistake(answerType: .text)
        let logs = makeLogs(mistakeID: mistake.id, count: 2, daysApart: 1, duration: 10)
        XCTAssertEqual(ReviewAlgorithms.mastery(for: mistake, logs: logs), .mastered)
    }

    func testObjectiveMasteryRejectsSameDay() {
        let mistake = makeMistake(answerType: .text)
        let logs = makeLogs(mistakeID: mistake.id, count: 2, daysApart: 0, duration: 10)
        XCTAssertEqual(ReviewAlgorithms.mastery(for: mistake, logs: logs), .unmastered)
    }

    func testMasteryRejectsSlowAnswers() {
        let mistake = makeMistake(answerType: .text)
        let logs = makeLogs(mistakeID: mistake.id, count: 2, daysApart: 1, duration: 59)
        XCTAssertEqual(ReviewAlgorithms.mastery(for: mistake, logs: logs), .unmastered)
    }

    func testSubjectiveMasteryRequiresThree() {
        var mistake = makeMistake(answerType: .subjective)
        mistake.standardAnswer = ""
        let logs = makeLogs(mistakeID: mistake.id, count: 3, daysApart: 1, duration: 10)
        XCTAssertEqual(ReviewAlgorithms.mastery(for: mistake, logs: logs), .mastered)
    }

    func testSubjectiveMasteryRejectsTwo() {
        var mistake = makeMistake(answerType: .subjective)
        mistake.standardAnswer = ""
        let logs = makeLogs(mistakeID: mistake.id, count: 2, daysApart: 1, duration: 10)
        XCTAssertEqual(ReviewAlgorithms.mastery(for: mistake, logs: logs), .unmastered)
    }

    func testNormalizeFullWidthDigits() {
        XCTAssertTrue(ReviewAlgorithms.isCorrect("１２３", standard: "123"))
    }

    func testNormalizePunctuation() {
        XCTAssertTrue(ReviewAlgorithms.isCorrect("１，２。", standard: "1,2."))
    }

    func testNormalizeCaseAndWhitespace() {
        XCTAssertTrue(ReviewAlgorithms.isCorrect("  A B C ", standard: "abc"))
    }

    func testUnequalAnswers() {
        XCTAssertFalse(ReviewAlgorithms.isCorrect("5/8", standard: "3/8"))
    }

    func testPointsRulesMatchHarmony() {
        XCTAssertEqual(PointsAction.capture.points, 5)
        XCTAssertEqual(PointsAction.onTimeReview.points, 10)
        XCTAssertEqual(PointsAction.masteryAchieved.points, 20)
        XCTAssertEqual(PointsAction.streak.points, 15)
        XCTAssertEqual(PointsAction.communityContribution.points, 3)
    }

    @MainActor
    func testInsertMistakeAwardsCapture() {
        let store = makeStore()
        let before = store.totalPoints
        XCTAssertTrue(store.insert(makeMistake()))
        XCTAssertEqual(store.totalPoints, before + 5)
    }

    @MainActor
    func testInsertDuplicateDoesNotDuplicate() {
        let store = makeStore()
        var mistake = makeMistake()
        mistake.id = "duplicate"
        XCTAssertTrue(store.insert(mistake))
        XCTAssertFalse(store.insert(mistake))
        XCTAssertEqual(store.mistakes.filter { $0.id == "duplicate" }.count, 1)
    }

    @MainActor
    func testUpdateMistakePersists() {
        let directory = makeDirectory()
        let store = AppStore(directory: directory)
        var mistake = makeMistake()
        mistake.id = "update-me"
        store.insert(mistake)
        mistake.notes = "更新后的笔记"
        store.update(mistake)
        let reloaded = AppStore(directory: directory)
        XCTAssertEqual(reloaded.mistake(id: "update-me")?.notes, "更新后的笔记")
    }

    @MainActor
    func testDeleteMistakeRemovesReviewLogs() {
        let store = makeStore()
        var mistake = makeMistake()
        mistake.id = "delete-me"
        store.insert(mistake)
        store.submitReview(mistakeID: mistake.id, answer: mistake.standardAnswer, duration: 10)
        store.delete(mistake)
        XCTAssertNil(store.mistake(id: mistake.id))
        XCTAssertTrue(store.reviewLogs(mistakeID: mistake.id).isEmpty)
    }

    @MainActor
    func testQueueFiltersSubjects() {
        let store = makeStore()
        var settings = store.settings
        settings.subjects = [.chinese]
        store.updateSettings(settings)
        let math = makeDueMistake(subject: .math, id: "q-math")
        let chinese = makeDueMistake(subject: .chinese, id: "q-chinese")
        store.insert(math)
        store.insert(chinese)
        XCTAssertEqual(store.todayReviewQueue.map(\.id), ["q-chinese"])
    }

    @MainActor
    func testQueueAppliesDailyLimit() {
        let store = makeStore()
        var settings = store.settings
        settings.subjects = [.math]
        settings.dailyLimit = 2
        store.updateSettings(settings)
        for index in 0..<4 {
            store.insert(makeDueMistake(subject: .math, id: "limit-\(index)"))
        }
        XCTAssertEqual(store.todayReviewQueue.count, 2)
    }

    @MainActor
    func testQueueExcludesFutureReview() {
        let store = makeStore()
        var future = makeMistake()
        future.id = "future"
        future.nextReviewDate = Date().addingTimeInterval(86_400)
        store.insert(future)
        XCTAssertFalse(store.todayReviewQueue.contains { $0.id == "future" })
    }

    @MainActor
    func testSubmitCorrectAwardsReviewPoints() {
        let store = makeStore()
        let mistake = makeMistake()
        store.insert(mistake)
        let before = store.totalPoints
        let result = store.submitReview(
            mistakeID: mistake.id, answer: mistake.standardAnswer, duration: 10)
        XCTAssertEqual(result?.correct, true)
        XCTAssertEqual(store.totalPoints, before + 25) // 10 review + 15 streak
    }

    @MainActor
    func testSubmitWrongDoesNotAwardReviewPoints() {
        let store = makeStore()
        let mistake = makeMistake()
        store.insert(mistake)
        let before = store.totalPoints
        let result = store.submitReview(mistakeID: mistake.id, answer: "错误答案", duration: 10)
        XCTAssertEqual(result?.correct, false)
        XCTAssertEqual(store.totalPoints, before + 15) // 错题不加分，但当日学习行为触发连击
    }

    @MainActor
    func testStreakAwardOnlyOncePerDay() {
        let store = makeStore()
        let first = makeDueMistake(subject: .math, id: "streak-1")
        let second = makeDueMistake(subject: .math, id: "streak-2")
        store.insert(first)
        store.insert(second)
        store.submitReview(mistakeID: first.id, answer: first.standardAnswer, duration: 10)
        store.submitReview(mistakeID: second.id, answer: second.standardAnswer, duration: 10)
        XCTAssertEqual(store.pointsLogs.filter { $0.action == .streak }.count, 1)
    }

    @MainActor
    func testMasteryAwardOnlyOnce() {
        let directory = makeDirectory()
        let store = AppStore(directory: directory)
        var mistake = makeMistake()
        mistake.id = "mastery-once"
        mistake.standardAnswer = "答案"
        store.insert(mistake)
        let oldLogs = makeLogs(mistakeID: mistake.id, count: 2, daysApart: 1, duration: 10)
        var seeded = PersistentStore()
        seeded.student = store.student
        seeded.hasSeededExamples = true
        seeded.mistakes = [mistake]
        seeded.reviewLogs = oldLogs
        seeded.pointsLogs = store.pointsLogs
        store.replaceStorage(seeded)
        store.save()
        let firstCount = store.pointsLogs.filter { $0.action == .masteryAchieved }.count
        store.submitReview(mistakeID: mistake.id, answer: "答案", duration: 10)
        XCTAssertEqual(store.pointsLogs.filter { $0.action == .masteryAchieved }.count, firstCount + 1)
    }

    @MainActor
    func testCuriosityStatsCountsTotalAndWeek() {
        let store = makeStore()
        var old = VoiceAskRecord()
        old.id = "old"
        old.createdAt = Date().addingTimeInterval(-14 * 86_400)
        var recent = VoiceAskRecord()
        recent.id = "recent"
        recent.subject = "science"
        recent.topic = "恐龙"
        store.insert(old)
        store.insert(recent)
        let stats = store.curiosityStats()
        XCTAssertEqual(stats.total, 2)
        XCTAssertEqual(stats.weekCount, 1)
        XCTAssertTrue(stats.subjects.contains { $0.key == "science" })
    }

    @MainActor
    func testBuildInsightUsesDeterministicLocalStats() {
        let store = makeStore()
        var record = VoiceAskRecord()
        record.id = "insight-record"
        record.subject = "science"
        record.topic = "太空"
        record.interestTags = ["星球"]
        store.insert(record)
        let insight = store.buildInsight(report: AICuriosityReport(
            childSummary: "孩子",
            parentSummary: "家长",
            recommendedActivities: ["去科技馆"],
            trend: "rising"))
        XCTAssertEqual(insight.questionCount, 1)
        XCTAssertEqual(insight.topSubjects, ["science"])
        XCTAssertEqual(insight.topTopics, ["太空"])
        XCTAssertEqual(insight.interestTags, ["星球"])
    }

    func testKnowledgeProfileFallsBackToSummary() {
        var store = PersistentStore()
        var mistake = makeMistake()
        mistake.tags = []
        mistake.knowledgeSummary = "分数运算"
        store.mistakes = [mistake]
        XCTAssertEqual(KnowledgeProfileAggregator.aggregate(store).first?.tag, "分数运算")
    }

    func testKnowledgeProfileDecliningTrend() {
        var store = PersistentStore()
        for index in 0..<3 {
            var mistake = makeMistake()
            mistake.tags = ["薄弱"]
            mistake.status = .unmastered
            mistake.id = "declining-\(index)"
            store.mistakes.append(mistake)
        }
        XCTAssertEqual(KnowledgeProfileAggregator.aggregate(store).first?.trend, "declining")
    }

    func testKnowledgeProfileImprovingTrend() {
        var store = PersistentStore()
        for index in 0..<3 {
            var mistake = makeMistake()
            mistake.tags = ["掌握"]
            mistake.status = .mastered
            mistake.id = "improving-\(index)"
            store.mistakes.append(mistake)
        }
        XCTAssertEqual(KnowledgeProfileAggregator.aggregate(store).first?.trend, "improving")
    }

    func testBackupSettingsRoundTrip() throws {
        var store = PersistentStore()
        store.settings.startMinutes = 510
        store.settings.endMinutes = 1230
        store.settings.dailyLimit = 15
        store.settings.subjects = [.math, .science]
        store.settings.enabled = false
        let data = try BackupCompatibility.encode(storage: store, exportedAt: Date(), studentID: store.student.id)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let raw = try decoder.decode(HarmonyBackupData.self, from: data)
        let restored = BackupCompatibility.storage(from: raw, student: store.student)
        XCTAssertEqual(restored.settings.startMinutes, 510)
        XCTAssertEqual(restored.settings.endMinutes, 1230)
        XCTAssertEqual(restored.settings.dailyLimit, 15)
        XCTAssertEqual(restored.settings.subjects, [.math, .science])
        XCTAssertFalse(restored.settings.enabled)
    }

    func testBackupVoiceAskRoundTrip() throws {
        var store = PersistentStore()
        var record = VoiceAskRecord()
        record.id = "voice-backup"
        record.question = "为什么天空是蓝色的？"
        record.answer = "因为瑞利散射。"
        record.subject = "science"
        record.topic = "天空"
        record.interestTags = ["光学", "自然"]
        record.questionType = "reason"
        record.grade = .five
        record.audioDuration = 12
        store.voiceAsks = [record]
        let data = try BackupCompatibility.encode(storage: store, exportedAt: Date(), studentID: store.student.id)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let raw = try decoder.decode(HarmonyBackupData.self, from: data)
        let restored = BackupCompatibility.storage(from: raw, student: store.student)
        XCTAssertEqual(restored.voiceAsks.first?.question, record.question)
        XCTAssertEqual(restored.voiceAsks.first?.interestTags, ["光学", "自然"])
        XCTAssertEqual(restored.voiceAsks.first?.grade, .five)
    }

    func testZipSupportsUnicodeNames() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("unicode-\(UUID().uuidString).zip")
        let data = Data("中文内容".utf8)
        try ZipService.write(entries: [("目录/中文.json", data)], to: url)
        XCTAssertEqual(try ZipService.read(url: url)["目录/中文.json"], data)
        try? FileManager.default.removeItem(at: url)
    }

    func testZipHandlesLargeBinary() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("large-\(UUID().uuidString).zip")
        var data = Data()
        for index in 0..<(512 * 1024) {
            data.append(UInt8(index % 251))
        }
        try ZipService.write(entries: [("images/large.bin", data)], to: url)
        XCTAssertEqual(try ZipService.read(url: url)["images/large.bin"], data)
        try? FileManager.default.removeItem(at: url)
    }

    func testSQLitePersistsReminderSettings() throws {
        let directory = makeDirectory()
        let service = try SQLiteStoreService(url: directory.appendingPathComponent("settings.sqlite"))
        var store = PersistentStore()
        store.settings.startMinutes = 510
        store.settings.subjects = [.math, .english]
        store.settings.enabled = false
        try service.save(store)
        let loaded = try service.load()
        XCTAssertEqual(loaded.settings.startMinutes, 510)
        XCTAssertEqual(loaded.settings.subjects, [.math, .english])
        XCTAssertFalse(loaded.settings.enabled)
    }

    func testSQLitePersistsVoiceAskAndInsight() throws {
        let directory = makeDirectory()
        let service = try SQLiteStoreService(url: directory.appendingPathComponent("voice.sqlite"))
        var store = PersistentStore()
        var voice = VoiceAskRecord()
        voice.id = "sqlite-voice"
        voice.question = "问题"
        voice.answer = "回答"
        voice.interestTags = ["标签"]
        let insight = InterestInsight(
            id: "sqlite-insight", periodStart: Date(timeIntervalSince1970: 1),
            periodEnd: Date(timeIntervalSince1970: 2), questionCount: 1,
            topSubjects: ["science"], topTopics: ["太空"], interestTags: ["星球"],
            trend: "rising", childSummary: "孩子", parentSummary: "家长",
            recommendedActivities: ["看星星"], generatedAt: Date(timeIntervalSince1970: 3))
        store.voiceAsks = [voice]
        store.insights = [insight]
        try service.save(store)
        let loaded = try service.load()
        XCTAssertEqual(loaded.voiceAsks.first?.interestTags, ["标签"])
        XCTAssertEqual(loaded.insights.first?.recommendedActivities, ["看星星"])
    }

    func testJSONExtractorSupportsArray() {
        XCTAssertEqual(JSONExtractor.firstJSON(in: "前缀 [1,2,3] 后缀"), "[1,2,3]")
    }

    func testAIErrorMessagesAreReadable() {
        XCTAssertEqual(
            AIError.timeout.errorDescription,
            "AI 处理超时，请稍后重试；如果连续出现，请缩短题目内容后再试"
        )
        XCTAssertEqual(
            AIError.network("连接中断").errorDescription,
            "网络连接失败，请检查网络后重试（连接中断）"
        )
    }

    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("HarmonyParity-\(UUID().uuidString)", isDirectory: true)
    }

    @MainActor
    private func makeStore() -> AppStore {
        AppStore(directory: makeDirectory())
    }

    private func makeMistake(answerType: AnswerType = .text) -> Mistake {
        var mistake = Mistake.new(
            question: "计算 3/8 + 1/4 = ?",
            subject: .math,
            answerType: answerType,
            standardAnswer: "5/8")
        mistake.firstReviewDuration = 60
        return mistake
    }

    private func makeDueMistake(subject: Subject, id: String) -> Mistake {
        var mistake = Mistake.new(question: "题 \(id)", subject: subject,
                                  answerType: .text, standardAnswer: "答案")
        mistake.id = id
        mistake.nextReviewDate = Date().addingTimeInterval(-60)
        return mistake
    }

    private func makeLogs(mistakeID: String, count: Int, daysApart: Int,
                          duration: Int) -> [ReviewLog] {
        (0..<count).map { index in
            ReviewLog(
                id: "log-\(index)",
                mistakeId: mistakeID,
                reviewTime: Date().addingTimeInterval(Double((count - index) * daysApart) * -86_400),
                correct: true,
                durationSeconds: duration,
                pointsAwarded: 10,
                operationId: "op-\(index)")
        }
    }
}
