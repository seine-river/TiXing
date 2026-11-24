import Foundation

struct APIConfig: Codable {
    var apiKey: String?
    var api_key: String?
    var resolvedKey: String? {
        let key = apiKey ?? api_key ?? ""
        return key.hasPrefix("Bearer ") ? String(key.dropFirst(7)).trimmingCharacters(in: .whitespaces) : key
    }
}

struct AIQuestion: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var question: String
    var myAnswer: String?
    var myAnswerPresent: Bool?
    var standardAnswer: String?
    var knowledgeSummary: String?
    var subject: String?
    var answerType: String?
    var errorType: String?
    var knowledgeTags: [String]?

    private enum CodingKeys: String, CodingKey {
        case id
        case question
        case myAnswer
        case myAnswerPresent
        case standardAnswer
        case knowledgeSummary
        case subject
        case answerType
        case errorType
        case knowledgeTags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        question = try container.decode(String.self, forKey: .question)
        myAnswer = try container.decodeIfPresent(String.self, forKey: .myAnswer)
        myAnswerPresent = try container.decodeIfPresent(Bool.self, forKey: .myAnswerPresent)
        standardAnswer = try container.decodeIfPresent(String.self, forKey: .standardAnswer)
        knowledgeSummary = try container.decodeIfPresent(String.self, forKey: .knowledgeSummary)
        subject = try container.decodeIfPresent(String.self, forKey: .subject)
        answerType = try container.decodeIfPresent(String.self, forKey: .answerType)
        errorType = try container.decodeIfPresent(String.self, forKey: .errorType)
        knowledgeTags = try container.decodeIfPresent([String].self, forKey: .knowledgeTags)
        // GLM 的题目 JSON 不包含客户端生成的 id。Swift Codable 不会把属性默认值
        // 当作缺省解码值，因此必须在这里生成，否则明明识别成功也会被判为解析失败。
        id = UUID().uuidString
    }

    var domainSubject: Subject {
        Subject(rawValue: subject ?? "") ?? .math
    }
    var domainAnswerType: AnswerType {
        AnswerType(rawValue: answerType ?? "") ?? .text
    }
    var domainErrorType: ErrorType {
        ErrorType(rawValue: errorType ?? "") ?? .other
    }
}

struct AIQuestionEnvelope: Codable {
    var questionCount: Int?
    var questions: [AIQuestion]?
    var items: [AIQuestion]?
}

struct AIVoiceAnswer: Codable, Equatable {
    var answerText: String
    var normalizedQuestion: String?
    var subject: String
    var topic: String
    var interestTags: [String]
    var questionType: String
    var safetyLevel: String
    var followUpQuestion: String
}

struct AICuriosityReport: Codable, Equatable {
    var childSummary: String
    var parentSummary: String
    var recommendedActivities: [String]
    var trend: String
}

struct AILesson: Codable, Equatable {
    var title: String
    var totalDuration: Int
    var gradeLevel: String?
    var tone: String?
    var scenes: [AILessonScene]
}

struct AILessonScene: Codable, Equatable, Identifiable {
    var id: String
    var duration: Int
    var narration: String
    var subtitle: String
    var screen: AILessonScreen
    var visual: AILessonVisual?
    var animation: String?
}

struct AILessonScreen: Codable, Equatable {
    var type: String
    var title: String?
    var text: String?
    var highlight: String?
    var studentAnswer: String?
    var standardAnswer: String?
    var steps: [String]?
}

struct AILessonVisual: Codable, Equatable {
    var type: String?
    var labels: [String]?
    var numerators: [Int]?
    var denominators: [Int]?
    var resultNumerator: Int?
    var resultDenominator: Int?
    var nodes: [String]?
    var icons: [String]?
    var captions: [String]?
    var highlightIndex: Int?
}
