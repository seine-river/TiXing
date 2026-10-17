import SwiftUI

struct VoiceAskListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var keyword = ""
    @State private var subjectFilter: String?

    private var filtered: [VoiceAskRecord] {
        store.voiceAsks.filter { record in
            let keywordOK = keyword.isEmpty || record.question.localizedCaseInsensitiveContains(keyword)
                || record.answer.localizedCaseInsensitiveContains(keyword)
                || record.topic.localizedCaseInsensitiveContains(keyword)
            let subjectOK = subjectFilter == nil || record.subject == subjectFilter
            return keywordOK && subjectOK
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    Text("我的问一问")
                        .font(.system(size: 25, weight: .bold))
                    Spacer()
                    Text("\(filtered.count)")
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Theme.primary))
                }
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    TextField("搜索问题、回答或主题", text: $keyword)
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(Capsule().fill(.white))
            }
            .padding(16)

            ScrollView {
                VStack(spacing: 9) {
                    filterChips
                    if filtered.isEmpty {
                        AppCard { EmptyBlock(message: "还没有问一问记录，点中间麦克风开始提问") }
                    } else {
                        ForEach(filtered) { record in
                            NavigationLink {
                                VoiceAskDetailView(recordID: record.id)
                            } label: {
                                VoiceAskRow(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("我的问一问")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "全部领域", selected: subjectFilter == nil) { subjectFilter = nil }
                ForEach(["math", "chinese", "english", "science", "technology", "life", "other"], id: \.self) { value in
                    FilterChip(title: subjectLabel(value), selected: subjectFilter == value) {
                        subjectFilter = subjectFilter == value ? nil : value
                    }
                }
            }
        }
    }

    private func subjectLabel(_ value: String) -> String {
        let map = ["math": "数学", "chinese": "语文", "english": "英语", "science": "科学",
                   "history": "历史", "geography": "地理", "technology": "科技", "life": "生活",
                   "art": "艺术", "sports": "运动"]
        return map[value] ?? "其他"
    }
}

struct VoiceAskRow: View {
    let record: VoiceAskRecord

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("🔊")
                .font(.system(size: 20))
                .frame(width: 40, height: 40)
                .background(Theme.softPrimary)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(record.question.isEmpty ? "这条记录还没有转写文字" : record.question)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(record.answer)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                HStack(spacing: 5) {
                    TagPill(text: record.topic.isEmpty ? "未分类" : record.topic, color: Theme.primary)
                    Text(record.createdAt.formatted(.dateTime.year().month().day()))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(13)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }
}
