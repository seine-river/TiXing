import AVFoundation
import os.log
import SwiftUI

private let voiceAskLogger = Logger(subsystem: "com.tixing.me.ios", category: "VoiceAsk")

struct VoiceAskView: View {
    private enum Phase: Equatable {
        case idle
        case recording
        case converting
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
    @State private var audioURL: URL?
    @State private var audioDuration = 0
    @State private var busy = false
    @State private var voiceTask: Task<Void, Never>?
    @State private var answerSaved = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                hero
                if !errorText.isEmpty {
                    ErrorBanner(message: errorText, title: "语音遇到一点小问题")
                }
                if let answer {
                    resultCard(answer)
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
                    abandonAndDismiss()
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

    private func resultCard(_ answer: AIVoiceAnswer) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("醒醒听到的问题")
                    .font(.system(size: 15, weight: .bold))
                Text(question)
                    .font(.system(size: 15))
                    .lineSpacing(6)

                Text("醒醒的回答")
                    .font(.system(size: 15, weight: .bold))
                    .padding(.top, 4)
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
                        TagPill(text: subjectName(answer.subject), color: Theme.primary)
                        TagPill(text: questionTypeName(answer.questionType), color: Theme.gradientEnd)
                        ForEach(answer.interestTags, id: \.self) { tag in
                            TagPill(text: tag, color: Theme.secondary)
                        }
                    }
                }
            }
        }
    }

    private var stageText: String {
        switch phase {
        case .idle: return "开口问一个问题"
        case .recording: return "正在听你说…"
        case .converting: return "正在转换为文字…"
        case .thinking: return "醒醒正在思考…"
        case .answered: return "看看醒醒的回答吧"
        }
    }

    private func handleMicTap() {
        if recorder.isRecording {
            recorder.stop()
        } else {
            voiceTask?.cancel()
            voiceTask = Task { await runRecording() }
        }
    }

    private func runRecording() async {
        if let audioURL, !answerSaved {
            try? FileManager.default.removeItem(at: audioURL)
        }
        reset(keepAnswer: false)
        phase = .recording
        let authorized = await SpeechTranscriptionService.requestAuthorization()
        guard authorized else {
            ObservabilityService.shared.reportError(name: "voice.permission", message: "Speech or microphone permission denied")
            errorText = "未获得语音识别或麦克风权限，请到系统设置中开启后重试"
            phase = .idle
            busy = false
            return
        }

        guard let audio = await recorder.record() else {
            ObservabilityService.shared.reportError(name: "voice.record", message: recorder.errorMessage ?? "Recorder failed")
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
            if Task.isCancelled { return }
            question = text
            if text.isEmpty {
                phase = .idle
                ObservabilityService.shared.track(kind: .metric, name: "voice_transcription", attributes: ["success": "0", "stage": "empty"])
                errorText = "没有听清孩子的问题，点麦克风再说一次"
                busy = false
                return
            }

            busy = false
            await generateAnswer()
            if Task.isCancelled { return }
            if answer != nil {
                saveAnswer()
            }
        } catch {
            guard !Task.isCancelled else {
                phase = .idle
                return
            }
            let nsError = error as NSError
            ObservabilityService.shared.track(kind: .metric, name: "voice_transcription", attributes: [
                "success": "0", "stage": "pipeline", "error_code": String(nsError.code)
            ])
            ObservabilityService.shared.reportError(name: "voice.pipeline", message: nsError.localizedDescription,
                                                    detail: "stage=pipeline code=\(nsError.code)")
            voiceAskLogger.error(
                "voice ask pipeline failed: domain=\(nsError.domain, privacy: .public), code=\(nsError.code), message=\(nsError.localizedDescription, privacy: .public)"
            )
            errorText = nsError.localizedDescription
            phase = .idle
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
            if let normalized = answer?.normalizedQuestion?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !normalized.isEmpty {
                question = normalized
            }
            ObservabilityService.shared.track(kind: .metric, name: "voice_answer", attributes: ["success": "1"])
            phase = .answered
        } catch {
            let nsError = error as NSError
            ObservabilityService.shared.track(kind: .metric, name: "voice_answer", attributes: [
                "success": "0", "error_code": String(nsError.code)
            ])
            ObservabilityService.shared.reportError(name: "voice.ai", message: nsError.localizedDescription,
                                                    detail: "stage=answer code=\(nsError.code)")
            voiceAskLogger.error(
                "voice ask AI failed: domain=\(nsError.domain, privacy: .public), code=\(nsError.code), message=\(nsError.localizedDescription, privacy: .public)"
            )
            phase = .idle
            errorText = nsError.localizedDescription
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
        answerSaved = true
        phase = .answered
    }

    private func abandonAndDismiss() {
        if answerSaved {
            dismiss()
            return
        }
        voiceTask?.cancel()
        if recorder.isRecording { recorder.cancel() }
        if let audioURL { try? FileManager.default.removeItem(at: audioURL) }
        reset()
        dismiss()
    }

    private func reset(keepAnswer: Bool = false) {
        if !keepAnswer { answer = nil }
        question = ""
        errorText = ""
        audioURL = nil
        audioDuration = 0
        answerSaved = false
        phase = .idle
        busy = false
    }

    private func subjectName(_ value: String) -> String {
        let map = ["math": "数学", "chinese": "语文", "english": "英语", "science": "科学",
                   "history": "历史", "geography": "地理", "technology": "科技", "life": "生活",
                   "art": "艺术", "sports": "运动"]
        return map[value] ?? "其他"
    }

    private func questionTypeName(_ value: String) -> String {
        let map = ["fact": "事实探索", "reason": "爱问为什么", "compare": "喜欢比较",
                   "imagine": "大胆想象", "how_to": "动手实践", "help": "求助"]
        return map[value] ?? "事实探索"
    }

}
