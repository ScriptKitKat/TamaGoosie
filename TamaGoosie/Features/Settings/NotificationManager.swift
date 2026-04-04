import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private let maxPerDay = 5
    private let quietHourStart = 22 // 10pm
    private let quietHourEnd = 7    // 7am

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    // MARK: - Schedule All Notifications

    func rescheduleAll(gooseName: String, healthiness: Double, happiness: Double, goals: [GoalNotificationInfo]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        var scheduled = 0

        // State-based urgent notification (once)
        if let urgent = urgentStateNotification(name: gooseName, healthiness: healthiness, happiness: happiness) {
            schedule(urgent)
            scheduled += 1
        }

        // Goal reminders
        for goal in goals where scheduled < maxPerDay {
            if let req = goalReminderNotification(goal: goal, gooseName: gooseName) {
                schedule(req)
                scheduled += 1
            }
        }

        // Morning check-in (always)
        if scheduled < maxPerDay {
            scheduleMorningReminder(gooseName: gooseName, healthiness: healthiness)
        }
    }

    // MARK: - Morning Reminder

    func scheduleMorningReminder(gooseName: String, healthiness: Double, hour: Int = 8, minute: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = morningTitle(healthiness: healthiness)
        content.body = morningBody(name: gooseName, healthiness: healthiness)
        content.sound = .default
        content.badge = 1

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "morning_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - State-Based Notification

    private func urgentStateNotification(name: String, healthiness: Double, happiness: Double) -> UNNotificationRequest? {
        let message: (title: String, body: String)?

        switch (healthiness, happiness) {
        case (..<0.15, _):
            message = ("⚠️ \(name) is in danger!", "I'm so sick... I don't know how much longer I can hold on. Please help me!")
        case (_, ..<0.15):
            message = ("💔 \(name) misses you", "I've been alone all day and I'm so sad. Please come back soon...")
        case (..<0.3, ..<0.3):
            message = ("😰 \(name) needs you now!", "I'm not feeling well and I'm really unhappy. Things are getting bad...")
        case (..<0.3, _):
            message = ("🤒 \(name) is feeling sick", "I'm not feeling great. A little care would go a long way!")
        case (_, ..<0.3):
            message = ("😢 \(name) is sad", "I'm feeling pretty down. Could you complete some of your goals for me?")
        default:
            return nil
        }

        guard let message else { return nil }

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default

        // Schedule 1 hour from now if not in quiet hours
        let deliveryHour = Calendar.current.component(.hour, from: Date.now.addingTimeInterval(3600))
        guard !isQuietHour(deliveryHour) else { return nil }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        return UNNotificationRequest(identifier: "state_alert_\(UUID().uuidString)", content: content, trigger: trigger)
    }

    // MARK: - Goal Reminder

    private func goalReminderNotification(goal: GoalNotificationInfo, gooseName: String) -> UNNotificationRequest? {
        guard !goal.isCompleted, let hour = goal.preferredHour else { return nil }
        guard !isQuietHour(hour) else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "🪿 \(gooseName) reminder"
        content.body = goalReminderBody(goalTitle: goal.title, completionRate: goal.recentCompletionRate)
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = goal.preferredMinute ?? 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        return UNNotificationRequest(
            identifier: "goal_\(goal.id.uuidString)",
            content: content,
            trigger: trigger
        )
    }

    // MARK: - Streak Celebration

    func scheduleStreakCelebration(gooseName: String, streakDays: Int) {
        guard streakDays > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "🔥 \(streakDays)-day streak!"
        content.body = "Woohoo! We're on a \(streakDays)-day streak! I'm feeling fantastic. Keep it up!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "streak_\(streakDays)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Decay Warning

    func scheduleDecayWarning(gooseName: String, healthiness: Double, happiness: Double) {
        let lowestStat = min(healthiness, happiness)
        guard lowestStat < 0.4 else { return }

        let currentHour = Calendar.current.component(.hour, from: .now)
        guard !isQuietHour(currentHour) else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(gooseName) needs attention"
        content.body = lowestStat < 0.2
            ? "I'm really struggling... please open the app."
            : "I'm starting to feel worse. Don't forget about me today!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "decay_warning", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Remove

    func cancelGoalReminder(goalID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["goal_\(goalID.uuidString)"])
    }

    // MARK: - Helpers

    private func schedule(_ request: UNNotificationRequest) {
        UNUserNotificationCenter.current().add(request)
    }

    private func isQuietHour(_ hour: Int) -> Bool {
        hour >= quietHourStart || hour < quietHourEnd
    }

    private func morningTitle(healthiness: Double) -> String {
        if healthiness > 0.7 { return "Good morning! 🌅" }
        if healthiness > 0.4 { return "Good morning... 🌤️" }
        return "Please help me today 🥺"
    }

    private func morningBody(name: String, healthiness: Double) -> String {
        if healthiness > 0.7 { return "\(name) slept well and is ready for a great day!" }
        if healthiness > 0.4 { return "I'm okay, but I could really use your help with some goals today." }
        return "I didn't sleep well and I'm not feeling great. I really need you today."
    }

    private func goalReminderBody(goalTitle: String, completionRate: Double) -> String {
        if completionRate < 0.4 {
            return "You've been missing '\(goalTitle)' a lot lately. Maybe try a smaller version?"
        }
        return "Don't forget about '\(goalTitle)' today! I'm counting on you 🪿"
    }
}

// MARK: - GoalNotificationInfo

struct GoalNotificationInfo {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let preferredHour: Int?
    let preferredMinute: Int?
    let recentCompletionRate: Double // 0.0–1.0 over last 7 days
}
