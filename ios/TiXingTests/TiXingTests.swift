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
            "语音识别服务暂时不可用，请再试一次；也可以手动写下问题"
        )
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
}
