import AVFoundation
import os.log

private let audioSessionLogger = Logger(
    subsystem: "com.tixing.me.ios",
    category: "AudioSession"
)

/// 统一管理录音、原始录音播放和讲解播报的 AVAudioSession。
///
/// AVAudioSession 的同步 API 不能直接从 MainActor/async 上下文调用；
/// 这里用 actor 保证调用顺序，再把实际系统调用放到专用串行队列，
/// 避免 UI 线程阻塞，也避免录音会话和播放会话交叉切换。
actor AudioSessionService {
    enum Usage: String, Sendable {
        case voiceRecording
        case spokenPlayback
    }

    static let shared = AudioSessionService()

    private let sessionQueue = DispatchQueue(
        label: "com.tixing.me.ios.audio-session",
        qos: .userInitiated
    )
    private var lastUsage: Usage?

    private init() {}

    /// 同一用途内避免反复切换会话，例如讲解章节切换时不再重复激活。
    func ensureActivated(for usage: Usage) async throws {
        guard lastUsage != usage else { return }
        try await activate(for: usage)
    }

    func activate(for usage: Usage) async throws {
        try await configure { session in
            switch usage {
            case .voiceRecording:
                try session.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.defaultToSpeaker]
                )
                // 20ms 输入缓冲可以兼顾采集延迟和调度稳定性。
                try session.setPreferredIOBufferDuration(0.02)
            case .spokenPlayback:
                try session.setCategory(
                    .playback,
                    mode: .spokenAudio,
                    options: [.duckOthers]
                )
                // 稍大的输出缓冲能降低模拟器和低负载设备的 AudioQueue underflow。
                try session.setPreferredIOBufferDuration(0.08)
            }
        }

        try await activateSession()
        lastUsage = usage
        logCurrentSession(operation: "activated", usage: usage)
    }

    /// 录音文件已经关闭后释放输入路由；失败只记录日志，不阻断语音识别。
    func deactivateAfterRecording() async {
        do {
            try await deactivateSession()
            audioSessionLogger.info("audio session deactivated after recording")
        } catch {
            let nsError = error as NSError
            audioSessionLogger.notice(
                "audio session deactivation ignored: domain=\(nsError.domain, privacy: .public), code=\(nsError.code), message=\(nsError.localizedDescription, privacy: .public)"
            )
        }
        lastUsage = nil
    }

    static func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        audioSessionLogger.error(
            "audio session failed: domain=\(nsError.domain, privacy: .public), code=\(nsError.code), message=\(nsError.localizedDescription, privacy: .public)"
        )

        if let code = AVAudioSession.ErrorCode(rawValue: nsError.code) {
            switch code {
            case .isBusy:
                return "音频设备正在切换，请稍后再试"
            case .cannotStartPlaying, .cannotInterruptOthers:
                return "当前音频设备被占用，请关闭其他音频后重试"
            case .insufficientPriority:
                return "有更高优先级的录音或通话正在使用麦克风"
            case .resourceNotAvailable:
                return "音频资源暂不可用，请检查音量和音频设备"
            default:
                break
            }
        }
        if nsError.domain == "TiXing.AudioPlayback" || nsError.domain == "TiXing.AudioRecorder" {
            return nsError.localizedDescription
        }
        return "音频启动失败，请检查音量和音频设备后重试"
    }

    private func configure(_ work: @escaping @Sendable (AVAudioSession) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    try work(AVAudioSession.sharedInstance())
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func activateSession() async throws {
        if #available(iOS 27.0, *) {
            try await withCheckedThrowingContinuation { continuation in
                sessionQueue.async {
                    AVAudioSession.sharedInstance().activate(options: []) { activated, error in
                        if activated, error == nil {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: error ?? AudioSessionError.activationFailed)
                        }
                    }
                }
            }
        } else {
            try await configure { session in
                try session.setActive(
                    true,
                    options: [.notifyOthersOnDeactivation]
                )
            }
        }
    }

    private func deactivateSession() async throws {
        if #available(iOS 27.0, *) {
            try await withCheckedThrowingContinuation { continuation in
                sessionQueue.async {
                    AVAudioSession.sharedInstance().deactivate(options: [.notifyOthersOnDeactivation]) { deactivated, error in
                        if deactivated, error == nil {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: error ?? AudioSessionError.deactivationFailed)
                        }
                    }
                }
            }
        } else {
            try await configure { session in
                try session.setActive(
                    false,
                    options: [.notifyOthersOnDeactivation]
                )
            }
        }
    }

    private func logCurrentSession(operation: String, usage: Usage) {
        sessionQueue.async {
            let session = AVAudioSession.sharedInstance()
            audioSessionLogger.info(
                "audio session \(operation, privacy: .public): usage=\(usage.rawValue, privacy: .public), category=\(session.category.rawValue, privacy: .public), mode=\(session.mode.rawValue, privacy: .public), bufferMs=\(Int(session.ioBufferDuration * 1000), privacy: .public), sampleRate=\(Int(session.sampleRate), privacy: .public)"
            )
        }
    }

    private enum AudioSessionError: Error {
        case activationFailed
        case deactivationFailed
    }
}
