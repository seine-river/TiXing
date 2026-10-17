import AVFoundation
import os.log
import Speech

private let speechLogger = Logger(subsystem: "com.tixing.me.ios", category: "Speech")
private let audioPlaybackLogger = Logger(subsystem: "com.tixing.me.ios", category: "AudioPlayback")

struct RecordedAudio: Equatable {
    var url: URL
    var duration: Int
}

@MainActor
final class AudioRecorderService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var elapsed = 0
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var stopped = false
    private var continuation: CheckedContinuation<RecordedAudio?, Never>?
    private var currentURL: URL?
    private var finishing = false

    func record() async -> RecordedAudio? {
        stopped = false
        errorMessage = nil
        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard granted else {
            errorMessage = "未获得麦克风权限，无法问一问"
            return nil
        }

        do {
            try await AudioSessionService.shared.activate(for: .voiceRecording)
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("VoiceAsks", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("ask-\(UUID().uuidString).wav")
            currentURL = url
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            self.recorder = recorder
            recorder.delegate = self
            guard recorder.prepareToRecord(), recorder.record(forDuration: 30) else {
                throw NSError(
                    domain: "TiXing.AudioRecorder",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "麦克风暂时没有启动，请重新录一次"]
                )
            }
            isRecording = true
            elapsed = 0
            startTimer()
            return await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        } catch {
            speechLogger.error(
                "recorder start failed: \(String(describing: error), privacy: .public)"
            )
            recorder?.stop()
            recorder = nil
            if let currentURL {
                try? FileManager.default.removeItem(at: currentURL)
            }
            currentURL = nil
            await AudioSessionService.shared.deactivateAfterRecording()
            errorMessage = AudioSessionService.friendlyMessage(for: error)
            return nil
        }
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        stopTimer()
        recorder?.stop()
    }

    func cancel() {
        stop()
        if let url = currentURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            await self.finish(success: flag)
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error {
                speechLogger.error(
                    "recorder encode failed: \(String(describing: error), privacy: .public)"
                )
            }
            self.errorMessage = "录音出了点小问题，请重新录一次"
            await self.finish(success: false)
        }
    }

    private func finish(success: Bool) async {
        guard !finishing else { return }
        finishing = true
        stopTimer()
        isRecording = false
        let url = currentURL
        let duration = elapsed
        recorder = nil
        currentURL = nil
        await AudioSessionService.shared.deactivateAfterRecording()
        finishing = false
        continuation?.resume(with: .success(success ? RecordedAudio(url: url ?? URL(fileURLWithPath: "/dev/null"), duration: duration) : nil))
        continuation = nil
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.elapsed += 1
                if self.elapsed >= 30 {
                    self.stop()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct SpeechTranscriptionService {
    static func requestAuthorization() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        let microphone = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        return speech && microphone
    }

    static func transcribe(url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) else {
            throw NSError(domain: "TiXing.Speech", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "本机语音识别引擎不可用，请检查系统语音服务后重试"])
        }

        do {
            return try await recognize(
                url: url,
                recognizer: recognizer,
                requiresOnDevice: recognizer.supportsOnDeviceRecognition)
        } catch {
            let underlying = error as NSError
            speechLogger.error(
                "speech first pass failed: domain=\(underlying.domain, privacy: .public), code=\(underlying.code), onDevice=\(recognizer.supportsOnDeviceRecognition), message=\(underlying.localizedDescription, privacy: .public)"
            )

            // iOS Speech 偶发返回 kAFAssistantErrorDomain/1101 “retry”。
            // 端侧模型缺失或服务抖动时，关闭强制端侧并重试一次。
            do {
                try await Task.sleep(nanoseconds: 400_000_000)
                if recognizer.supportsOnDeviceRecognition {
                    return try await recognize(
                        url: url,
                        recognizer: recognizer,
                        requiresOnDevice: false)
                }
                if underlying.domain == "kAFAssistantErrorDomain" &&
                    (underlying.code == 1101 || underlying.code == 203) {
                    return try await recognize(
                        url: url,
                        recognizer: recognizer,
                        requiresOnDevice: false)
                }
            } catch {
                let secondError = error as NSError
                speechLogger.error(
                    "speech fallback failed: domain=\(secondError.domain, privacy: .public), code=\(secondError.code), message=\(secondError.localizedDescription, privacy: .public)"
                )
                throw friendlySpeechError(secondError)
            }
            throw friendlySpeechError(underlying)
        }
    }

    private static func recognize(url: URL,
                                  recognizer: SFSpeechRecognizer,
                                  requiresOnDevice: Bool) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = requiresOnDevice
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            var bestText = ""
            _ = recognizer.recognitionTask(with: request, resultHandler: { result, error in
                if finished { return }
                if let error {
                    finished = true
                    let underlying = error as NSError
                    speechLogger.error(
                        "speech task failed: domain=\(underlying.domain, privacy: .public), code=\(underlying.code), bestTextLength=\(bestText.count), message=\(underlying.localizedDescription, privacy: .public)"
                    )
                    let partial = bestText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !partial.isEmpty {
                        continuation.resume(returning: partial)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                if let result {
                    bestText = result.bestTranscription.formattedString
                    if result.isFinal {
                        finished = true
                        continuation.resume(
                            returning: bestText.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            })
        }
    }

    static func friendlySpeechError(_ error: NSError) -> Error {
        let message: String
        if error.domain == "kAFAssistantErrorDomain" {
            switch error.code {
            case 1020, 1101, 203:
                message = "语音识别服务暂时不可用，请再试一次；也可以手动写下问题"
            case 1100:
                message = "没有听清孩子的问题，请靠近麦克风重新录一次"
            case 209:
                message = "语音识别权限不可用，请到系统设置中开启后重试"
            default:
                message = "语音转文字失败，请重新录制或手动输入问题"
            }
        } else {
            if error.code == -600 || error.localizedDescription.lowercased() == "retry" {
                message = "语音识别服务暂时不可用，请再试一次；也可以手动写下问题"
            } else {
                message = "语音转文字失败，请重新录制或手动输入问题"
            }
        }
        return NSError(
            domain: "TiXing.Speech",
            code: 200 + abs(error.code) % 100,
            userInfo: [
                NSLocalizedDescriptionKey: message,
                NSUnderlyingErrorKey: error
            ])
    }
}

@MainActor
final class AudioPlaybackService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var playingID: String?
    @Published var errorMessage: String?
    private var player: AVAudioPlayer?
    private var playbackTask: Task<Void, Never>?
    private var playbackToken = 0

    func play(url: URL, id: String) {
        playbackToken += 1
        let token = playbackToken
        playbackTask?.cancel()
        player?.stop()
        player = nil
        playingID = id
        errorMessage = nil

        playbackTask = Task { [weak self] in
            do {
                try await AudioSessionService.shared.ensureActivated(for: .spokenPlayback)
                guard let self, token == self.playbackToken, !Task.isCancelled else { return }
                let player = try AVAudioPlayer(contentsOf: url)
                guard player.duration.isFinite, player.duration > 0.2 else {
                    throw NSError(
                        domain: "TiXing.AudioPlayback",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "这段录音文件不完整，无法播放"]
                    )
                }
                player.delegate = self
                self.player = player
                guard player.prepareToPlay() else {
                    throw NSError(
                        domain: "TiXing.AudioPlayback",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "音频还在准备中，请再点一次"]
                    )
                }
                let started = player.play()
                guard started else {
                    throw NSError(
                        domain: "TiXing.AudioPlayback",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "音频设备暂时不可用，请稍后再试"]
                    )
                }
            } catch {
                guard let self, token == self.playbackToken else { return }
                self.playingID = nil
                self.errorMessage = AudioSessionService.friendlyMessage(for: error)
                audioPlaybackLogger.error(
                    "original recording playback failed: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    func stop() {
        playbackToken += 1
        playbackTask?.cancel()
        playbackTask = nil
        player?.stop()
        player = nil
        playingID = nil
        errorMessage = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.playingID = nil
        }
    }
}
