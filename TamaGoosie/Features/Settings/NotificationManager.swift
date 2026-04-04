import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    // MARK: - Schedule Notifications

    func scheduleMorningReminder(gooseName: String, hour: Int = 8, minute: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = "Good morning!"
        content.body = "\(gooseName) is waiting for you 🪿"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "morning_reminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}
