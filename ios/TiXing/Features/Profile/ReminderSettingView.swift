import SwiftUI

struct ReminderSettingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var draft = ReminderSettings()
    @State private var saving = false
    @State private var resultText = ""
    @State private var resultOK = true

    var body: some View {
        Form {
            Section {
                Toggle("开启复习提醒", isOn: $draft.enabled)
            } footer: {
                Text("若设备限制应用通知，将自动改为写入系统日历，仍按开始时间提醒")
            }
            Section("复习时间段") {
                timeRow("开始时间", minutes: $draft.startMinutes)
                timeRow("结束时间", minutes: $draft.endMinutes)
            }
            Section("每日复习题量上限") {
                Stepper(value: $draft.dailyLimit, in: 1...20) {
                    Text("\(draft.dailyLimit) 题")
                        .font(.system(size: 20, weight: .bold))
                }
            }
            Section("学科开关") {
                ForEach(Subject.allCases) { subject in
                    Toggle(subject.label, isOn: binding(for: subject))
                }
            }
            Section {
                Button(saving ? "保存中..." : "保存设置") { save() }
                    .disabled(saving)
                if !resultText.isEmpty {
                    Text(resultText)
                        .foregroundStyle(resultOK ? Theme.secondary : Theme.danger)
                }
            }
        }
        .navigationTitle("复习提醒设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { draft = store.settings }
    }

    private func timeRow(_ title: String, minutes: Binding<Int>) -> some View {
        DatePicker(title, selection: Binding(
            get: { Calendar.current.date(bySettingHour: minutes.wrappedValue / 60,
                                         minute: minutes.wrappedValue % 60, second: 0, of: Date()) ?? Date() },
            set: { value in
                let components = Calendar.current.dateComponents([.hour, .minute], from: value)
                minutes.wrappedValue = (components.hour ?? 8) * 60 + (components.minute ?? 0)
            }), displayedComponents: .hourAndMinute)
    }

    private func binding(for subject: Subject) -> Binding<Bool> {
        Binding(
            get: { draft.subjects.contains(subject) },
            set: { enabled in
                if enabled { draft.subjects.insert(subject) } else { draft.subjects.remove(subject) }
            })
    }

    private func save() {
        saving = true
        resultText = ""
        Task {
            do {
                let delivery = try await ReminderService.apply(draft)
                store.updateSettings(draft)
                resultOK = true
                resultText = delivery == .calendar ? "成功设置日历" : "成功设置复习提醒"
            } catch {
                resultOK = false
                resultText = error.localizedDescription
            }
            saving = false
        }
    }
}
