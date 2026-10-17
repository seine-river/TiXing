import SwiftUI
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    static var writableContentTypes: [UTType] { [.zip] }

    private let storage: PersistentStore

    @MainActor
    init(store: AppStore) {
        storage = store.storage
    }

    init(configuration: ReadConfiguration) throws {
        storage = PersistentStore()
    }

    func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifest = BackupManifest(app: "tixing", version: BackupService.bundleVersion,
                                      exportedAt: Date(), studentId: storage.student.id)
        var allEntries: [(String, Data)] = [
            ("manifest.json", try encoder.encode(manifest)),
            ("data.json", try BackupCompatibility.encode(storage: storage, exportedAt: Date(), studentID: storage.student.id))
        ]
        allEntries.append(contentsOf: assetEntries())
        try ZipService.write(entries: allEntries, to: url)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TiXing-backup-\(UUID().uuidString).zip")
        try write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return try FileWrapper(url: url, options: .immediate)
    }

    private func assetEntries() -> [(name: String, data: Data)] {
        var assets: [(String, Data)] = []
        for mistake in storage.mistakes {
            if let path = mistake.imagePath,
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                assets.append(("images/\(mistake.id).jpg", data))
            }
        }
        for mistake in storage.mistakes {
            if let path = mistake.notesImagePath,
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                assets.append(("notes/\(mistake.id).jpg", data))
            }
        }
        for record in storage.voiceAsks {
            if let path = record.audioPath,
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                let ext = path.lowercased().hasSuffix(".mp3") ? "mp3" : "wav"
                assets.append(("audio/\(record.id).\(ext)", data))
            }
        }
        return assets
    }
}

struct DataManagementView: View {
    @EnvironmentObject private var store: AppStore
    @State private var exporting = false
    @State private var importing = false
    @State private var preview: BackupPreview?
    @State private var busyText: String?
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 13) {
                if let busyText {
                    AppCard {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(busyText)
                        }
                    }
                }
                if let errorText { ErrorBanner(message: errorText) }

                AppCard {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("导出数据").font(.system(size: 17, weight: .bold))
                        Text("打包错题、复习记录、图片、问一问记录、好奇星球报告与原始录音后，会弹出系统保存窗口，由你选择备份文件的存储位置和文件名。")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                        Button("导出到指定位置（zip）") { exporting = true }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("导入数据").font(.system(size: 17, weight: .bold))
                        Text("选择本应用导出的 zip 备份文件，导入前会先解析预览，需逐条核对确认。")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                        Button("选择文件并预览") { importing = true }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }

                if let preview {
                    previewCard(preview)
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("导出与导入")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exporting,
                      document: BackupDocument(store: store),
                      contentType: .zip,
                      defaultFilename: "TiXing-backup") { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                errorText = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.zip]) { result in
            switch result {
            case .success(let url):
                Task { await importBackup(url: url) }
            case .failure(let error):
                errorText = error.localizedDescription
            }
        }
    }

    private func previewCard(_ preview: BackupPreview) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("备份预览").font(.system(size: 16, weight: .bold))
                row("备份时间", preview.manifest.exportedAt.formatted(date: .abbreviated, time: .shortened))
                row("错题", "\(preview.mistakeCount) 条")
                row("复习记录", "\(preview.reviewCount) 条")
                row("问一问", "\(preview.voiceCount) 条")
                row("好奇星球报告", "\(preview.insightCount) 份")
                Button("确认导入") {
                    store.importBackup(preview)
                    self.preview = nil
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("取消") { self.preview = nil }
                    .foregroundStyle(Theme.danger)
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.textPrimary)
        }
        .font(.system(size: 13))
    }

    private func importBackup(url: URL) async {
        busyText = "正在解析备份包..."
        errorText = nil
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            preview = try await BackupService.preview(at: url, currentStudent: store.student)
        } catch {
            errorText = error.localizedDescription
        }
        busyText = nil
    }
}
