import AVFoundation
import SwiftUI

struct VoiceAskView: View {
    private enum Phase: Equatable {
        case idle
        case recording
        case converting
        case confirm
        case thinking
        case answered
    }

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = AudioRecorderService()
    @State private var phase: Phase = .idle
    @State private var question = ""
    @State private var answer: AIVoiceAnswer?
    @State private var errorText: String = ""
    @State private var recordID = UUID().uuidString
    @State private var audioURL: URL?
    @State private var audioDuration = 0
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                hero
                if !errorText.isEmpty { ErrorBanner(message: errorText) }
                if phase == .confirm || phase == .thinking || phase == .answered {
                    questionEditor
                }
                if phase == .answered, let answer {
                    answerCard(answer)
                }
                primaryAction
                if audioURL != nil && phase != .idle {
                    Button(role: .destructive) {
                        discard()
                    } label: { Text("放弃这条录音") }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Capsule().fill(Theme.softDanger))
                }
            }
            .padding(16)
            .padding(.bottom, 25)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("问一问")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("返回") {
                    if recorder.isRecording { recorder.cancel() }
                    dismiss()
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Button {
                handleMicTap()
            } label: {
                VStack(spacing: 7) {
                    ZStack {
                        Circle().fill(Color.white.opacity(phase == .recording ? 0.18 : 0.12))
                            .frame(width: phase == .recording ? 128 : 118, height: phase == .recording ? 128 : 118)
                        Circle()
                            .fill(LinearGradient(colors: [Color(red: 1, green: 0.82, blue: 0.4), Color(red: 1, green: 0.54, blue: 0.24), Color(red: phase == .recording ? 0.78 : 0.94, green: 0.18, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 84, height: 84)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(color: Color.red.opacity(0.28), radius: 16, y: 9)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text(actionLabel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(.white))
                }
            }
            .buttonStyle(.plain)
            .disabled(busy)

            Text(stageText)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if phase == .recording {
                Text("\(recorder.elapsed) / 30 秒")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.88))
            } else {
                Text("说完整一个问题，更容易得到好答案")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.88))
            }
            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(0.65))
                        .frame(width: 5, height: phase == .recording ? (index.isMultiple(of: 2) ? 24 : 14) : 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6).repeatForever(autoreverses: true), value: phase)
                }
            }
            .frame(height: 28)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 30).fill(Theme.heroGradient))
        .shadow(color: Theme.primary.opacity(0.25), radius: 16, y: 7)
    }

    private var questionEditor: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 9) {
                Text("醒醒听到的问题")
                    .font(.system(size: 15, weight: .bold))
                TextEditor(text: $question)
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Theme.chip)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    private func answerCard(_ answer: AIVoiceAnswer) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("醒醒的回答")
                    .font(.system(size: 15, weight: .bold))
                Text(answer.answerText)
                    .font(.system(size: 15))
                    .lineSpacing(6)
                if !answer.followUpQuestion.isEmpty {
                    Text("继续想一想：\(answer.followUpQuestion)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.primary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        TagPill(text: subjectLabel(answer.subject), color: Theme.primary)
                        TagPill(text: questionTypeLabel(answer.questionType), color: Theme.gradientEnd)
                        ForEach(answer.interestTags, id: \.self) { tag in
                            TagPill(text: tag, color: Theme.secondary)
                        }
                    }
                }
            }
        }
    }

    private var primaryAction: some View {
        Button {
            handleMainAction()
        } label: {
            Text(mainActionText)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(busy || (phase == .confirm && question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
    }

    private var actionLabel: String {
        switch phase {
        case .recording: return "点这里结束录音"
        case .idle: return "点一下，开始说话"
        case .confirm: return "没听清？点这里重说"
        default: return "再问一个新的问题"
        }
    }

    private var stageText: String {
        switch phase {
        case .idle: return "点下面大麦克风，开口问一个问题"
        case .recording: return "正在听你说…"
        case .converting: return "正在转换为文字…"
        case .confirm: return "确认一下醒醒听到的问题"
        case .thinking: return "醒醒正在思考…"
        case .answered: return "回答好了，看看要不要收进好奇星球"
        }
    }

    private var mainActionText: String {
        switch phase {
        case .recording: return "说完了，保存声音"
        case .idle: return "开始录音"
        case .confirm: return "让醒醒回答"
        case .thinking: return "醒醒正在思考…"
        case .answered: return "收进好奇星球"
        case .converting: return "正在转换为文字…"
        }
    }

    private func handleMicTap() {
        if recorder.isRecording {
            recorder.stop()
        } else if phase == .answered {
            reset()
        } else {
            Task { await runRecording() }
        }
    }

    private func handleMainAction() {
        if recorder.isRecording {
            recorder.stop()
        } else if phase == .confirm {
            Task { await generateAnswer() }
        } else if phase == .answered {
            saveAnswer()
        } else {
            Task { await runRecording() }
        }
    }

    private func runRecording() async {
        reset(keepAnswer: false)
        phase = .recording
        let authorized = await SpeechTranscriptionService.requestAuthorization()
        guard authorized else {
            errorText = "未获得语音识别或麦克风权限，请到系统设置中开启后重试"
            phase = .idle
            busy = false
            return
        }

        guard let audio = await recorder.record() else {
            errorText = recorder.errorMessage ?? "录音启动失败，请检查麦克风权限后重试"
            phase = .idle
            busy = false
            return
        }
        audioURL = audio.url
        audioDuration = audio.duration
        busy = true
        phase = .converting
        do {
            // 只读取 WAV 元数据，不初始化输出 AudioQueue，避免转写期间抢占播放会话。
            let audioFile = try AVAudioFile(forReading: audio.url)
            let recordedSeconds = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            guard recordedSeconds >= 0.8 else {
                throw NSError(domain: "TiXing.Speech", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "录音太短了，请靠近麦克风再说一次"])
            }
            let text = try await SpeechTranscriptionService.transcribe(url: audio.url)
            question = text
            phase = .confirm
            if text.isEmpty {
                errorText = "没有听清孩子的问题，请靠近麦克风重新录一次"
            }
        } catch {
            let rawMessage = error.localizedDescription
            errorText = rawMessage.lowercased() == "retry" || rawMessage.isEmpty
                ? "语音识别服务暂时不可用，请再试一次；也可以手动写下问题"
                : rawMessage
            phase = .confirm
        }
        busy = false
    }

    private func generateAnswer() async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        busy = true
        errorText = ""
        phase = .thinking
        do {
            answer = try await AIService.shared.answerVoice(question: trimmed, grade: store.student.grade)
            phase = .answered
        } catch {
            errorText = error.localizedDescription
            phase = .confirm
        }
        busy = false
    }

    private func saveAnswer() {
        guard let answer else { return }
        var record = VoiceAskRecord()
        record.question = question
        record.answer = answer.answerText
        record.subject = answer.subject
        record.topic = answer.topic
        record.interestTags = answer.interestTags
        record.questionType = answer.questionType
        record.grade = store.student.grade
        record.audioPath = audioURL?.path
        record.audioDuration = audioDuration
        record.asrStatus = .done
        record.aiStatus = .done
        record.safetyLevel = answer.safetyLevel == "attention" ? .attention : .normal
        store.insert(record)
        dismiss()
    }

    private func discard() {
        if recorder.isRecording { recorder.cancel() }
        if let audioURL { try? FileManager.default.removeItem(at: audioURL) }
        reset()
    }

    private func reset(keepAnswer: Bool = false) {
        if !keepAnswer { answer = nil }
        question = ""
        errorText = ""
        audioURL = nil
        audioDuration = 0
        recordID = UUID().uuidString
        phase = .idle
        busy = false
    }

    private func subjectLabel(_ value: String) -> String {
        let map = ["math": "数学", "chinese": "语文", "english": "英语", "science": "科学",
                   "history": "历史", "geography": "地理", "technology": "科技", "life": "生活",
                   "art": "艺术", "sports": "运动"]
        return map[value] ?? "其他"
    }

    private func questionTypeLabel(_ value: String) -> String {
        let map = ["fact": "事实探索", "reason": "爱问为什么", "compare": "喜欢比较",
                   "imagine": "大胆想象", "how_to": "动手实践", "help": "求助"]
        return map[value] ?? "事实探索"
    }
}
