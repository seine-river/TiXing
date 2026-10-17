import SwiftUI

struct VoiceAskDetailView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var player = AudioPlaybackService()
    private let recordID: String

    init(recordID: String) {
        self.recordID = recordID
    }

    private var record: VoiceAskRecord? {
        store.voiceAsks.first { $0.id == recordID }
    }

    var body: some View {
        Group {
            if let record {
                content(record)
            } else {
                EmptyBlock(message: "没有找到这条问一问记录")
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("问题回忆")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player.stop() }
    }

    private func content(_ record: VoiceAskRecord) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("🎧 当时的声音")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Button {
                        if let path = record.audioPath {
                            let url = URL(fileURLWithPath: path)
                            if player.playingID == record.id {
                                player.stop()
                            } else {
                                player.play(url: url, id: record.id)
                            }
                        }
                    } label: {
                        Label(player.playingID == record.id ? "停止播放" : "播放原始录音 · \(record.audioDuration)秒",
                              systemImage: player.playingID == record.id ? "stop.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(.white))
                    }
                    .buttonStyle(.plain)
                    .disabled(record.audioPath == nil)
                    if let playerError = player.errorMessage {
                        Text(playerError)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text("这段录音会一直保存在本机，并随备份一起导出")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 26).fill(Theme.heroGradient))

                infoCard("我的问题", record.question.isEmpty ? "这条记录还没有转写文字" : record.question)
                infoCard("醒醒的回答", record.answer.isEmpty ? "这条记录还没有生成回答" : record.answer)

                AppCard {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("归档位置").font(.system(size: 15, weight: .bold))
                        FlowTags(tags: [record.topic, "#" + record.topic] + record.interestTags.map { "#" + $0 })
                        Text(record.createdAt.formatted(date: .long, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(16)
        }
    }

    private func infoCard(_ title: String, _ text: String) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 15, weight: .bold))
                Text(text)
                    .font(.system(size: 15))
                    .lineSpacing(6)
            }
        }
    }
}

struct FlowTags: View {
    let tags: [String]
    @State private var tagsWidth: CGFloat = 0

    var body: some View {
        var rows: [[String]] = []
        var current: [String] = []
        for tag in tags.filter({ !$0.isEmpty }) {
            current.append(tag)
            if current.count == 3 {
                rows.append(current)
                current = []
            }
        }
        if !current.isEmpty { rows.append(current) }
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { tag in
                        TagPill(text: tag, color: Theme.primary)
                    }
                }
            }
        }
    }
}
