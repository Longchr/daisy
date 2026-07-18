import Foundation
import UserNotifications

enum RecurringReminderNotification {
    static let reminderIDKey = "recurringReminderID"
    static let pendingReminderDefaultsKey = "recurringReminder.pendingID"
}

extension Notification.Name {
    static let openRecurringReminder = Notification.Name("daisy.openRecurringReminder")
}

enum RecurringReminderScheduler {
    static func notificationIdentifier(for reminderID: UUID) -> String {
        "daisy.recurring.\(reminderID.uuidString)"
    }

    static func schedule(_ reminder: RecurringReminder) async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let identifier = notificationIdentifier(for: reminder.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard reminder.isEnabled else { return true }

        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
            status = await center.notificationSettings().authorizationStatus
        }

        guard status == .authorized || status == .provisional else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Daisy 账单提醒"
        content.body = "一笔周期账单预计今天发生，打开 Daisy 确认后记账。"
        content.sound = .default
        content.userInfo = [RecurringReminderNotification.reminderIDKey: reminder.id.uuidString]

        var components = DateComponents()
        components.day = reminder.dayOfMonth
        components.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await center.add(request)
        return true
    }

    static func remove(reminderID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier(for: reminderID)]
        )
    }
}
