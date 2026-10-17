import EventKit
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

enum ReminderDelivery: Equatable {
    case agent
    case calendar
}

struct ReminderService {
    static func apply(_ settings: ReminderSettings) async throws -> ReminderDelivery {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["tixing.review.daily"])
        center.removeDeliveredNotifications(withIdentifiers: ["tixing.review.daily"])

        guard settings.enabled else {
            try? await removeCalendarReminder()
            return .agent
        }

        let notificationsGranted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if notificationsGranted {
            let content = UNMutableNotificationContent()
            content.title = "题醒 · 复习时间到"
            content.body = "醒醒已经准备好今天的错题，点进来一起复习吧。"
            content.sound = .default
            var components = DateComponents()
            components.hour = settings.startMinutes / 60
            components.minute = settings.startMinutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "tixing.review.daily", content: content, trigger: trigger)
            try await center.add(request)
            return .agent
        }

        return try await createCalendarReminder(minutes: settings.startMinutes)
    }

    private static func removeCalendarReminder() async throws {
        let store = EKEventStore()
        guard await requestCalendarAccess(store) else { return }
        let calendars = store.calendars(for: .event).filter { $0.title == "题醒复习" }
        for calendar in calendars {
            let predicate = store.predicateForEvents(withStart: .distantPast, end: .distantFuture, calendars: [calendar])
            store.events(matching: predicate).forEach { try? store.remove($0, span: .thisEvent) }
        }
    }

    private static func createCalendarReminder(minutes: Int) async throws -> ReminderDelivery {
        let store = EKEventStore()
        guard await requestCalendarAccess(store) else {
            throw NSError(domain: "TiXing.Reminder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "应用通知未开启，且日历提醒不可用：请在系统设置中开启通知或日历权限"])
        }

        let calendar: EKCalendar
        if let existing = store.calendars(for: .event).first(where: { $0.title == "题醒复习" }) {
            calendar = existing
        } else {
            calendar = EKCalendar(for: .event, eventStore: store)
            calendar.title = "题醒复习"
            calendar.cgColor = UIColor.systemPurple.cgColor
            guard let source = store.sources.first(where: { $0.sourceType == .local })
                ?? store.sources.first(where: { $0.sourceType == .calDAV }) else {
                throw NSError(domain: "TiXing.Reminder", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "没有可用日历账户，无法创建日历提醒"])
            }
            calendar.source = source
            try store.saveCalendar(calendar, commit: true)
        }

        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = "题醒复习"
        event.notes = "和孩子一起完成今日错题复习"
        event.startDate = nextDate(minutes: minutes)
        event.endDate = event.startDate.addingTimeInterval(15 * 60)
        let alarm = EKAlarm(relativeOffset: 0)
        event.addAlarm(alarm)
        let rule = EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        event.recurrenceRules = [rule]
        try store.save(event, span: .thisEvent)
        return .calendar
    }

    private static func requestCalendarAccess(_ store: EKEventStore) async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    private static func nextDate(minutes: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = minutes / 60
        components.minute = minutes % 60
        let date = calendar.date(from: components) ?? Date()
        return date > Date() ? date : date.addingTimeInterval(86_400)
    }
}
