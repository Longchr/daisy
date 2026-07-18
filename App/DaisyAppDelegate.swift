import UIKit
import UserNotifications

final class DaisyAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let reminderID = response.notification.request.content.userInfo[
            RecurringReminderNotification.reminderIDKey
        ] as? String {
            UserDefaults.standard.set(
                reminderID,
                forKey: RecurringReminderNotification.pendingReminderDefaultsKey
            )
            NotificationCenter.default.post(name: .openRecurringReminder, object: reminderID)
        }
        completionHandler()
    }
}
