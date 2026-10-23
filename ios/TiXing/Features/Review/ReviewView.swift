import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var store: AppStore
    @State private var queue: [Mistake] = []
    @State private var index = 0
    @State private var answer = ""
    @State private var result: AppStore.ReviewResult?
    @State private var finished = false
    @State private var startTime = Date()
    @State private var correctCount = 0
    @State private var earnedPoints = 0

    var body: some View {
        Group {
            if finished {
                summary
            } else if queue.isEmpty {
                EmptyBlock(message: "今天没有需要复习的错题")
                    .padding(30)
            } else if index < queue.count {
                questionView(queue[index])
            } else {
                summary
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("复习错题")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if queue.isEmpty {
                queue = store.todayReviewQueue
                startTime = Date()
            }
        }
    }

    private func questionView(_ mistake: Mistake) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Text("\(index + 1)/\(queue.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.primary)
                    ProgressView(value: Double(index + 1), total: Double(queue.count))
                        .tint(Theme.primary)
                }
                .padding(.top, 10)

                AppCard {
                    Text(mistake.question)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(5)
                }

                if let result {
                    resultCard(mistake, result: result)
                } else {
                    answerCard(mistake)
                }
            }
            .padding(16)
            .padding(.bottom, 65)
        }
    }

    @ViewBuilder
    private func answerCard(_ mistake: Mistake) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("作答")
                    .font(.system(size: 16, weight: .medium))
                if mistake.answerType == .numeric {
                    TextField("请输入数字答案", text: $answer)
                        .keyboardType(.numbersAndPunctuation)
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(Theme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button("提交答案") {
                        submit(mistake)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else if mistake.answerType == .subjective || mistake.standardAnswer.isEmpty {
                    Text("这道题没有标准答案，请先写下你的回答，再自评是否一致。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    TextField("请输入答案", text: $answer, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                        .padding(12)
                        .background(Theme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    HStack(spacing: 8) {
                        Button {
                            submit(mistake, subjectiveCorrect: true)
                        } label: { Text("✓ 一致，已掌握") }
                            .buttonStyle(PrimaryButtonStyle())
                        Button {
                            submit(mistake, subjectiveCorrect: false)
                        } label: { Text("✗ 不一致") }
                            .buttonStyle(.plain)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Capsule().fill(Theme.danger))
                    }
                } else {
                    TextField("请输入答案", text: $answer, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .font(.system(size: 17))
                        .padding(12)
                        .background(Theme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button("提交答案") { submit(mistake) }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func resultCard(_ mistake: Mistake, result: AppStore.ReviewResult) -> some View {
        AppCard {
            VStack(spacing: 12) {
                Text(result.correct ? "🎉 回答正确" : "💪 回答错误")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(result.correct ? Theme.secondary : Theme.danger)
                if !result.correct && !mistake.standardAnswer.isEmpty {
                    Text("正确答案：\(mistake.standardAnswer)")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textRegular)
                }
                NavigationLink {
                    LessonVideoView(mistakeID: mistake.id)
                } label: {
                    Label(hasCachedLesson(mistake) ? "播放讲解视频" : "生成讲解视频",
                          systemImage: hasCachedLesson(mistake) ? "play.rectangle.fill" : "wand.and.stars")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Capsule().stroke(Theme.primary, lineWidth: 1.4))
                }
                .buttonStyle(.plain)
                Button(index + 1 < queue.count ? "下一题" : "完成复习") {
                    next()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func hasCachedLesson(_ mistake: Mistake) -> Bool {
        LessonCacheService.hasCachedLesson(
            mistakeID: mistake.id,
            sourceFingerprint: LessonCacheService.sourceFingerprint(
                mistake: mistake, grade: store.student.grade))
    }

    private var summary: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("🎉 ✨ 🎈 ✨ 🎉")
                    .font(.system(size: 20))
                    .padding(.top, 40)
                Text("🏆")
                    .font(.system(size: 62))
                    .frame(width: 112, height: 112)
                    .background(Circle().fill(Theme.softWarning))
                Text("复习总结")
                    .font(.system(size: 25, weight: .bold))
                HStack(spacing: 18) {
                    summaryItem("\(correctCount)", "答对了")
                    summaryItem("\(queue.count - correctCount)", "再练练")
                    summaryItem("+\(earnedPoints)", "赢积分")
                }
                Text(correctCount == queue.count ? "太棒了，继续保持！🌟" : "别灰心，每道错题都是进步的台阶 🌱")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                Button("返回首页") { finished = true }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
        }
    }

    private func summaryItem(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.primary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(width: 86, height: 78)
        .background(RoundedRectangle(cornerRadius: 17).fill(Color.white))
    }

    private func submit(_ mistake: Mistake, subjectiveCorrect: Bool? = nil) {
        guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || subjectiveCorrect != nil else { return }
        let duration = max(1, Int(Date().timeIntervalSince(startTime)))
        if let value = store.submitReview(mistakeID: mistake.id, answer: answer,
                                          duration: duration, subjectiveCorrect: subjectiveCorrect) {
            result = value
            if value.correct { correctCount += 1 }
            earnedPoints += value.points
        }
    }

    private func next() {
        result = nil
        answer = ""
        startTime = Date()
        if index + 1 < queue.count {
            index += 1
        } else {
            finished = true
        }
    }
}
