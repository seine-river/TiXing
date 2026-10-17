import Foundation

enum Subject: String, Codable, CaseIterable, Identifiable, Hashable {
    case math, chinese, english, science
    var id: String { rawValue }

    var label: String {
        switch self {
        case .math: return "数学"
        case .chinese: return "语文"
        case .english: return "英语"
        case .science: return "科学"
        }
    }

    var emoji: String {
        switch self {
        case .math: return "🔢"
        case .chinese: return "📖"
        case .english: return "🇬🇧"
        case .science: return "🔬"
        }
    }
}

enum Grade: String, Codable, CaseIterable, Identifiable {
    case three = "3", four = "4", five = "5", six = "6"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .three: return "三年级"
        case .four: return "四年级"
        case .five: return "五年级"
        case .six: return "六年级"
        }
    }
}

enum TextbookVersion: String, Codable, CaseIterable, Identifiable {
    case pep, bj, su, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .pep: return "人教版"
        case .bj: return "北师大版"
        case .su: return "苏教版"
        case .other: return "其他教材"
        }
    }
}

enum ErrorType: String, Codable, CaseIterable, Identifiable {
    case concept, careless, misread, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .concept: return "概念不清"
        case .careless: return "粗心"
        case .misread: return "审题错误"
        case .other: return "其他"
        }
    }
}

enum MistakeStatus: String, Codable, CaseIterable, Identifiable {
    case unmastered, reviewing, mastered
    var id: String { rawValue }
    var label: String {
        switch self {
        case .unmastered: return "未掌握"
        case .reviewing: return "复习中"
        case .mastered: return "已掌握"
        }
    }
}

enum AnswerType: String, Codable, CaseIterable, Identifiable {
    case choice, numeric, text, subjective
    var id: String { rawValue }
    var label: String {
        switch self {
        case .choice: return "选择题"
        case .numeric: return "数字题"
        case .text: return "文本题"
        case .subjective: return "主观题"
        }
    }
}

enum PointsAction: String, Codable, CaseIterable {
    case capture, onTimeReview = "on_time_review", masteryAchieved = "mastery_achieved"
    case streak, communityContribution = "community_contribution"

    var points: Int {
        switch self {
        case .capture: return 5
        case .onTimeReview: return 10
        case .masteryAchieved: return 20
        case .streak: return 15
        case .communityContribution: return 3
        }
    }
}

struct Student: Codable, Identifiable, Equatable {
    var id: String = "stu_default"
    var nickname: String = "同学"
    var grade: Grade = .three
    var textbookVersion: TextbookVersion = .pep
    var createdAt: Date = Date()
}

struct Mistake: Codable, Identifiable, Equatable {
    var id: String
    var studentId: String = "stu_default"
    var imagePath: String?
    var question: String
    var studentAnswer: String = ""
    var standardAnswer: String = ""
    var knowledgeSummary: String = ""
    var subject: Subject = .math
    var answerType: AnswerType = .text
    var errorType: ErrorType = .other
    var tags: [String] = []
    var status: MistakeStatus = .unmastered
    var intervalIndex: Int = 0
    var nextReviewDate: Date = Date().addingTimeInterval(86_400)
    var firstReviewDuration: Int = 60
    var notes: String = ""
    var notesImagePath: String?
    var createdAt: Date = Date()

    static func new(question: String, subject: Subject = .math,
                    answerType: AnswerType = .text, standardAnswer: String = "") -> Mistake {
        var mistake = Mistake(id: UUID().uuidString, question: question)
        mistake.subject = subject
        mistake.answerType = answerType
        mistake.standardAnswer = standardAnswer
        return mistake
    }
}

struct ReviewLog: Codable, Identifiable, Equatable {
    var id: String
    var mistakeId: String
    var reviewTime: Date
    var correct: Bool
    var durationSeconds: Int
    var pointsAwarded: Int
    var operationId: String
    var subjective: Bool = false

    init(id: String, mistakeId: String, reviewTime: Date, correct: Bool,
         durationSeconds: Int, pointsAwarded: Int, operationId: String,
         subjective: Bool = false) {
        self.id = id
        self.mistakeId = mistakeId
        self.reviewTime = reviewTime
        self.correct = correct
        self.durationSeconds = durationSeconds
        self.pointsAwarded = pointsAwarded
        self.operationId = operationId
        self.subjective = subjective
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        mistakeId = try container.decode(String.self, forKey: .mistakeId)
        reviewTime = try container.decode(Date.self, forKey: .reviewTime)
        correct = try container.decode(Bool.self, forKey: .correct)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        pointsAwarded = try container.decode(Int.self, forKey: .pointsAwarded)
        operationId = try container.decode(String.self, forKey: .operationId)
        subjective = try container.decodeIfPresent(Bool.self, forKey: .subjective) ?? false
    }
}

struct KnowledgeProfile: Codable, Identifiable, Equatable {
    var id: String
    var studentID: String
    var tag: String
    var totalMistakes: Int
    var masteredCount: Int
    var masteryScore: Double
    var trend: String
    var updatedAt: Date
}

struct PointsLog: Codable, Identifiable, Equatable {
    var id: String
    var action: PointsAction
    var points: Int
    var createdAt: Date
}

struct RedemptionRecord: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var itemID: String
    var cost: Int
    var redeemedAt: Date = Date()
}

struct ReminderSettings: Codable, Equatable {
    var startMinutes: Int = 8 * 60
    var endMinutes: Int = 21 * 60
    var dailyLimit: Int = 10
    var subjects: Set<Subject> = [.math, .chinese]
    var enabled: Bool = true
}

struct VoiceAskRecord: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var question: String = ""
    var answer: String = ""
    var subject: String = "other"
    var topic: String = ""
    var interestTags: [String] = []
    var questionType: String = "fact"
    var grade: Grade = .three
    var audioPath: String?
    var audioDuration: Int = 0
    var asrStatus: Status = .pending
    var aiStatus: Status = .pending
    var safetyLevel: SafetyLevel = .normal
    var createdAt: Date = Date()

    enum Status: String, Codable { case pending, processing, done, failed }
    enum SafetyLevel: String, Codable { case normal, attention }
}

struct InterestInsight: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var periodStart: Date
    var periodEnd: Date
    var questionCount: Int
    var topSubjects: [String]
    var topTopics: [String]
    var interestTags: [String]
    var trend: String
    var childSummary: String
    var parentSummary: String
    var recommendedActivities: [String]
    var generatedAt: Date
}

struct AnalyticsEvent: Codable, Identifiable {
    var id: String = UUID().uuidString
    var type: String
    var studentHash: String
    var createdAt: Date = Date()
}

struct RedeemableItem: Identifiable, Hashable {
    let id: String
    let emoji: String
    let name: String
    let category: String
    let cost: Int
}

struct CuriosityStats: Equatable {
    var total: Int = 0
    var weekCount: Int = 0
    var subjects: [CountItem] = []
    var topics: [CountItem] = []
    var tags: [CountItem] = []

    struct CountItem: Equatable, Identifiable {
        var id: String { key }
        let key: String
        let count: Int
    }
}

enum ReviewAlgorithms {
    static let intervals: [Int] = [1, 3, 7, 15, 30]

    static func schedule(_ mistake: inout Mistake, correct: Bool, now: Date = Date()) {
        if correct {
            mistake.intervalIndex = min(mistake.intervalIndex + 1, intervals.count - 1)
            mistake.status = .reviewing
        } else {
            mistake.intervalIndex = 0
            mistake.status = .unmastered
        }
        mistake.nextReviewDate = now.addingTimeInterval(Double(intervals[mistake.intervalIndex]) * 86_400)
        if mistake.status == .mastered { mistake.nextReviewDate = .distantFuture }
    }

    static func mastery(for mistake: Mistake, logs: [ReviewLog]) -> MistakeStatus {
        let relevant = logs.filter { $0.mistakeId == mistake.id }.sorted { $0.reviewTime > $1.reviewTime }
        let required = mistake.answerType == .subjective ? 3 : 2
        guard relevant.count >= required else { return .unmastered }
        let recent = Array(relevant.prefix(required))
        guard recent.allSatisfy(\.correct) else { return .unmastered }
        let days = Set(recent.map { Calendar.current.startOfDay(for: $0.reviewTime) })
        guard days.count >= 2 else { return .unmastered }
        let baseline = mistake.firstReviewDuration > 0 ? mistake.firstReviewDuration : 60
        guard recent.allSatisfy({ $0.durationSeconds <= Int(Double(baseline) * 0.6) }) else { return .unmastered }
        return .mastered
    }

    static func normalizeAnswer(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let map: [Character: Character] = [
            "（": "(", "）": ")", "：": ":", "，": ",", "。": ".",
            "１": "1", "２": "2", "３": "3", "４": "4", "５": "5",
            "６": "6", "７": "7", "８": "8", "９": "9", "０": "0"
        ]
        let mapped = trimmed.map { character -> Character in
            if let scalar = character.unicodeScalars.first,
               scalar.value >= 0xFF01 && scalar.value <= 0xFF5E,
               let normalized = UnicodeScalar(scalar.value - 0xFEE0) {
                return Character(normalized)
            }
            return map[character] ?? character
        }
        return String(mapped.filter { !$0.isWhitespace })
    }

    static func isCorrect(_ answer: String, standard: String) -> Bool {
        normalizeAnswer(answer) == normalizeAnswer(standard)
    }
}
