import SwiftUI

struct ProfileSettingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var nickname = ""
    @State private var grade: Grade = .three
    @State private var textbook: TextbookVersion = .pep

    var body: some View {
        Form {
            Section("昵称") {
                TextField("请输入昵称", text: $nickname)
            }
            Section("年级") {
                Picker("年级", selection: $grade) {
                    ForEach(Grade.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section("教材版本") {
                Picker("教材版本", selection: $textbook) {
                    ForEach(TextbookVersion.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section {
                Button("保存") {
                    var student = store.student
                    student.nickname = nickname.isEmpty ? "同学" : nickname
                    student.grade = grade
                    student.textbookVersion = textbook
                    store.updateStudent(student)
                }
            }
        }
        .navigationTitle("学习档案")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            nickname = store.student.nickname
            grade = store.student.grade
            textbook = store.student.textbookVersion
        }
    }
}
