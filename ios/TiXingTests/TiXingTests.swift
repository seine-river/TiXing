import AVFoundation
import XCTest
@testable import TiXing

final class TiXingTests: XCTestCase {
    func testReviewScheduleAdvancesAndResets() {
        var mistake = Mistake.new(question: "计算 3/8 + 1/4 = ?", subject: .math, answerType: .numeric, standardAnswer: "5/8")
        ReviewAlgorithms.schedule(&mistake, correct: true, now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(mistake.intervalIndex, 1)
        XCTAssertEqual(mistake.nextReviewDate, Date(timeIntervalSince1970: 3 * 86_400))

        ReviewAlgorithms.schedule(&mistake, correct: false, now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(mistake.intervalIndex, 0)
        XCTAssertEqual(mistake.status, .unmastered)
    }

    func testAnswerNormalization() {
        XCTAssertTrue(ReviewAlgorithms.isCorrect(" ５ / ８ ", standard: "5/8"))
        XCTAssertTrue(ReviewAlgorithms.isCorrect("Ａ", standard: "a"))
    }

    func testCuriosityAggregatorCounts() {
        let items = CuriosityAggregator.count(["science", "science", "life"])
        XCTAssertEqual(items.first?.key, "science")
        XCTAssertEqual(items.first?.count, 2)
    }

    func testCuriosityHistoryKeepsQuestionsAndAnswersAtReportTime() {
        var oldQuestion = VoiceAskRecord()
        oldQuestion.question = "为什么天空是蓝色？"
        oldQuestion.answer = "因为空气会散射阳光。"
        oldQuestion.createdAt = Date(timeIntervalSince1970: 100)

        var laterQuestion = VoiceAskRecord()
        laterQuestion.question = "星星晚上去哪里了？"
        laterQuestion.answer = "星星还在，只是白天太阳太亮。"
        laterQuestion.createdAt = Date(timeIntervalSince1970: 200)

        let insight = InterestInsight(
            periodStart: Date(timeIntervalSince1970: 90),
            periodEnd: Date(timeIntervalSince1970: 150),
            questionCount: 1,
            topSubjects: [], topTopics: [], interestTags: [],
            trend: "stable", childSummary: "", parentSummary: "",
            recommendedActivities: [], generatedAt: Date(timeIntervalSince1970: 150))

        let records = CuriosityAggregator.coveredRecords([oldQuestion, laterQuestion], insight: insight)
        XCTAssertEqual(records.map(\.question), ["为什么天空是蓝色？"])
        XCTAssertEqual(records.map(\.answer), ["因为空气会散射阳光。"])
    }

    func testZipRoundTrip() throws {
        let entries: [(String, Data)] = [
            ("manifest.json", Data("{\"app\":\"tixing\"}".utf8)),
            ("images/demo.jpg", Data([1, 2, 3, 4, 5]))
        ]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).zip")
        try ZipService.write(entries: entries, to: url)
        let result = try ZipService.read(url: url)
        XCTAssertEqual(result["manifest.json"], entries[0].1)
        XCTAssertEqual(result["images/demo.jpg"], entries[1].1)
        try? FileManager.default.removeItem(at: url)
    }

    func testHarmonyBackupCompatibilityRoundTrip() throws {
        var storage = PersistentStore()
        var mistake = Mistake.new(question: "一列火车每小时行驶120千米，行驶5小时后休息30分钟，一共行驶了多少千米？",
                                  subject: .math, answerType: .numeric,
                                  standardAnswer: "600千米")
        mistake.id = "compat-mistake"
        mistake.studentAnswer = "550千米"
        mistake.knowledgeSummary = "速度时间路程"
        mistake.createdAt = Date(timeIntervalSince1970: 1_760_000_000)
        storage.mistakes = [mistake]
        storage.settings.startMinutes = 510
        storage.settings.subjects = [.math, .science]

        let data = try BackupCompatibility.encode(storage: storage, exportedAt: Date(), studentID: storage.student.id)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let harmonyData = try decoder.decode(HarmonyBackupData.self, from: data)
        let restored = BackupCompatibility.storage(from: harmonyData, student: storage.student)

        XCTAssertEqual(restored.mistakes.first?.id, mistake.id)
        XCTAssertEqual(restored.mistakes.first?.studentAnswer, mistake.studentAnswer)
        XCTAssertEqual(restored.settings.startMinutes, 510)
        XCTAssertEqual(restored.settings.subjects, [.math, .science])
    }

    func testSpeechRetryErrorUsesFriendlyChineseMessage() {
        let retry = NSError(
            domain: "kAFAssistantErrorDomain",
            code: 203,
            userInfo: [NSLocalizedDescriptionKey: "retry"]
        )
        let friendly = SpeechTranscriptionService.friendlySpeechError(retry) as NSError
        XCTAssertEqual(
            friendly.localizedDescription,
            "没有听清或语音服务暂时不可用，点麦克风再说一次"
        )
    }

    func testSpeechFallbackConvertsTraditionalChineseToSimplified() {
        XCTAssertEqual(
            SpeechTranscriptionService.simplifiedChinese("家長為什麼會有這麼多心情？"),
            "家长为什么会有这么多心情？"
        )
    }

    func testVoiceAnswerDecodesNormalizedQuestion() throws {
        let data = Data("""
        {"normalizedQuestion":"天上为什么会有这么多星星？","answerText":"因为宇宙里有数不清的星星。","subject":"science","topic":"星空","interestTags":["星空"],"questionType":"reason","safetyLevel":"normal","followUpQuestion":"晚上可以和爸爸妈妈一起看星星。"}
        """.utf8)
        let answer = try JSONDecoder().decode(AIVoiceAnswer.self, from: data)
        XCTAssertEqual(answer.normalizedQuestion, "天上为什么会有这么多星星？")
    }


    func testAudioSessionErrorUsesFriendlyChineseMessage() {
        let busy = NSError(
            domain: NSOSStatusErrorDomain,
            code: AVAudioSession.ErrorCode.isBusy.rawValue
        )
        XCTAssertEqual(
            AudioSessionService.friendlyMessage(for: busy),
            "音频设备正在切换，请稍后再试"
        )
    }

    @MainActor
    func testDeferredStoreDataLoadsAfterFirstFrame() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TiXingDeferredTest-\(UUID().uuidString)", isDirectory: true)
        let first = AppStore(directory: directory)
        var record = VoiceAskRecord()
        record.id = "deferred-voice"
        record.question = "为什么天空是蓝色？"
        record.answer = "因为瑞利散射。"
        first.insert(record)

        let second = AppStore(directory: directory)
        XCTAssertTrue(second.voiceAsks.isEmpty)
        second.loadDeferredDataIfNeeded()
        XCTAssertEqual(second.voiceAsks.map(\.id), ["deferred-voice"])
        XCTAssertEqual(second.voiceAsks.first?.question, "为什么天空是蓝色？")

        try? FileManager.default.removeItem(at: directory)
    }

    @MainActor
    func testLessonProgressUsesActualSceneDurations() {
        let scenes = (0..<3).map { index in
            AILessonScene(
                id: "scene-\(index)",
                duration: [5, 4, 3][index],
                narration: "第\(index)句讲解。",
                subtitle: "第\(index)章",
                screen: AILessonScreen(type: "steps", title: "第\(index)章", steps: []),
                visual: nil,
                animation: nil)
        }
        let lesson = AILesson(
            title: "分数讲解",
            totalDuration: 999,
            gradeLevel: "三年级",
            tone: "亲切",
            scenes: scenes)
        let player = LessonPlayerModel(lesson: lesson)

        XCTAssertEqual(player.actualTotalDuration, 12)
        player.index = 1
        player.elapsed = 3
        XCTAssertEqual(player.completedSeconds, 8)
        XCTAssertEqual(player.completedFraction, 8.0 / 12.0, accuracy: 0.0001)
        XCTAssertTrue(player.canPrevious)
        XCTAssertTrue(player.canNext)

        player.elapsed = 99
        XCTAssertEqual(player.completedSeconds, 9)
        player.index = 2
        player.finished = true
        XCTAssertFalse(player.canNext)
        XCTAssertTrue(player.canPrevious)
    }

    @MainActor
    func testInitialExamplesMatchHarmonyOSBaseline() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TiXingSeedTest-\(UUID().uuidString)", isDirectory: true)
        let store = AppStore(directory: directory)

        XCTAssertEqual(store.mistakes.count, 3)
        XCTAssertEqual(store.todayReviewQueue.count, 1)
        XCTAssertEqual(store.mistakes.map(\.id), ["demo_m_03", "demo_m_01", "demo_m_02"])
        XCTAssertEqual(store.totalPoints, 45)
        XCTAssertEqual(store.mistakeStats.mastered, 1)

        try? FileManager.default.removeItem(at: directory)
    }

    @MainActor
    func testLessonSeekMapsGlobalSecondsToSceneAndElapsed() {
        let scenes = (0..<3).map { index in
            AILessonScene(
                id: "scene-\(index)",
                duration: [5, 4, 3][index],
                narration: "第\(index)句讲解。",
                subtitle: "第\(index)章",
                screen: AILessonScreen(type: "steps", title: "第\(index)章", steps: []),
                visual: nil,
                animation: nil)
        }
        let player = LessonPlayerModel(lesson: AILesson(
            title: "分数讲解",
            totalDuration: 999,
            gradeLevel: "三年级",
            tone: "亲切",
            scenes: scenes))

        player.seek(to: 7, resume: false)
        XCTAssertEqual(player.index, 1)
        XCTAssertEqual(player.elapsed, 2)
        XCTAssertEqual(player.completedSeconds, 7)
        XCTAssertFalse(player.playing)
        XCTAssertFalse(player.finished)

        player.seek(to: 9, resume: false)
        XCTAssertEqual(player.index, 2)
        XCTAssertEqual(player.elapsed, 0)

        player.seek(to: 999, resume: false)
        XCTAssertEqual(player.index, 2)
        XCTAssertEqual(player.elapsed, 3)
        XCTAssertTrue(player.finished)

        player.seek(to: 0, resume: false)
        XCTAssertEqual(player.index, 0)
        XCTAssertEqual(player.elapsed, 0)
        XCTAssertFalse(player.finished)

        player.beginSeeking()
        XCTAssertTrue(player.isSeeking)
        player.updateSeeking(to: 0.75)
        player.endSeeking()
        XCTAssertFalse(player.isSeeking)
        XCTAssertEqual(player.index, 2)
        XCTAssertEqual(player.elapsed, 0)
    }

    func testAIQuestionDecodingGeneratesIDsWhenModelOmitsID() throws {
        // GLM 返回的 questions 条目没有客户端 id；解码时必须自动生成，
        // 否则 AI 已成功识别，进入核对页前仍会误报“题目结构解析失败”。
        let raw = """
        {"questionCount":1,"questions":[{"question":"12 + 7 = ?","myAnswer":"18","myAnswerPresent":true,"standardAnswer":"19","knowledgeSummary":"20以内加法","subject":"math","answerType":"numeric","errorType":"careless","knowledgeTags":["加法"]}]}
        """
        let envelope = try JSONDecoder().decode(AIQuestionEnvelope.self, from: Data(raw.utf8))
        let questions = try XCTUnwrap(envelope.questions)

        XCTAssertEqual(questions.map(\.question), ["12 + 7 = ?"])
        XCTAssertEqual(questions.map(\.myAnswer), ["18"])
        XCTAssertEqual(questions.count, Set(questions.map(\.id)).count)
    }
}
