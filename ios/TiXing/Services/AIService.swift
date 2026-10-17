import Foundation
import ImageIO
import os.log
import UniformTypeIdentifiers

private let aiLogger = Logger(subsystem: "com.tixing.me.ios", category: "AIService")

enum AIError: LocalizedError {
    case notConfigured
    case invalidResponse(String)
    case server(String)
    case parsing(String)
    case timeout
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI 未配置：请在 iOS 构建的 apiconfig.json 中配置 apiKey"
        case .invalidResponse(let summary):
            return "AI 返回异常：\(summary)"
        case .server(let message):
            return message
        case .parsing(let message):
            return "AI 返回格式异常：\(message)"
        case .timeout:
            return "AI 处理超时，请稍后重试；如果连续出现，请缩短题目内容后再试"
        case .network(let message):
            return "网络连接失败，请检查网络后重试（\(message)）"
        }
    }
}

struct AIService {
    static let shared = AIService()
    private let config: APIConfig
    private let session: URLSession
    private let endpoint = URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions")!
    private let model = "glm-5.3-flash"

    private init(session: URLSession = .shared) {
        self.session = session
        if let url = Bundle.main.url(forResource: "apiconfig", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            config = (try? JSONDecoder().decode(APIConfig.self, from: data)) ?? APIConfig()
        } else {
            config = APIConfig()
        }
    }

    var configured: Bool {
        (config.resolvedKey ?? "").isEmpty == false
    }

    enum ContentPart: Encodable {
        case text(String)
        case imageURL(String)

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let value):
                try container.encode("text", forKey: .type)
                try container.encode(value, forKey: .text)
            case .imageURL(let value):
                try container.encode("image_url", forKey: .type)
                try container.encode(["url": value], forKey: .imageURL)
            }
        }

        enum CodingKeys: String, CodingKey {
            case type, text
            case imageURL = "image_url"
        }
    }

    private struct RequestBody: Encodable {
        struct Message: Encodable {
            let role: String
            let content: [ContentPart]
        }
        struct Thinking: Encodable {
            let type = "enabled"
            let clearThinking = false
            enum CodingKeys: String, CodingKey {
                case type
                case clearThinking = "clear_thinking"
            }
        }
        let model: String
        let messages: [Message]
        let temperature: Double
        let maxTokens: Int
        let thinking: Thinking
        let reasoningEffort: String

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature, thinking
            case maxTokens = "max_tokens"
            case reasoningEffort = "reasoning_effort"
        }
    }

    private struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
            let finishReason: String?

            enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }
        let choices: [Choice]
        let usage: Usage?
    }

    private struct Usage: Decodable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }

    func recognizeQuestions(imageData: Data) async throws -> [AIQuestion] {
        let base64 = ImageResizer.jpegData(from: imageData, maxDimension: 1800).base64EncodedString()
        let prompt = """
这是一张小学生作业或试卷照片，可能只有一道题，也可能包含多道题，还包含学生手写作答和批改痕迹。请仔细看图，按题号把每道题拆开识别，并以纯JSON返回，不要markdown代码块和解释。
返回格式：{"questionCount":题目数量,"questions":[{"question":"这一道题的完整题干，保留题号、共用材料和选项","myAnswer":"这一道题对应的学生作答，没有则为空字符串","myAnswerPresent":true或false,"standardAnswer":"这一道题可见的正确答案或批改结果，看不出则为空字符串","knowledgeSummary":"不超过10个汉字的知识点名称","subject":"math或chinese或english或science","answerType":"choice或numeric或text或subjective","errorType":"concept或careless或misread或other","knowledgeTags":["标签1","标签2"]}]}
多题拆分要求：必须按可见题号、题目间距或版式把图片拆成多道题；每道题只归属自己下方或旁边的学生答案；如果多道小题共享阅读材料或题干，每道题的question都要带上必要的共用材料；不要把多道题合并成一个长字符串；只有确实看不出任何题目时questions才返回空数组。
学生答案识别要求：小学生答案通常写在题目下方、横线上、括号内或题目留白处，笔迹常与印刷题干不同。myAnswer必须原样转写学生写的算式、字母、汉字、选项和结果，不要混入题干、教师批注或标准答案。
"""
        let raw = try await request(parts: [
            .imageURL("data:image/jpeg;base64,\(base64)"),
            .text(prompt)
        ], maxTokens: 8192)
        let json = JSONExtractor.firstJSON(in: raw)
        guard let data = json.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(AIQuestionEnvelope.self, from: data) else {
            throw AIError.parsing("题目结构解析失败")
        }
        return envelope.questions ?? envelope.items ?? []
    }

    func answerVoice(question: String, grade: Grade) async throws -> AIVoiceAnswer {
        let prompt = """
你是一个叫醒醒的儿童学习伙伴，回答小学生通过语音提出的问题。请语气亲切、鼓励、简明，符合给定年级；如果问题不完整，请合理补全；如果涉及危险、隐私、身体健康或情绪困扰，要温和建议请家长一起处理。
学生年级：\(grade.rawValue)年级
问题：\(question)
请只返回纯JSON，不要markdown代码块：{"answerText":"给孩子的回答，120-220字","subject":"math/chinese/english/science/history/geography/technology/life/art/sports/other","topic":"8字以内主题","interestTags":["兴趣标签1","兴趣标签2"],"questionType":"fact/reason/compare/imagine/how_to/help","safetyLevel":"normal/attention","followUpQuestion":"一个适合孩子继续思考的问题"}。字段名必须使用英文。
"""
        let raw = try await request(parts: [.text(prompt)], maxTokens: 4096)
        return try decode(raw)
    }

    func curiosityReport(records: [VoiceAskRecord], grade: Grade) async throws -> AICuriosityReport {
        let lines = records.prefix(100).enumerated().map { index, record in
            "\(index + 1). \(record.question) | subject=\(record.subject) | topic=\(record.topic)"
        }.joined(separator: "\n")
        let prompt = """
请根据小学生的历史提问生成“好奇星球”兴趣报告。孩子视角要有趣、正向、具体；家长视角要冷静、可操作，不做负面评价。
学生年级：\(grade.rawValue)年级
提问数量：\(records.count)
最近提问：
\(lines)
只返回纯JSON：{"childSummary":"给孩子看的趣味总结，80-150字","parentSummary":"给家长看的观察和建议，100-180字","recommendedActivities":["活动建议1","活动建议2","活动建议3"],"trend":"rising/stable/cooling"}。字段名必须使用英文。
"""
        let raw = try await request(parts: [.text(prompt)], maxTokens: 4096)
        return try decode(raw)
    }

    func lesson(mistake: Mistake, grade: Grade) async throws -> AILesson {
        let prompt = """
请为一个小学生错题生成App内动画讲解视频脚本。脚本必须根据学生年级调整语言难度，语气亲切、鼓励，不批评孩子。
学生年级：\(grade.rawValue)年级
学科：\(mistake.subject.label)
知识点：\(mistake.knowledgeSummary)
错误类型：\(mistake.errorType.rawValue)
题目：\(mistake.question)
学生答案：\(mistake.studentAnswer.isEmpty ? "未提供" : mistake.studentAnswer)
标准答案：\(mistake.standardAnswer.isEmpty ? "未提供" : mistake.standardAnswer)
生成要求：
1. 4-6个scenes，总时长35-55秒，优先精炼。
2. 结构包含：亲切开场、读题、理解学生答案、定位错误原因、正确解法分步讲解、检查答案、鼓励总结。
3. narration每句不超过38个中文字；subtitle不超过12个中文字。
4. 数学步骤拆小，每步只讲一个动作；其他学科用适合年级的方式解释。
5. screen.type只能是cover/question/compare/steps/tip。
6. steps场景的screen.steps放2-3条短步骤。
7. 每个screen必须带visual字段。visual.type只能是fraction_bars/number_line/counters/arrow_flow/shape_combo/icon_story。
8. 不得编造题目没有的信息。
9. 只输出纯JSON，不要markdown代码块和解释。
返回格式：{"title":"不超过10字","totalDuration":45,"gradeLevel":"三年级","tone":"亲切鼓励","scenes":[{"id":"intro","duration":5,"narration":"...","subtitle":"...","screen":{"type":"steps","title":"...","steps":["..."]},"visual":{"type":"arrow_flow","nodes":["..."]},"animation":"step_in"}]}
"""
        let raw = try await request(parts: [.text(prompt)], maxTokens: 4096)
        return try decode(raw)
    }

    private func request(parts: [ContentPart], maxTokens: Int) async throws -> String {
        guard let key = config.resolvedKey, !key.isEmpty else { throw AIError.notConfigured }
        let requestID = UUID().uuidString.prefix(8)
        let startedAt = Date()
        var request = URLRequest(url: endpoint, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let body = RequestBody(
            model: model,
            messages: [.init(role: "user", content: parts)],
            temperature: 0.1,
            maxTokens: maxTokens,
            thinking: .init(),
            reasoningEffort: "low")
        request.httpBody = try JSONEncoder().encode(body)
        let bodySize = request.httpBody?.count ?? 0
        aiLogger.info(
            "AI request start: id=\(requestID, privacy: .public), model=\(self.model, privacy: .public), parts=\(parts.count), maxTokens=\(maxTokens), bodyBytes=\(bodySize)"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let nsError = error as NSError
            aiLogger.error(
                "AI transport failed: id=\(requestID, privacy: .public), domain=\(nsError.domain, privacy: .public), code=\(nsError.code), message=\(nsError.localizedDescription, privacy: .public)"
            )
            if nsError.code == NSURLErrorTimedOut {
                throw AIError.timeout
            }
            throw AIError.network(nsError.localizedDescription)
        }
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let text = String(data: data, encoding: .utf8) ?? ""
        aiLogger.info(
            "AI response received: id=\(requestID, privacy: .public), http=\(statusCode), bodyBytes=\(data.count), elapsedMs=\(Int(Date().timeIntervalSince(startedAt) * 1000))"
        )
        guard statusCode == 200 else {
            aiLogger.error(
                "AI HTTP error: id=\(requestID, privacy: .public), http=\(statusCode), body=\(String(text.prefix(1200)), privacy: .public)"
            )
            throw AIError.server(friendlyHTTP(statusCode: statusCode, body: text))
        }
        guard let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data),
              let firstChoice = decoded.choices.first,
              let content = firstChoice.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            aiLogger.error(
                "AI response invalid: id=\(requestID, privacy: .public), body=\(String(text.prefix(1200)), privacy: .public)"
            )
            throw AIError.invalidResponse(String(text.prefix(180)))
        }
        let usage = decoded.usage
        aiLogger.info(
            "AI choice parsed: id=\(requestID, privacy: .public), choices=\(decoded.choices.count), finish=\(firstChoice.finishReason ?? "unknown", privacy: .public), contentLength=\(content.count), promptTokens=\(usage?.promptTokens ?? -1), completionTokens=\(usage?.completionTokens ?? -1), totalTokens=\(usage?.totalTokens ?? -1)"
        )
        return content
    }

    private func decode<T: Decodable>(_ raw: String, as type: T.Type = T.self) throws -> T {
        let json = JSONExtractor.firstJSON(in: raw)
        guard let data = json.data(using: .utf8) else { throw AIError.parsing("无法提取JSON") }
        do {
            let value = try JSONDecoder().decode(T.self, from: data)
            aiLogger.info("AI structured decode succeeded: type=\(String(describing: T.self), privacy: .public)")
            return value
        } catch {
            aiLogger.error(
                "AI structured decode failed: type=\(String(describing: T.self), privacy: .public), error=\(String(describing: error), privacy: .public), jsonLength=\(json.count)"
            )
            throw AIError.parsing(String(describing: error))
        }
    }

    private func friendlyHTTP(statusCode: Int, body: String) -> String {
        if body.contains("1113") || body.contains("余额不足") || body.contains("资源包") {
            return "AI 服务余额不足或没有可用资源包，请到智谱开放平台充值或开通资源包"
        }
        if statusCode == 401 || statusCode == 403 || body.contains("1000") || body.contains("身份验证失败") {
            return "AI 身份验证失败，请检查 API Key 是否正确、过期或无权限"
        }
        if statusCode >= 500 { return "AI 服务暂时不可用，请稍后重试" }
        return "AI 请求失败（HTTP \(statusCode)），请稍后重试"
    }
}

enum JSONExtractor {
    static func firstJSON(in raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            let body = lines.dropFirst().dropLast().joined(separator: "\n")
            if body.contains("{") { return body }
        }
        guard let objectStart = text.firstIndex(where: { $0 == "{" || $0 == "[" }) else { return text }
        let objectChar = text[objectStart]
        let endChar: Character = objectChar == "{" ? "}" : "]"
        guard let end = text.lastIndex(of: endChar), end > objectStart else { return text }
        return String(text[objectStart...end])
    }
}

enum ImageResizer {
    static func jpegData(from data: Data, maxDimension: CGFloat) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return data }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let longest = max(width, height)
        guard longest > maxDimension else { return data }
        let scale = maxDimension / longest
        let newSize = CGSize(width: floor(width * scale), height: floor(height * scale))
        guard let context = CGContext(
            data: nil, width: Int(newSize.width), height: Int(newSize.height),
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return data }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: newSize))
        guard let resized = context.makeImage() else { return data }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return data }
        CGImageDestinationAddImage(destination, resized, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return data }
        return output as Data
    }
}
