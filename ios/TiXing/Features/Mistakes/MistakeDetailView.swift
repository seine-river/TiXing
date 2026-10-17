import SwiftUI
import PhotosUI

struct MistakeDetailView: View {
    @EnvironmentObject private var store: AppStore
    @State private var notes: String
    @State private var notePhotoItem: PhotosPickerItem?
    @State private var noteError: String?
    private let mistakeID: String

    init(mistakeID: String) {
        self.mistakeID = mistakeID
        _notes = State(initialValue: "")
    }

    private var mistake: Mistake? {
        store.mistake(id: mistakeID)
    }

    var body: some View {
        Group {
            if let mistake {
                content(mistake)
            } else {
                EmptyBlock(message: "错题不存在或已被删除")
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("错题详情")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: notePhotoItem) { _, item in
            guard let item else { return }
            Task {
                await loadNotePhoto(item, mistakeID: mistakeID)
                notePhotoItem = nil
            }
        }
    }

    private func content(_ mistake: Mistake) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    TagPill(text: mistake.subject.label, color: Theme.primary)
                    TagPill(text: mistake.status.label, color: mistake.status == .mastered ? Theme.secondary : Theme.gradientEnd)
                    Spacer()
                    Text(mistake.createdAt.formatted(.dateTime.year().month().day()))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }

                NavigationLink {
                    LessonVideoView(mistakeID: mistake.id)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Text("🎬")
                                .font(.system(size: 24))
                                .frame(width: 48, height: 48)
                                .background(Theme.softPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AI 视频讲解")
                                    .font(.system(size: 16, weight: .bold))
                                Text("按年级定制 · 分析我的答案 · 分步讲懂")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Text("生成并播放讲解")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Capsule().fill(Theme.buttonGradient))
                    }
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
                }
                .buttonStyle(.plain)

                if let path = mistake.imagePath, let image = UIImage(contentsOfFile: path) {
                    card("📷 原始照片") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                card("知识点总结") {
                    Text(mistake.knowledgeSummary.isEmpty ? "尚未总结" : mistake.knowledgeSummary)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                }

                card("题目内容") {
                    Text(mistake.question)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary)
                }

                card("标准答案") {
                    Text(mistake.standardAnswer.isEmpty ? "未填写，复习时需要自评" : mistake.standardAnswer)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                }

                card("我的答案") {
                    Text(mistake.studentAnswer.isEmpty ? "未识别到我的答案" : mistake.studentAnswer)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                }

                card("掌握度信息") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("间隔级别")
                            Spacer()
                            Text("\(mistake.intervalIndex + 1)/5")
                        }
                        HStack {
                            Text("下次复习")
                            Spacer()
                            Text(mistake.nextReviewDate.formatted(.dateTime.year().month().day()))
                        }
                        ProgressView(value: Double(mistake.intervalIndex + 1), total: 5)
                    }
                    .font(.system(size: 14))
                }

                card("讲解笔记") {
                    TextField("添加讲解笔记", text: $notes, axis: .vertical)
                        .lineLimit(6, reservesSpace: true)
                        .padding(9)
                        .background(Theme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    if let path = mistake.notesImagePath,
                       let image = UIImage(contentsOfFile: path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    PhotosPicker(selection: $notePhotoItem, matching: .images) {
                        Label("🖼️ 添加图片笔记", systemImage: "photo.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Capsule().stroke(Theme.primary, lineWidth: 1.1))
                    }
                    if let noteError {
                        Text(noteError)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.danger)
                    }
                    Button("保存修改") {
                        var updated = mistake
                        updated.notes = notes
                        store.update(updated)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                card("复习历史") {
                    if store.reviewLogs(mistakeID: mistake.id).isEmpty {
                        Text("暂无复习记录")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.reviewLogs(mistakeID: mistake.id)) { log in
                                HStack {
                                    Image(systemName: log.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(log.correct ? Theme.secondary : Theme.danger)
                                    VStack(alignment: .leading) {
                                        Text(log.correct ? "回答正确" : "回答错误")
                                            .font(.system(size: 14, weight: .medium))
                                        Text(log.reviewTime.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Text("\(log.durationSeconds)秒")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 70)
        }
        .onAppear {
            notes = mistake.notes
        }
    }

    private func loadNotePhoto(_ item: PhotosPickerItem, mistakeID: String) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.85) else {
                throw NSError(domain: "TiXing.NoteImage", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "图片笔记读取失败，请重新选择"])
            }
            guard var mistake = store.mistake(id: mistakeID) else { return }
            mistake.notesImagePath = try store.saveNoteImage(jpeg, mistakeID: mistakeID)
            store.update(mistake)
            noteError = nil
        } catch {
            noteError = error.localizedDescription
        }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
    }
}
