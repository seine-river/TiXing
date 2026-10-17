import SwiftUI

struct MistakesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var keyword = ""
    @State private var subject: Subject?
    @State private var status: MistakeStatus?
    @State private var errorType: ErrorType?

    private var filtered: [Mistake] {
        store.mistakes.filter { mistake in
            let keywordOK = keyword.isEmpty || mistake.question.localizedCaseInsensitiveContains(keyword)
                || mistake.knowledgeSummary.localizedCaseInsensitiveContains(keyword)
                || mistake.tags.contains { $0.localizedCaseInsensitiveContains(keyword) }
            let subjectOK = subject == nil || mistake.subject == subject
            let statusOK = status == nil || mistake.status == status
            let errorOK = errorType == nil || mistake.errorType == errorType
            return keywordOK && subjectOK && statusOK && errorOK
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 10) {
                    filterRows
                    if filtered.isEmpty {
                        AppCard { EmptyBlock(message: "还没有错题，快去录入吧") }
                            .padding(.top, 30)
                    } else {
                        ForEach(filtered) { mistake in
                            NavigationLink {
                                MistakeDetailView(mistakeID: mistake.id)
                            } label: {
                                MistakeRow(mistake: mistake)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    confirmDelete(mistake)
                                } label: { Label("删除错题", systemImage: "trash") }
                            }
                        }
                        Text("已加载全部错题")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 6)
                    }
                }
                .padding(16)
                .padding(.bottom, 70)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("错题本")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text("错题本")
                    .font(.system(size: 27, weight: .bold))
                Spacer()
                Text("\(filtered.count)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.primary))
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                TextField("搜索题目 / 知识点", text: $keyword)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 13)
            .frame(height: 44)
            .background(Capsule().fill(Color.white))
            .shadow(color: Color.black.opacity(0.04), radius: 7, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var filterRows: some View {
        VStack(spacing: 7) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "🌈 全部", selected: subject == nil) { subject = nil }
                    ForEach(Subject.allCases) { value in
                        FilterChip(title: "\(value.emoji) \(value.label)", selected: subject == value) {
                            subject = subject == value ? nil : value
                        }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MistakeStatus.allCases) { value in
                        FilterChip(title: value.label, selected: status == value) {
                            status = status == value ? nil : value
                        }
                    }
                    ForEach(ErrorType.allCases) { value in
                        FilterChip(title: value.label, selected: errorType == value) {
                            errorType = errorType == value ? nil : value
                        }
                    }
                }
            }
        }
    }

    private func confirmDelete(_ mistake: Mistake) {
        store.delete(mistake)
    }
}
