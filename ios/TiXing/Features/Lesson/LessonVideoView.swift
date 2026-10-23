import AVFoundation
import SwiftUI

@MainActor
final class LessonPlayerModel: NSObject, ObservableObject {
    @Published var index = 0
    @Published var elapsed: Int = 0
    @Published var playing = false
    @Published var finished = false
    @Published var audioErrorMessage: String?
    let lesson: AILesson
    let actualTotalDuration: Int
    private let synthesizer = AVSpeechSynthesizer()
    private var timer: Timer?
    private var startTask: Task<Void, Never>?
    private var transitionTask: Task<Void, Never>?
    private var commandToken = 0
    private var speechGeneration = 0

    init(lesson: AILesson) {
        self.lesson = lesson
        self.actualTotalDuration = lesson.scenes.reduce(0) { $0 + max(1, $1.duration) }
        super.init()
    }

    var scene: AILessonScene? {
        guard index < lesson.scenes.count else { return nil }
        return lesson.scenes[index]
    }

    func start(at index: Int = 0) {
        let targetIndex = boundedIndex(index)
        commandToken += 1
        let token = commandToken
        startTask?.cancel()
        transitionTask?.cancel()
        audioErrorMessage = nil
        self.index = targetIndex
        elapsed = 0
        finished = false
        playing = true
        stopSpeakingImmediately()

        startTask = Task { [weak self] in
            do {
                try await AudioSessionService.shared.ensureActivated(for: .spokenPlayback)
            } catch {
                guard let self, token == self.commandToken else { return }
                self.playing = false
                self.audioErrorMessage = AudioSessionService.friendlyMessage(for: error)
                return
            }

            guard let self, token == self.commandToken, !Task.isCancelled else { return }
            self.beginScene(at: targetIndex)
        }
    }

    func pause() {
        commandToken += 1
        startTask?.cancel()
        transitionTask?.cancel()
        stopTimer()
        playing = false
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.pauseSpeaking(at: .word)
        }
    }

    func resume() {
        guard !lesson.scenes.isEmpty else { return }
        if finished {
            start(at: 0)
            return
        }
        playing = true
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            startTimer()
        } else if let scene, elapsed >= effectiveDuration(of: scene) {
            advanceToNextScene()
        } else {
            speakCurrent(resumeElapsed: elapsed)
            startTimer()
        }
    }

    func stop() {
        commandToken += 1
        startTask?.cancel()
        transitionTask?.cancel()
        playing = false
        audioErrorMessage = nil
        stopTimer()
        stopSpeakingImmediately()
    }

    var completedSeconds: Int {
        let beforeScene = lesson.scenes.prefix(index).reduce(0) { $0 + effectiveDuration(of: $1) }
        let currentSeconds = scene.map { min(elapsed, effectiveDuration(of: $0)) } ?? 0
        return beforeScene + currentSeconds
    }

    var completedFraction: Double {
        min(1, max(0, Double(completedSeconds) / Double(max(actualTotalDuration, 1))))
    }

    var canPrevious: Bool {
        index > 0 || finished
    }

    var canNext: Bool {
        index + 1 < lesson.scenes.count
    }

    private func boundedIndex(_ index: Int) -> Int {
        min(max(index, 0), lesson.scenes.count - 1)
    }

    private func effectiveDuration(of scene: AILessonScene) -> Int {
        max(1, scene.duration)
    }

    private func stopSpeakingImmediately() {
        speechGeneration += 1
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func beginScene(at targetIndex: Int) {
        index = boundedIndex(targetIndex)
        elapsed = 0
        finished = false
        playing = true
        speakCurrent()
        startTimer()
    }

    private func advanceToNextScene() {
        let nextIndex = index + 1
        guard nextIndex < lesson.scenes.count else {
            finished = true
            playing = false
            stopTimer()
            stopSpeakingImmediately()
            return
        }

        // 与 HarmonyOS 一致：章节由脚本时长驱动；短暂停顿减少 AudioQueue 立即重建。
        let generation = speechGeneration
        transitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard let self, generation == self.speechGeneration, self.playing else { return }
            self.beginScene(at: nextIndex)
        }
    }

    private func tick() {
        guard playing, !finished, let scene else { return }
        let duration = effectiveDuration(of: scene)
        elapsed = min(elapsed + 1, duration)
        if elapsed >= duration {
            advanceToNextScene()
        }
    }

    private func speechText(for scene: AILessonScene) -> String {
        let narration = scene.narration.trimmingCharacters(in: .whitespacesAndNewlines)
        if !narration.isEmpty { return narration }
        let subtitle = scene.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !subtitle.isEmpty { return subtitle }
        return scene.screen.title ?? "我们一起看这一部分。"
    }

    private func speakCurrent(resumeElapsed: Int? = nil) {
        guard let scene else { return }
        speechGeneration += 1
        let text: String
        if let resumeElapsed {
            text = remainingNarration(for: scene, elapsed: resumeElapsed)
        } else {
            text = speechText(for: scene)
        }
        guard !text.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.48
        utterance.postUtteranceDelay = 0.12
        synthesizer.speak(utterance)
    }

    private func remainingNarration(for scene: AILessonScene, elapsed: Int) -> String {
        guard elapsed > 0 else { return speechText(for: scene) }
        let duration = effectiveDuration(of: scene)
        guard elapsed < duration else { return "" }
        let fullText = speechText(for: scene)
        let sentences = splitNarration(fullText)
        let consumedTarget = Double(fullText.count) * Double(elapsed) / Double(duration)
        var consumed = 0.0
        for sentenceIndex in sentences.indices {
            let previous = consumed
            consumed += Double(sentences[sentenceIndex].count)
            if consumed > consumedTarget && previous <= consumedTarget {
                return sentences[sentenceIndex...].joined()
            }
        }
        return ""
    }

    private func splitNarration(_ text: String) -> [String] {
        var sentences: [String] = []
        var start = text.startIndex
        for (offset, character) in text.enumerated() {
            guard character == "。" || character == "！" || character == "？" ||
                    character == "；" || character == "." else { continue }
            let end = text.index(text.startIndex, offsetBy: offset + 1)
            let sentence = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { sentences.append(sentence) }
            start = end
        }
        let tail = String(text[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { sentences.append(tail) }
        return sentences
    }
}

private struct LessonIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

private extension LessonPlayerModel {
    func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func previous() {
        guard index > 0 || finished else { return }
        start(at: index > 0 ? index - 1 : 0)
    }

    func next() {
        guard index + 1 < lesson.scenes.count else { return }
        start(at: index + 1)
    }
}

struct LessonVideoView: View {
    @EnvironmentObject private var store: AppStore
    @State private var loading = true
    @State private var progress = 6.0
    @State private var waitingSeconds = 0
    @State private var stage = "正在打开讲解工坊..."
    @State private var lesson: AILesson?
    @State private var player: LessonPlayerModel?
    @State private var errorText: String?
    @State private var detailText: String?
    @State private var timer: Timer?
    @State private var generating = false
    @State private var usingCachedLesson = false
    private let mistakeID: String

    init(mistakeID: String) {
        self.mistakeID = mistakeID
    }

    var body: some View {
        Group {
            if loading {
                loadingView
            } else if let errorText {
                errorView(errorText)
            } else if let player {
                playerView(player)
            } else {
                EmptyBlock(message: "讲解内容为空，请返回重试")
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("AI 讲解视频")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { generate(force: false) }
        .onDisappear {
            timer?.invalidate()
            player?.stop()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 15) {
            Text("🦉")
                .font(.system(size: 72))
                .frame(width: 132, height: 132)
                .background(Theme.heroGradient)
                .clipShape(RoundedRectangle(cornerRadius: 42))
                .symbolEffect(.pulse)
            Text("醒醒正在为你准备讲解视频...")
                .font(.system(size: 18, weight: .bold))
            Text(stage)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            ProgressView(value: progress, total: 100)
                .tint(Theme.primary)
            Text("已等待 \(waitingSeconds) 秒 · 可随时点击左上角返回")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(24)
    }

    private func errorView(_ message: String) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("😟").font(.system(size: 54))
                Text("讲解视频生成失败")
                    .font(.system(size: 20, weight: .bold))
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                if let detailText {
                    ScrollView {
                        Text(detailText)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 260)
                    .padding(10)
                    .background(Color.black.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Button("重新生成") { generate(force: true) }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(18)
        }
    }

    private func playerView(_ model: LessonPlayerModel) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                if let scene = model.scene {
                    sceneCard(scene, model: model)
                    narrationCard(scene)
                }
                if let audioError = model.audioErrorMessage {
                    Text(audioError)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                    controls(model)
                    if usingCachedLesson {
                        Text("已保存本地")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                chapters(model)
            }
            .padding(14)
            .padding(.bottom, 66)
        }
    }

    private func sceneCard(_ scene: AILessonScene, model: LessonPlayerModel) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(scene.screen.title ?? scene.subtitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(model.elapsed)/\(scene.duration)秒")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
            }
            SceneVisual(
                scene: scene,
                progress: Double(model.elapsed) / Double(max(scene.duration, 1)))
                .frame(maxWidth: .infinity)
                .frame(height: 270)
                .background(Color.white.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            Text(scene.subtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 26).fill(Theme.heroGradient))
        .shadow(color: Theme.primary.opacity(0.22), radius: 14, y: 7)
    }

    private func narrationCard(_ scene: AILessonScene) -> some View {
        AppCard {
            Text(scene.narration)
                .font(.system(size: 15))
                .lineSpacing(6)
                .foregroundStyle(Theme.textRegular)
        }
    }

    private func controls(_ model: LessonPlayerModel) -> some View {
        VStack(spacing: 9) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.chip)
                    Capsule()
                        .fill(Theme.primary)
                        .frame(width: max(0, proxy.size.width * model.completedFraction))
                }
            }
            .frame(height: 8)
            .animation(.linear(duration: 1), value: model.completedSeconds)
            .accessibilityLabel("讲解进度")
            .accessibilityValue("\(model.completedSeconds)/\(model.actualTotalDuration)秒")

            HStack(spacing: 10) {
                Button {
                    playPrevious(model)
                } label: { Image(systemName: "backward.end.fill") }
                    .buttonStyle(LessonIconButtonStyle())
                    .disabled(!model.canPrevious)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white))
                    .foregroundStyle(Theme.primary)
                    .contentShape(Circle())

                Button {
                    togglePlayback(model)
                } label: {
                    Image(systemName: playbackIcon(model))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: model.playing)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(LessonIconButtonStyle())
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Capsule().fill(Theme.buttonGradient))
                .contentShape(Capsule())

                Button {
                    playNext(model)
                } label: { Image(systemName: "forward.end.fill") }
                    .buttonStyle(LessonIconButtonStyle())
                    .disabled(!model.canNext)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white))
                    .foregroundStyle(Theme.primary)
                    .contentShape(Circle())
            }

            Button {
                generate(force: true)
            } label: {
                Label("重新生成讲解", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Capsule().stroke(Theme.primary, lineWidth: 1.2))
            }
            .buttonStyle(.plain)
            .disabled(generating)
        }
        .padding(13)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func togglePlayback(_ model: LessonPlayerModel) {
        if model.playing {
            model.pause()
        } else if model.finished {
            model.start()
        } else {
            model.resume()
        }
    }

    private func playPrevious(_ model: LessonPlayerModel) {
        model.previous()
    }

    private func playNext(_ model: LessonPlayerModel) {
        model.next()
    }

    private func playbackIcon(_ model: LessonPlayerModel) -> String {
        if model.finished { return "arrow.counterclockwise" }
        return model.playing ? "pause.fill" : "play.fill"
    }

    private func chapters(_ model: LessonPlayerModel) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("讲解章节").font(.system(size: 14, weight: .bold))
                ForEach(Array(model.lesson.scenes.enumerated()), id: \.element.id) { index, scene in
                    Button {
                        model.start(at: index)
                    } label: {
                        HStack(spacing: 9) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(index == model.index ? .white : Theme.primary)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(index == model.index ? Theme.primary : Theme.softPrimary))
                            Text(scene.subtitle)
                                .font(.system(size: 14, weight: index == model.index ? .bold : .regular))
                                .foregroundStyle(index == model.index ? Theme.textPrimary : Theme.textRegular)
                            Spacer()
                            Text("\(scene.duration)秒")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func generate(force: Bool) {
        guard !generating else { return }
        generating = true
        player?.stop()
        player = nil
        usingCachedLesson = false

        let fingerprint = lessonSourceFingerprint()
        if !force, let cached = LessonCacheService.load(
            mistakeID: mistakeID, sourceFingerprint: fingerprint) {
            applyLesson(cached, fromCache: true)
            generating = false
            return
        }

        loading = true
        errorText = nil
        detailText = nil
        progress = 6
        waitingSeconds = 0
        stage = "正在读取错题信息..."
        startPulse()

        Task {
            do {
                guard let mistake = store.mistake(id: mistakeID) else { throw AIError.invalidResponse("错题不存在") }
                stage = "正在理解题目和学生答案..."
                let value = try await AIService.shared.lesson(mistake: mistake, grade: store.student.grade)
                guard !value.scenes.isEmpty else { throw AIError.parsing("未解析到讲解章节") }
                LessonCacheService.save(
                    mistakeID: mistakeID, sourceFingerprint: fingerprint, lesson: value)
                stage = "马上开始播放..."
                progress = 97
                applyLesson(value, fromCache: false)
            } catch {
                errorText = error.localizedDescription
                detailText = String(describing: error)
                loading = false
                stopPulse()
            }
            generating = false
        }
    }

    private func applyLesson(_ value: AILesson, fromCache: Bool) {
        lesson = value
        usingCachedLesson = fromCache
        let model = LessonPlayerModel(lesson: value)
        player = model
        loading = false
        stopPulse()
        model.start()
    }

    private func lessonSourceFingerprint() -> String {
        guard let mistake = store.mistake(id: mistakeID) else { return mistakeID }
        return [
            store.student.grade.rawValue,
            mistake.question,
            mistake.studentAnswer,
            mistake.standardAnswer,
            mistake.knowledgeSummary,
            mistake.subject.rawValue,
            mistake.errorType.rawValue
        ].joined(separator: "\u{1F}")
    }

    private func startPulse() {
        stopPulse()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                waitingSeconds += 1
                progress = min(progress + 1.4, 88)
                if waitingSeconds < 4 { stage = "正在读取错题信息..." }
                else if waitingSeconds < 10 { stage = "正在理解题目和学生答案..." }
                else if waitingSeconds < 18 { stage = "正在拆解动画章节..." }
                else { stage = "正在整理讲解步骤..." }
            }
        }
    }

    private func stopPulse() {
        timer?.invalidate()
        timer = nil
    }
}

struct SceneVisual: View {
    let scene: AILessonScene
    let progress: Double

    init(scene: AILessonScene, progress: Double) {
        self.scene = scene
        self.progress = min(max(progress, 0), 1)
    }

    var body: some View {
        Group {
            switch scene.visual?.type ?? "" {
            case "fraction_bars":
                FractionBarsVisual(scene: scene, progress: progress)
            case "number_line":
                NumberLineVisual(scene: scene, progress: progress)
            case "arrow_flow":
                ArrowFlowVisual(items: flowItems, progress: progress)
            case "counters":
                CountersVisual(scene: scene, progress: progress)
            case "shape_combo":
                ShapeComboVisual(scene: scene, progress: progress)
            default:
                IconStoryVisual(scene: scene, progress: progress)
            }
        }
    }

    private var flowItems: [String] {
        if let nodes = scene.visual?.nodes, !nodes.isEmpty { return nodes }
        if let steps = scene.screen.steps { return steps }
        return scene.visual?.captions ?? []
    }
}

struct IconStoryVisual: View {
    let scene: AILessonScene
    let progress: Double

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(Array((scene.visual?.icons ?? ["📘", "✏️", "✅"]).prefix(3).enumerated()), id: \.offset) { index, icon in
                    Text(icon)
                        .font(.system(size: 28))
                        .frame(width: 62, height: 62)
                        .background(Color.white)
                        .clipShape(Circle())
                        .offset(y: index.isMultiple(of: 2) ? -4 : 4)
                        .scaleEffect(index <= Int(progress * 3) ? 1 : 0.86)
                        .opacity(index <= Int(progress * 3) ? 1 : 0.55)
                        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: progress)
                }
            }
            Text(scene.screen.text ?? scene.screen.title ?? scene.subtitle)
                .font(.system(size: 17, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 8)
        }
        .padding(12)
    }
}

struct FractionBarsVisual: View {
    let scene: AILessonScene
    let progress: Double

    var body: some View {
        VStack(spacing: 12) {
            let labels = scene.visual?.labels ?? []
            let numerators = scene.visual?.numerators ?? []
            let denominators = scene.visual?.denominators ?? []
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                let numerator = index < numerators.count ? numerators[index] : 0
                let denominator = index < denominators.count ? denominators[index] : 1
                let ratio = denominator == 0 ? 0.0 : Double(numerator) / Double(denominator)
                VStack(alignment: .leading, spacing: 4) {
                    Text(label).font(.system(size: 13, weight: .semibold))
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.softPrimary)
                            Capsule().fill(index.isMultiple(of: 2) ? Theme.primary : Theme.gradientEnd)
                                .frame(width: max(8, proxy.size.width * ratio * max(0.18, progress)))
                        }
                    }
                    .frame(height: 16)
                    .animation(.easeOut(duration: 0.35), value: progress)
                }
            }
        }
        .padding(14)
    }
}

struct NumberLineVisual: View {
    let scene: AILessonScene
    let progress: Double

    var body: some View {
        let labels = scene.visual?.labels ?? ["1", "2", "3", "4", "5"]
        VStack(spacing: 18) {
            Text(scene.screen.highlight ?? scene.screen.title ?? "数轴观察")
                .font(.system(size: 17, weight: .semibold))
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    VStack(spacing: 7) {
                        if index > 0 {
                            Rectangle()
                                .fill(Theme.primary.opacity(0.28))
                                .frame(height: 3)
                                .offset(y: -9)
                        }
                        Circle()
                            .fill(index == (scene.visual?.highlightIndex ?? labels.count - 1) ? Theme.warning : Theme.primary)
                            .frame(width: index == (scene.visual?.highlightIndex ?? labels.count - 1) ? 20 : 13, height: index == (scene.visual?.highlightIndex ?? labels.count - 1) ? 20 : 13)
                            .scaleEffect(index <= Int(progress * Double(labels.count)) ? 1 : 0.8)
                        Text(label).font(.system(size: 11))
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: progress)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(12)
    }
}

struct ArrowFlowVisual: View {
    let items: [String]
    let progress: Double

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 9) {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.primary))
                    Text(item)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if index + 1 < items.count {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.primary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .opacity(Double(index) <= progress * Double(items.count) ? 1 : 0.48)
                .offset(x: Double(index) <= progress * Double(items.count) ? 0 : 12)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
            }
        }
    }
}

struct CountersVisual: View {
    let scene: AILessonScene
    let progress: Double

    var body: some View {
        let captions = scene.visual?.captions ?? ["看清题目", "认真计算", "检查答案"]
        let icons = scene.visual?.icons ?? []
        VStack(spacing: 14) {
            ForEach(Array(captions.enumerated()), id: \.offset) { index, caption in
                HStack(spacing: 9) {
                    Text(index < icons.count ? icons[index] : "⭐")
                        .font(.system(size: 20))
                    Text(caption)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .padding(10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .scaleEffect(Double(index) <= progress * Double(captions.count) ? 1 : 0.94)
                .opacity(Double(index) <= progress * Double(captions.count) ? 1 : 0.5)
                .animation(.spring(response: 0.38, dampingFraction: 0.75), value: progress)
            }
        }
        .padding(10)
    }
}

struct ShapeComboVisual: View {
    let scene: AILessonScene
    let progress: Double

    var body: some View {
        let nodes = scene.visual?.nodes ?? scene.screen.steps ?? []
        let icons = scene.visual?.icons ?? []
        let captions = scene.visual?.captions ?? []
        let items = nodes.isEmpty ? (0..<3).map { index in "步骤 \(index + 1)" } : nodes

        VStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(index.isMultiple(of: 2) ? Theme.softPrimary : Theme.softSecondary)
                            .frame(width: 44, height: 44)
                        if index < icons.count {
                            Text(icons[index]).font(.system(size: 18))
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.primary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if index < captions.count {
                            Text(captions[index])
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer()
                }
                .padding(9)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .opacity(Double(index) <= progress * Double(items.count) ? 1 : 0.48)
                .offset(y: Double(index) <= progress * Double(items.count) ? 0 : 8)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
            }
        }
        .padding(10)
    }
}
