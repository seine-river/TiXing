// xcode: set sdk=iOS

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("题醒")
                    .font(.system(size: 34, weight: .bold))
                    .padding(.top, 25)
                Text("智能错题记录与科学复习工具")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Text("v1.0.3")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.primary)
                AppCard {
                    VStack(spacing: 9) {
                        row("应用名称", "题醒")
                        row("当前版本", "1.0.3")
                    }
                }
                AppCard {
                    Text("题醒是一款面向小学生家庭的智能错题本。孩子拍照录入错题后，AI 会识别题目、学生答案和知识点；系统按遗忘曲线安排复习，并把错题讲解变成更容易理解的动画课程。")
                        .font(.system(size: 14))
                        .lineSpacing(6)
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("关于题醒")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.textPrimary)
        }
        .font(.system(size: 14))
    }
}
