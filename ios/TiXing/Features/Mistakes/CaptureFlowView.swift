import PhotosUI
import SwiftUI

struct CaptureFlowView: View {
    fileprivate enum Step {
        case source
        case analyzing
        case select
        case review
        case saved
    }

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .source
    @State private var imageData: Data?
    @State private var imagePath: String?
    @State private var questions: [AIQuestion] = []
    @State private var selectedIDs: Set<String> = []
    @State private var draft = Mistake.new(question: "")
    @State private var editingQuestion = ""
    @State private var editingStudentAnswer = ""
    @State private var editingStandardAnswer = ""
    @State private var editingKnowledge = ""
    @State private var notes = ""
    @State private var busyText: String?
    @State private var errorText: String?
    @State private var qualityWarning: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var savedCount = 0

    var body: some View {
        VStack(spacing: 0) {
            CaptureFlowProgress(step: step)
            switch step {
            case .source: sourceView
            case .analyzing: analyzingView
            case .select: questionSelectView
            case .review: reviewForm
            case .saved: savedView
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("录入错题")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("返回") {
                    handleBack()
                }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                await loadPhoto(item)
                photoItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                if let image, let data = image.jpegData(compressionQuality: 0.9) {
                    Task { await prepare(data: data) }
                }
            }
            .ignoresSafeArea()
        }
    }

    private var sourceView: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    Text("🦉")
                        .font(.system(size: 40))
                        .frame(width: 78, height: 78)
                        .background(Theme.heroGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("嗨，我是醒醒！")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.primary)
                        Text("拍一道错题照片，我帮你识别题目、提取答案、总结知识点")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.softPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.top, 10)

                Text("AI 智能录题")
                    .font(.system(size: 24, weight: .bold))

                Button {
                    showCamera = true
                } label: {
                    Label("拍照识别", systemImage: "camera.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("从相册选取", systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Capsule().stroke(Theme.primary, lineWidth: 1.2))
                }

                HStack(spacing: 6) {
                    capability("🧠", "全图智能识别")
                    capability("✍️", "答案提取")
                }
                HStack(spacing: 6) {
                    capability("📚", "学科判断")
                    capability("🏷️", "知识点总结")
                }

                AppCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 拍摄小贴士")
                            .font(.system(size: 14, weight: .semibold))
                        tip("光线充足，整道题目完整入镜")
                        tip("尽量包含作答与红笔批改痕迹")
                        tip("手写作答也能识别，拍清晰即可")
                    }
                }
            }
            .padding(16)
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 18) {
            if let data = imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            ProgressView()
                .controlSize(.large)
            Text("AI 正在全图识别")
                .font(.system(size: 17, weight: .semibold))
            Text(busyText ?? "通常需要几秒钟，请保持网络畅通")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            if let errorText {
                ErrorBanner(message: errorText)
                Button("✏️ 手动填写") { step = .review }
                    .buttonStyle(PrimaryButtonStyle())
            }
            if let qualityWarning {
                Text("⚠️ \(qualityWarning)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.warning)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.softWarning))
            }
        }
        .padding(16)
    }

    private var questionSelectView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("识别到 \(questions.count) 道题")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Button("全选") {
                    selectedIDs = Set(questions.map(\.id))
                }
                .font(.system(size: 14, weight: .semibold))
                Button("清空") { selectedIDs = [] }
                    .font(.system(size: 14))
            }
            .padding(16)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(questions.enumerated()), id: \.element.id) { index, item in
                        Button {
                            toggle(item)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 23))
                                    .foregroundStyle(selectedIDs.contains(item.id) ? Theme.primary : Theme.textSecondary)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text("第 \(index + 1) 题")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Theme.primary)
                                    Text(item.question)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Theme.textPrimary)
                                        .lineLimit(4)
                                    if let answer = item.myAnswer, !answer.isEmpty {
                                        Text("我的答案：\(answer)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.textSecondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selectedIDs.contains(item.id) ? Theme.softPrimary : Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedIDs.contains(item.id) ? Theme.primary : Color.clear, lineWidth: 1.5))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }

            Button {
                saveSelected()
            } label: {
                Text("保存选中的 \(selectedIDs.count) 道题")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selectedIDs.isEmpty)
            .padding(16)
        }
    }

    private var reviewForm: some View {
        Form {
            if let imagePath, let image = UIImage(contentsOfFile: imagePath) {
                Section("原始照片") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            Section("题目内容") {
                TextField("题目", text: $editingQuestion, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                Picker("学科", selection: $draft.subject) {
                    ForEach(Subject.allCases) { Text($0.label).tag($0) }
                }
                Picker("题型", selection: $draft.answerType) {
                    ForEach(AnswerType.allCases) { Text($0.label).tag($0) }
                }
                Picker("错误类型", selection: $draft.errorType) {
                    ForEach(ErrorType.allCases) { Text($0.label).tag($0) }
                }
            }
            Section("答案") {
                TextField("我的答案", text: $editingStudentAnswer, axis: .vertical)
                TextField("标准答案", text: $editingStandardAnswer, axis: .vertical)
                TextField("知识点总结", text: $editingKnowledge)
            }
            Section("讲解笔记") {
                TextField("添加讲解笔记", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            Section {
                Button("保存错题") { saveDraft() }
                    .frame(maxWidth: .infinity)
            } footer: {
                Text("AI 结果仅作预填，保存前请核对题目和答案。")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    private var savedView: some View {
        VStack(spacing: 16) {
            Text("🎉")
                .font(.system(size: 64))
            Text("已保存 \(savedCount) 道错题")
                .font(.system(size: 22, weight: .bold))
            Text("醒醒已经把题目收进错题本，记得按计划复习哦")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("完成") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            errorText = "图片读取失败，请重新选择"
            return
        }
        await prepare(data: data)
    }

    private func prepare(data: Data) async {
        imageData = data
        errorText = nil
        step = .analyzing
        busyText = "正在读取照片…"
        do {
            let quality = ImageQualityService.analyze(data: data)
            if let blocking = quality.blockingMessage {
                errorText = blocking
                qualityWarning = quality.warningMessage
                imagePath = nil
                return
            }
            qualityWarning = quality.warningMessage
            let path = try store.saveImage(data, id: UUID().uuidString)
            imagePath = path
            busyText = "AI 识别题目与答案…"
            let items = try await AIService.shared.recognizeQuestions(imageData: data)
            questions = items
            if items.count > 1 {
                selectedIDs = Set(items.map(\.id))
                step = .select
            } else if let first = items.first {
                apply(first)
            } else {
                errorText = "AI 未能识别出题目，请手动核对填写"
                step = .analyzing
            }
        } catch {
            errorText = error.localizedDescription
            step = .analyzing
        }
    }

    private func apply(_ item: AIQuestion) {
        draft = Mistake.new(question: item.question, subject: item.domainSubject,
                            answerType: item.domainAnswerType,
                            standardAnswer: item.standardAnswer ?? "")
        draft.studentAnswer = item.myAnswer ?? ""
        draft.knowledgeSummary = item.knowledgeSummary ?? ""
        draft.errorType = item.domainErrorType
        draft.tags = item.knowledgeTags ?? []
        editingQuestion = draft.question
        editingStudentAnswer = draft.studentAnswer
        editingStandardAnswer = draft.standardAnswer
        editingKnowledge = draft.knowledgeSummary
        step = .review
    }

    private func toggle(_ item: AIQuestion) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    private func saveSelected() {
        var count = 0
        for question in questions where selectedIDs.contains(question.id) {
            var mistake = Mistake.new(question: question.question,
                                      subject: question.domainSubject,
                                      answerType: question.domainAnswerType,
                                      standardAnswer: question.standardAnswer ?? "")
            mistake.imagePath = imagePath
            mistake.studentAnswer = question.myAnswer ?? ""
            mistake.knowledgeSummary = question.knowledgeSummary ?? ""
            mistake.errorType = question.domainErrorType
            mistake.tags = question.knowledgeTags ?? []
            if store.insert(mistake) { count += 1 }
        }
        savedCount = count
        step = .saved
    }

    private func saveDraft() {
        var mistake = draft
        mistake.question = editingQuestion
        mistake.studentAnswer = editingStudentAnswer
        mistake.standardAnswer = editingStandardAnswer
        mistake.knowledgeSummary = editingKnowledge
        mistake.notes = notes
        mistake.imagePath = imagePath
        store.insert(mistake)
        savedCount = 1
        step = .saved
    }

    private func handleBack() {
        switch step {
        case .source: dismiss()
        case .select, .analyzing: step = .source
        case .review: step = .source
        case .saved: dismiss()
        }
    }

    private func capability(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Text(emoji).font(.system(size: 13))
            Text(text).font(.system(size: 12)).foregroundStyle(Theme.textRegular)
        }
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background(Capsule().fill(Theme.softPrimary))
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Text("·").foregroundStyle(Theme.primary).bold()
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
        }
    }
}

private struct CaptureFlowProgress: View {
    let step: CaptureFlowView.Step

    private var index: Int {
        switch step {
        case .source: return 0
        case .analyzing: return 1
        case .select, .review: return 2
        case .saved: return 3
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(["选图", "AI 识别", "核对保存"].enumerated()), id: \.offset) { itemIndex, title in
                HStack(spacing: 6) {
                    Circle()
                        .fill(itemIndex <= index - 1 ? Theme.primary : Theme.chip)
                        .frame(width: 8, height: 8)
                    Text(title)
                        .font(.system(size: 11, weight: itemIndex <= index - 1 ? .bold : .medium))
                        .foregroundStyle(itemIndex <= index - 1 ? Theme.primary : Theme.textSecondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Capsule().fill(itemIndex == index - 1 ? Theme.softPrimary : Color.clear))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            completion(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completion(nil)
        }
    }
}
