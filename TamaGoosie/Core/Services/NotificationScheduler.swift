import Foundation
import UserNotifications
import SwiftData

final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let maxPerDay = 5
    private let quietHourStart = 22 // 10 PM
    private let quietHourEnd = 7    // 7 AM

    private init() {}

    // MARK: - Category Registration

    func registerCategories() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE",
            title: "Done!",
            options: []
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Remind me in 1 hour",
            options: []
        )
        let goalReminderCategory = UNNotificationCategory(
            identifier: "GOAL_REMINDER",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        let openAction = UNNotificationAction(
            identifier: "OPEN",
            title: "Check on Harold",
            options: [.foreground]
        )
        let gooseWarningCategory = UNNotificationCategory(
            identifier: "GOOSE_WARNING",
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )

        // Merge with existing categories from GooseNotificationSystem
        center.getNotificationCategories { existing in
            var categories = existing
            categories.insert(goalReminderCategory)
            categories.insert(gooseWarningCategory)
            self.center.setNotificationCategories(categories)
        }
    }

    // MARK: - Method 1: Schedule Goal Reminders

    func scheduleGoalReminders(goals: [Goal], completionEvents: [GoalCompletionEvent]) {
        for goal in goals where goal.isActive && !goal.isCompleted {
            let reminderHour: Int
            let reminderMinute: Int

            if let preferredTime = goal.preferredTime {
                // Case 1: Goal has a preferredTime — schedule 15 min before
                let calendar = Calendar.current
                let adjusted = calendar.date(byAdding: .minute, value: -15, to: preferredTime) ?? preferredTime
                reminderHour = calendar.component(.hour, from: adjusted)
                reminderMinute = calendar.component(.minute, from: adjusted)

                // Also schedule a follow-up 2 hours after preferredTime
                let followUpTime = calendar.date(byAdding: .hour, value: 2, to: preferredTime) ?? preferredTime
                let followUpHour = calendar.component(.hour, from: followUpTime)
                let followUpMinute = calendar.component(.minute, from: followUpTime)
                scheduleFollowUpReminder(
                    goal: goal,
                    hour: followUpHour,
                    minute: followUpMinute
                )
            } else {
                // Check completion events for this goal in the last 7 days
                let recentEvents = completionEvents.filter { event in
                    event.goalID == goal.id &&
                    event.completedAt > Date.now.addingTimeInterval(-7 * 86400)
                }

                if recentEvents.count >= 3 {
                    // Case 2: 3+ completion events — use average hour
                    let avgHour = recentEvents.map(\.hourOfDay).reduce(0, +) / recentEvents.count
                    reminderHour = avgHour
                    reminderMinute = 0
                } else {
                    // Case 3: Not enough data — default to 9 AM
                    reminderHour = 9
                    reminderMinute = 0
                }
            }

            guard !isQuietHour(reminderHour) else { continue }
            guard canScheduleToday() else { continue }

            let content = makeGoalReminderContent(goal: goal)

            var dateComponents = DateComponents()
            dateComponents.hour = reminderHour
            dateComponents.minute = reminderMinute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "goal-reminder-\(goal.id.uuidString)",
                content: content,
                trigger: trigger
            )
            schedule(request)
        }
    }

    // MARK: - Method 2: Schedule Follow-Ups

    func scheduleFollowUps(goals: [Goal]) {
        let calendar = Calendar.current
        let now = Date.now

        for goal in goals where goal.isActive && !goal.isCompleted {
            // Check if it's past the goal's reminder time
            let reminderHour: Int
            if let preferredTime = goal.preferredTime {
                reminderHour = calendar.component(.hour, from: preferredTime)
            } else {
                reminderHour = 9
            }

            let currentHour = calendar.component(.hour, from: now)
            guard currentHour >= reminderHour else { continue }
            guard canScheduleToday() else { continue }

            let twoHoursFromNow = now.addingTimeInterval(2 * 3600)
            let deliveryHour = calendar.component(.hour, from: twoHoursFromNow)
            guard !isQuietHour(deliveryHour) else { continue }

            let content = makeFollowUpContent(goal: goal)

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2 * 3600, repeats: false)
            let request = UNNotificationRequest(
                identifier: "goal-followup-\(goal.id.uuidString)",
                content: content,
                trigger: trigger
            )
            schedule(request)
        }
    }

    // MARK: - Method 3: Schedule State Notifications

    func scheduleStateNotifications(gooseState: GooseState) {
        let now = Date.now
        let currentHour = Calendar.current.component(.hour, from: now)
        guard !isQuietHour(currentHour) else { return }

        // Critical — bypasses cooldown and rate limit
        if gooseState.healthiness < 0.1 {
            let content = makeStateContent(
                title: "\(gooseState.name) really needs your help",
                body: "Harold really needs your help right now..."
            )
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "critical-warning",
                content: content,
                trigger: trigger
            )
            center.add(request)
            incrementDailyCount()
            return
        }

        // Health warning — 4 hour cooldown
        if gooseState.healthiness < 0.3 {
            let lastHealth = defaults.object(forKey: "last-health-warning") as? Date
            if lastHealth == nil || now.timeIntervalSince(lastHealth!) >= 4 * 3600 {
                guard canScheduleToday() else { return }
                let content = makeStateContent(
                    title: "\(gooseState.name) isn't feeling well",
                    body: "I'm not feeling my best... maybe we both need some fresh air?"
                )
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "health-warning",
                    content: content,
                    trigger: trigger
                )
                schedule(request)
                defaults.set(now, forKey: "last-health-warning")
            }
        }

        // Happiness warning — 4 hour cooldown
        if gooseState.happiness < 0.3 {
            let lastHappy = defaults.object(forKey: "last-happiness-warning") as? Date
            if lastHappy == nil || now.timeIntervalSince(lastHappy!) >= 4 * 3600 {
                guard canScheduleToday() else { return }
                let content = makeStateContent(
                    title: "\(gooseState.name) is feeling down",
                    body: "I've been a little down today. Want to tackle a goal together?"
                )
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "happiness-warning",
                    content: content,
                    trigger: trigger
                )
                schedule(request)
                defaults.set(now, forKey: "last-happiness-warning")
            }
        }
    }

    // MARK: - Method 4: Cancel All For Goal

    func cancelAllForGoal(goalID: UUID) {
        let ids = [
            "goal-reminder-\(goalID.uuidString)",
            "goal-followup-\(goalID.uuidString)"
        ]
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Method 5: Reschedule All

    func rescheduleAll(
        goals: [Goal],
        completionEvents: [GoalCompletionEvent],
        gooseState: GooseState,
        dailyLog: DailyLog? = nil
    ) {
        // Cancel all scheduler-managed notifications
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            let schedulerIDs = pending
                .filter {
                    $0.identifier.hasPrefix("goal-reminder-") ||
                    $0.identifier.hasPrefix("goal-followup-") ||
                    $0.identifier.hasPrefix("health-nudge-") ||
                    $0.identifier == "health-warning" ||
                    $0.identifier == "happiness-warning" ||
                    $0.identifier == "critical-warning" ||
                    $0.identifier == "all-goals-done" ||
                    $0.identifier.hasPrefix("streak-milestone-")
                }
                .map(\.identifier)
            self.center.removePendingNotificationRequests(withIdentifiers: schedulerIDs)

            // Reset daily counts for new day
            self.resetDailyCountIfNeeded()
            self.resetHealthNudgeCounts(goals: goals)

            // Rebuild
            self.scheduleGoalReminders(goals: goals, completionEvents: completionEvents)
            self.scheduleStateNotifications(gooseState: gooseState)
            self.scheduleHealthProgressNudges(
                goals: goals,
                dailyLog: dailyLog,
                gooseName: gooseState.name
            )
        }
    }

    // MARK: - Method 6: Health Progress Nudges

    /// Nudges the user about HealthKit-tracked goals they're behind on.
    ///
    /// Rules:
    /// - Afternoon only (1 PM+).
    /// - Only nudges when progress is **below 40%** of the goal target.
    /// - Max **1 nudge per goal per day** normally.
    /// - If progress is exactly **0** on first nudge, a second nudge
    ///   is allowed later in the evening (5-hour cooldown guarantees spacing).
    /// - 5-hour cooldown between nudges for the same goal.
    ///
    /// Call after every HealthKit data refresh.
    func scheduleHealthProgressNudges(goals: [Goal], dailyLog: DailyLog?, gooseName: String) {
        guard let log = dailyLog else { return }
        let now = Date.now
        let currentHour = Calendar.current.component(.hour, from: now)
        guard !isQuietHour(currentHour) else { return }
        guard currentHour >= 13 else { return }

        let urgency: HealthNudgeUrgency = currentHour >= 18 ? .urgent : .gentle

        for goal in goals where goal.isHealthKitTracked && goal.isActive && !goal.isCompleted {
            let progress = healthProgress(for: goal, log: log)
            // Only nudge when significantly behind — 40% or less
            guard progress < 0.40 else { continue }

            let nudgeCountKey = "health-nudge-count-\(goal.id.uuidString)"
            let nudgeTimeKey = "health-nudge-\(goal.id.uuidString)"
            let nudgesSentToday = defaults.integer(forKey: nudgeCountKey)

            // Max 2 nudges only when progress was 0 on first nudge; otherwise max 1
            let firstNudgeWasZeroKey = "health-nudge-zero-\(goal.id.uuidString)"
            let maxNudges = defaults.bool(forKey: firstNudgeWasZeroKey) ? 2 : 1
            guard nudgesSentToday < maxNudges else { continue }

            // 5-hour cooldown
            if let lastNudge = defaults.object(forKey: nudgeTimeKey) as? Date,
               now.timeIntervalSince(lastNudge) < 5 * 3600 {
                continue
            }

            guard canScheduleToday() else { return }

            let content = makeHealthNudgeContent(
                goal: goal,
                progress: progress,
                gooseName: gooseName,
                urgency: urgency
            )

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "health-nudge-\(goal.id.uuidString)",
                content: content,
                trigger: trigger
            )
            schedule(request)

            // Track nudge
            defaults.set(now, forKey: nudgeTimeKey)
            defaults.set(nudgesSentToday + 1, forKey: nudgeCountKey)
            if nudgesSentToday == 0 && progress == 0 {
                defaults.set(true, forKey: firstNudgeWasZeroKey)
            }
        }
    }

    /// Resets per-goal daily nudge counters. Call at midnight / rescheduleAll.
    func resetHealthNudgeCounts(goals: [Goal]) {
        for goal in goals where goal.isHealthKitTracked {
            defaults.removeObject(forKey: "health-nudge-count-\(goal.id.uuidString)")
            defaults.removeObject(forKey: "health-nudge-zero-\(goal.id.uuidString)")
            defaults.removeObject(forKey: "health-nudge-\(goal.id.uuidString)")
        }
    }

    private enum HealthNudgeUrgency {
        case gentle, urgent
    }

    /// Returns 0.0–1.0 progress for a HealthKit-tracked goal based on today's log.
    private func healthProgress(for goal: Goal, log: DailyLog) -> Double {
        guard goal.targetCount > 0 else { return 0 }
        if goal.title.localizedCaseInsensitiveContains("steps") || goal.title.localizedCaseInsensitiveContains("walk") {
            return Double(log.steps) / Double(goal.targetCount)
        } else if goal.title.localizedCaseInsensitiveContains("sleep") {
            return log.sleepHours / Double(goal.targetCount)
        } else if goal.title.localizedCaseInsensitiveContains("exercise") {
            return Double(log.exerciseMinutes) / Double(goal.targetCount)
        } else if goal.title.localizedCaseInsensitiveContains("outside") || goal.title.localizedCaseInsensitiveContains("daylight") {
            return Double(log.outsideMinutes) / Double(goal.targetCount)
        }
        return Double(goal.currentCount) / Double(goal.targetCount)
    }

    private func makeHealthNudgeContent(
        goal: Goal,
        progress: Double,
        gooseName: String,
        urgency: HealthNudgeUrgency
    ) -> UNMutableNotificationContent {
        let percent = Int(progress * 100)
        let remaining = remainingDescription(for: goal, progress: progress)

        let title: String
        let body: String

        switch urgency {
        case .gentle:
            title = "\(gooseName) peeking at your stats"
            let templates = [
                "You're at \(percent)% on \(goal.title) — \(remaining) to go. No rush yet!",
                "Hey! \(remaining) left for \(goal.title). Wanna get a head start? 🦆",
                "Harold noticed \(goal.title) could use some love today!"
            ]
            body = templates[Int.random(in: 0..<templates.count)]

        case .urgent:
            title = "\(gooseName) is getting worried"
            let templates = [
                "Only at \(percent)% on \(goal.title)... \(remaining) to go and the day's winding down!",
                "Harold's worried — \(remaining) left for \(goal.title) today!",
                "The day's almost over and \(goal.title) still needs \(remaining). You've got this!"
            ]
            body = templates[Int.random(in: 0..<templates.count)]
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "GOOSE_WARNING"
        content.userInfo = [
            "goalID": goal.id.uuidString,
            "goalTitle": goal.title,
            "type": "health_nudge"
        ]
        return content
    }

    /// Human-readable remaining amount, e.g. "4,200 steps" or "3.5 hours of sleep".
    private func remainingDescription(for goal: Goal, progress: Double) -> String {
        let remaining = max(0, Double(goal.targetCount) - Double(goal.targetCount) * progress)
        if goal.title.localizedCaseInsensitiveContains("steps") || goal.title.localizedCaseInsensitiveContains("walk") {
            return "\(Int(remaining).formatted()) steps"
        } else if goal.title.localizedCaseInsensitiveContains("sleep") {
            return String(format: "%.1f hours of sleep", remaining)
        } else if goal.title.localizedCaseInsensitiveContains("exercise") {
            return "\(Int(remaining)) min of exercise"
        } else if goal.title.localizedCaseInsensitiveContains("outside") || goal.title.localizedCaseInsensitiveContains("daylight") {
            return "\(Int(remaining)) min outside"
        }
        return "\(Int(remaining)) more"
    }

    // MARK: - Celebration Notifications

    func scheduleAllGoalsDone(gooseName: String) {
        guard canScheduleToday() else { return }
        let currentHour = Calendar.current.component(.hour, from: .now)
        guard !isQuietHour(currentHour) else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(gooseName) is thrilled!"
        content.body = "HONK! Every goal done today! I'm the happiest duck alive!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "all-goals-done", content: content, trigger: trigger)
        schedule(request)
    }

    func scheduleStreakMilestone(gooseName: String, days: Int) {
        guard days > 0, canScheduleToday() else { return }
        let currentHour = Calendar.current.component(.hour, from: .now)
        guard !isQuietHour(currentHour) else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(gooseName) is on fire!"
        content.body = "🔥 \(days) days in a row! We're unstoppable!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak-milestone-\(days)",
            content: content,
            trigger: trigger
        )
        schedule(request)
    }

    // MARK: - Snooze Handler

    func handleSnooze(goalID: UUID, goalTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "Reminder: \(goalTitle)"
        content.body = "Harold is still counting on you for \(goalTitle)!"
        content.sound = .default
        content.categoryIdentifier = "GOAL_REMINDER"
        content.userInfo = ["goalID": goalID.uuidString, "type": "snooze"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        let request = UNNotificationRequest(
            identifier: "goal-reminder-\(goalID.uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Private Helpers

    private func schedule(_ request: UNNotificationRequest) {
        center.add(request) { error in
            if let error { print("[NotificationScheduler] error: \(error)") }
        }
        incrementDailyCount()
    }

    private func makeGoalReminderContent(goal: Goal) -> UNMutableNotificationContent {
        let templates = [
            "Time to \(goal.title)! Let's do this together 🦆",
            "Hey! \(goal.title) is coming up. I believe in you!",
            "Reminder: \(goal.title). Harold is counting on you!"
        ]
        let content = UNMutableNotificationContent()
        content.title = "Harold says..."
        content.body = templates[Int.random(in: 0..<templates.count)]
        content.sound = .default
        content.categoryIdentifier = "GOAL_REMINDER"
        content.userInfo = [
            "goalID": goal.id.uuidString,
            "goalTitle": goal.title,
            "type": "goal_reminder"
        ]
        return content
    }

    private func makeFollowUpContent(goal: Goal) -> UNMutableNotificationContent {
        let templates = [
            "You haven't finished \(goal.title) yet today. Still time!",
            "Harold is waiting on \(goal.title)... no pressure though!"
        ]
        let content = UNMutableNotificationContent()
        content.title = "Harold checking in..."
        content.body = templates[Int.random(in: 0..<templates.count)]
        content.sound = .default
        content.categoryIdentifier = "GOAL_REMINDER"
        content.userInfo = [
            "goalID": goal.id.uuidString,
            "goalTitle": goal.title,
            "type": "goal_followup"
        ]
        return content
    }

    private func makeStateContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "GOOSE_WARNING"
        content.userInfo = ["type": "state_warning"]
        return content
    }

    private func scheduleFollowUpReminder(goal: Goal, hour: Int, minute: Int) {
        guard !isQuietHour(hour) else { return }
        guard canScheduleToday() else { return }

        let content = makeFollowUpContent(goal: goal)

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "goal-followup-\(goal.id.uuidString)",
            content: content,
            trigger: trigger
        )
        schedule(request)
    }

    // MARK: - Quiet Hours

    private func isQuietHour(_ hour: Int) -> Bool {
        hour >= quietHourStart || hour < quietHourEnd
    }

    // MARK: - Rate Limiting

    private var dailyCountKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "notif-count-\(formatter.string(from: .now))"
    }

    private func canScheduleToday() -> Bool {
        defaults.integer(forKey: dailyCountKey) < maxPerDay
    }

    private func incrementDailyCount() {
        let current = defaults.integer(forKey: dailyCountKey)
        defaults.set(current + 1, forKey: dailyCountKey)
    }

    private func resetDailyCountIfNeeded() {
        // Count resets naturally via date-based key — no explicit reset needed
    }
}
