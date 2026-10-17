import CoreGraphics
import ImageIO
import XCTest
@testable import TiXing

final class AlignmentTests: XCTestCase {
    func testSQLiteSchemaHasHarmonyCoreTablesIndexesAndVersion() throws {
        let service = try makeService()
        XCTAssertTrue(try service.tableNames().contains("mistake"))
        XCTAssertTrue(try service.tableNames().contains("review_log"))
        XCTAssertTrue(try service.tableNames().contains("voice_ask_record"))
        XCTAssertTrue(try service.tableNames().contains("interest_insight"))
        XCTAssertEqual(service.userVersion, 3)

        let indexes = try service.indexNames()
        for expected in [
            "idx_mistake_next_review", "idx_mistake_student", "idx_review_log_mistake",
            "idx_points_log_created", "idx_analytics_event_type",
            "idx_knowledge_profile_student", "idx_voice_ask_created"
        ] {
            XCTAssertTrue(indexes.contains(expected), "missing index \(expected)")
        }
    }

    func testSQLitePersistsCoreEntitiesAndReloadsThem() throws {
        let directory = makeDirectory()
        let service = try SQLiteStoreService(
            url: directory.appendingPathComponent("test.sqlite"))

        var store = PersistentStore()
        store.hasSeededExamples = true
        var mistake = Mistake.new(question: "计算 3/8 + 1/4", subject: .math,
                                  answerType: .numeric, standardAnswer: "5/8")
        mistake.id = "sqlite-mistake"
        mistake.tags = ["分数", "加法"]
        mistake.notesImagePath = "/tmp/note.jpg"
        store.mistakes = [mistake]
        store.reviewLogs = [
            ReviewLog(id: "sqlite-review", mistakeId: mistake.id, reviewTime: Date(timeIntervalSince1970: 100),
                      correct: true, durationSeconds: 20, pointsAwarded: 10,
                      operationId: "op", subjective: true)
        ]
        store.pointsLogs = [
            PointsLog(id: "sqlite-points", action: .onTimeReview, points: 10,
                      createdAt: Date(timeIntervalSince1970: 101))
        ]
        store.voiceAsks = []
        store.knowledgeProfiles = KnowledgeProfileAggregator.aggregate(store)
        try service.save(store)

        let reloaded = try service.load()
        XCTAssertEqual(reloaded.mistakes.count, 1)
        XCTAssertEqual(reloaded.mistakes.first?.id, mistake.id)
        XCTAssertEqual(reloaded.mistakes.first?.tags, ["分数", "加法"])
        XCTAssertEqual(reloaded.mistakes.first?.notesImagePath, "/tmp/note.jpg")
        XCTAssertEqual(reloaded.reviewLogs.first?.subjective, true)
        XCTAssertEqual(reloaded.knowledgeProfiles?.count, 1)
        XCTAssertEqual(try service.rowCount("mistake"), 1)
        XCTAssertEqual(try service.rowCount("review_log"), 1)
    }

    @MainActor
    func testAppStoreMigratesLegacyJSONToSQLite() throws {
        let directory = makeDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var legacy = PersistentStore()
        var mistake = Mistake.new(question: "旧 JSON 数据", subject: .chinese,
                                  answerType: .text, standardAnswer: "答案")
        mistake.id = "legacy-mistake"
        legacy.mistakes = [mistake]
        legacy.hasSeededExamples = true
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(legacy)
        try data.write(to: directory.appendingPathComponent("store-v3.json"))

        let store = AppStore(directory: directory)
        XCTAssertEqual(store.mistakes.map(\.id), ["legacy-mistake"])
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("tixing-v3.db").path))
        XCTAssertNil(store.lastError)
    }

    func testKnowledgeProfileAggregatorGroupsTagsAndCalculatesMastery() {
        var store = PersistentStore()
        let tags = ["分数", "分数", "计算"]
        for index in 0..<3 {
            var mistake = Mistake.new(question: "题\(index)", subject: .math,
                                      answerType: .numeric, standardAnswer: "\(index)")
            mistake.id = "profile-\(index)"
            mistake.tags = [tags[index]]
            mistake.status = index == 0 ? .mastered : .unmastered
            store.mistakes.append(mistake)
        }
        let profiles = KnowledgeProfileAggregator.aggregate(store)
        XCTAssertEqual(profiles.count, 2)
        let fraction = profiles.first { $0.tag == "分数" }
        XCTAssertEqual(fraction?.totalMistakes, 2)
        XCTAssertEqual(fraction?.masteredCount, 1)
        XCTAssertEqual(fraction?.masteryScore ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(fraction?.trend, "stable")
    }

    func testSubjectiveMasteryRequiresThreeConsecutiveCorrectReviews() {
        var mistake = Mistake.new(question: "说说你的想法", subject: .chinese,
                                  answerType: .subjective, standardAnswer: "")
        mistake.firstReviewDuration = 60
        let base = Date(timeIntervalSince1970: 0)
        var twoLogs: [ReviewLog] = (0..<2).map { index in
            ReviewLog(id: "two-\(index)", mistakeId: mistake.id,
                      reviewTime: base.addingTimeInterval(Double(index) * 86_400),
                      correct: true, durationSeconds: 10, pointsAwarded: 10,
                      operationId: "op-\(index)", subjective: true)
        }
        XCTAssertEqual(ReviewAlgorithms.mastery(for: mistake, logs: twoLogs), .unmastered)

        twoLogs.append(ReviewLog(
            id: "three", mistakeId: mistake.id,
            reviewTime: base.addingTimeInterval(172_800), correct: true,
            durationSeconds: 10, pointsAwarded: 10, operationId: "op-2", subjective: true))
        XCTAssertEqual(ReviewAlgorithms.mastery(for: mistake, logs: twoLogs), .mastered)
    }

    func testImageQualityServiceDetectsDecodeFailureAndQualityIssues() {
        XCTAssertEqual(
            ImageQualityService.analyze(data: Data([1, 2, 3])).issues,
            [.decodeFailed]
        )

        let lowResolution = makeImage(width: 320, height: 240, red: 128, green: 128, blue: 128)
        let lowResolutionResult = ImageQualityService.analyze(image: lowResolution)
        XCTAssertTrue(lowResolutionResult.issues.contains(.lowResolution))
        XCTAssertFalse(lowResolutionResult.passed)

        let darkImage = makeImage(width: 800, height: 600, red: 8, green: 8, blue: 8)
        let darkResult = ImageQualityService.analyze(image: darkImage)
        XCTAssertTrue(darkResult.issues.contains(.lowLight))
        XCTAssertTrue(darkResult.passed)

        let brightImage = makeImage(width: 800, height: 600, red: 255, green: 255, blue: 255)
        let brightResult = ImageQualityService.analyze(image: brightImage)
        XCTAssertTrue(brightResult.issues.contains(.glare))
    }

    @MainActor
    func testSQLiteHandlesFiveHundredMistakesEfficiently() throws {
        let directory = makeDirectory()
        let service = try SQLiteStoreService(url: directory.appendingPathComponent("bulk.sqlite"))
        var store = PersistentStore()
        store.hasSeededExamples = true
        for index in 0..<500 {
            var mistake = Mistake.new(
                question: "压测题目 \(index) - 计算 \(index) + \(index)",
                subject: .math, answerType: .numeric, standardAnswer: "\(index * 2)")
            mistake.id = "bulk-\(index)"
            mistake.tags = ["压测"]
            store.mistakes.append(mistake)
        }
        store.knowledgeProfiles = KnowledgeProfileAggregator.aggregate(store)

        let start = Date()
        try service.save(store)
        let reloaded = try service.load()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(reloaded.mistakes.count, 500)
        XCTAssertLessThan(elapsed, 10, "500 条错题 SQLite 写入+读取耗时过长：\(elapsed) 秒")
    }

    @MainActor
    func testBackupDocumentIncludesLargeRealJPEG() throws {
        let directory = makeDirectory()
        let jpeg = try makeJPEGData(width: 1600, height: 1200)

        var store = PersistentStore()
        store.hasSeededExamples = true
        var mistake = Mistake.new(question: "真实图片备份", subject: .math,
                                  answerType: .numeric, standardAnswer: "1")
        mistake.id = "image-backup"
        store.mistakes = [mistake]

        let appStore = AppStore(directory: directory)
        appStore.replaceStorage(store)
        var persisted = store
        persisted.mistakes[0].imagePath = try appStore.saveImage(jpeg, id: "real-photo")
        appStore.replaceStorage(persisted)
        let document = BackupDocument(store: appStore)
        let archive = directory.appendingPathComponent("backup.zip")
        try document.write(to: archive)
        let entries = try ZipService.read(url: archive)
        let restored = entries["images/image-backup.jpg"]
        XCTAssertNotNil(restored)
        XCTAssertGreaterThan(restored?.count ?? 0, 100 * 1024)
        XCTAssertGreaterThan(jpeg.count, 100 * 1024)
    }

    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("TiXingAlignment-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeService() throws -> SQLiteStoreService {
        try SQLiteStoreService(url: makeDirectory().appendingPathComponent("schema.sqlite"))
    }

    private func makeImage(width: Int, height: Int, red: UInt8, green: UInt8, blue: UInt8) -> CGImage {
        let pixels = [UInt8](repeating: 0, count: width * height * 4)
        var mutablePixels = pixels
        for offset in stride(from: 0, to: mutablePixels.count, by: 4) {
            mutablePixels[offset] = red
            mutablePixels[offset + 1] = green
            mutablePixels[offset + 2] = blue
            mutablePixels[offset + 3] = 255
        }
        let context = CGContext(
            data: &mutablePixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    private func makeJPEGData(width: Int, height: Int) throws -> Data {
        let image = makeGradientImage(width: width, height: height)
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(
            output, "public.jpeg" as CFString, 1, nil)!
        CGImageDestinationAddImage(
            destination, image,
            [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func makeGradientImage(width: Int, height: Int) -> CGImage {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                pixels[offset] = UInt8((x * 255) / max(width - 1, 1))
                pixels[offset + 1] = UInt8((y * 255) / max(height - 1, 1))
                pixels[offset + 2] = UInt8(((x + y) * 127) / max(width + height - 2, 1))
                pixels[offset + 3] = 255
            }
        }
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }
}
