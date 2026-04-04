import Foundation
import UserNotifications

// MARK: - Goose Notification System

/// Orchestrates all three notification types. Isolated from game logic —
/// only needs Goal models and a goose name string.
final class GooseNotificationSystem {
    static let shared = GooseNotificationSystem()
    private let center = UNUserNotificationCenter.current()
    private init() {}

    // MARK: - Setup

    func registerCategories() {
        let pushCategory = UNNotificationCategory(
            identifier: "PUSH_CATEGORY",
            actions: [
                UNNotificationAction(identifier: "ACK",  title: "i'm on it!",   options: []),
                UNNotificationAction(identifier: "BUSY", title: "i'm busy...",  options: [.foreground])
            ],
            intentIdentifiers: [],
            options: []
        )
        let resetCategory = UNNotificationCategory(
            identifier: "RESET_CATEGORY",
            actions: [
                UNNotificationAction(identifier: "UPDATE", title: "let's change it", options: [.foreground]),
                UNNotificationAction(identifier: "HARDER", title: "i'll try harder",  options: [])
            ],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([pushCategory, resetCategory])
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    // MARK: - Main Entry Point

    func rescheduleAll(goals: [Goal], gooseName: String) async {
        let pending = await center.pendingNotificationRequests()

        // Remove all Type 1 (reminder_*) and Type 3 (reset_*) — they're fully rebuilt each call.
        // Type 2 push_* notifications are self-managed and only touched when the chain needs starting/restarting.
        let removeIDs = pending
            .filter { $0.identifier.hasPrefix("reminder_") || $0.identifier.hasPrefix("reset_") }
            .map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: removeIDs)

        for goal in goals where goal.isActive {
            // Type 1: Reminder at preferred time
            if !goal.isCompleted, let preferredTime = goal.preferredTime {
                await scheduleReminder(goal: goal, preferredTime: preferredTime)
            }

            // Type 2: Aggressive push if behind schedule
            if !goal.isCompleted && !EscalationTracker.shared.isPaused(for: goal.id) {
                if isBehindSchedule(goal: goal) {
                    let hasPendingPush = pending.contains {
                        $0.identifier.hasPrefix("push_\(goal.id.uuidString)")
                    }
                    if !hasPendingPush {
                        let nextLevel = EscalationTracker.shared.state(for: goal.id).scheduledThroughLevel + 1
                        await scheduleAggressivePush(goal: goal, startLevel: nextLevel)
                    }
                }
            }

            // Type 3: Reset suggestion if consistently failing
            let esc = EscalationTracker.shared.state(for: goal.id)
            if shouldSuggestReset(goal: goal, failures: esc.consecutiveFailures) {
                await scheduleResetSuggestion(goal: goal, failures: esc.consecutiveFailures)
            }
        }
    }

    // MARK: - Public Actions

    /// Call when a goal is completed or deleted.
    func cancelPushes(for goalID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: pushIDs(for: goalID))
        EscalationTracker.shared.reset(for: goalID)
    }

    /// Call when user taps "i'm on it!" on a push notification.
    func markAcknowledged(goalID: UUID) {
        cancelPushes(for: goalID)
        EscalationTracker.shared.resetFailures(for: goalID)
    }

    /// Call from negotiation result when user is believed.
    func pausePushes(goalID: UUID, hours: Int) {
        center.removePendingNotificationRequests(withIdentifiers: pushIDs(for: goalID))
        EscalationTracker.shared.pause(for: goalID, hours: hours)
    }

    /// Call at daily reset when a recurring goal was not completed.
    func recordGoalFailure(for goalID: UUID) {
        EscalationTracker.shared.recordFailure(for: goalID)
        EscalationTracker.shared.reset(for: goalID)   // restart push chain for new period
    }

    // MARK: - Type 1: Goal Reminder

    private func scheduleReminder(goal: Goal, preferredTime: Date) async {
        let message = await GooseSpeechGenerator.shared.reminder(goalTitle: goal.title)
        let content = makeContent(
            title: "don't forget!",
            body: message,
            category: nil,
            goalID: goal.id,
            type: "reminder"
        )

        let cal = Calendar.current
        var comps = cal.dateComponents([.hour, .minute], from: preferredTime)

        func addRequest(id: String, weekday: Int? = nil) {
            if let weekday { comps.weekday = weekday }
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            schedule(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }

        switch goal.goalFrequency {
        case .daily:
            addRequest(id: "reminder_\(goal.id.uuidString)")
        case .weekdays:
            for d in 2...6 { addRequest(id: "reminder_\(goal.id.uuidString)_\(d)", weekday: d) }
        case .weekends:
            for d in [1, 7] { addRequest(id: "reminder_\(goal.id.uuidString)_\(d)", weekday: d) }
        case .weekly:
            addRequest(id: "reminder_\(goal.id.uuidString)", weekday: 2)  // Monday
        case .custom:
            for d in goal.customDaysSet { addRequest(id: "reminder_\(goal.id.uuidString)_\(d)", weekday: d) }
        }
    }

    // MARK: - Type 2: Aggressive Push

    private func scheduleAggressivePush(goal: Goal, startLevel: Int) async {
        // Schedule two levels: current and next, so the chain survives one missed app open.
        let levelA = startLevel
        let levelB = startLevel + 1

        let msgA = await GooseSpeechGenerator.shared.push(goalTitle: goal.title, level: levelA, ignored: levelA > 1)
        let contentA = makeContent(title: pushTitle(levelA), body: msgA, category: "PUSH_CATEGORY",
                                   goalID: goal.id, goalTitle: goal.title, type: "push", extra: ["level": levelA])
        let delayA: TimeInterval = 60  // 1 minute from now
        schedule(UNNotificationRequest(
            identifier: "push_\(goal.id.uuidString)_\(levelA)",
            content: contentA,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delayA, repeats: false)
        ))

        let msgB = await GooseSpeechGenerator.shared.push(goalTitle: goal.title, level: levelB, ignored: true)
        let contentB = makeContent(title: pushTitle(levelB), body: msgB, category: "PUSH_CATEGORY",
                                   goalID: goal.id, goalTitle: goal.title, type: "push", extra: ["level": levelB])
        let delayB = delayA + escalationDelay(for: levelB)
        schedule(UNNotificationRequest(
            identifier: "push_\(goal.id.uuidString)_\(levelB)",
            content: contentB,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delayB, repeats: false)
        ))

        // For spam phase (level 5+), pre-schedule an additional burst of 5-min notifications
        if startLevel >= 4 {
            var cumDelay = delayB
            for offset in 2...8 {
                let l = startLevel + offset
                cumDelay += 300  // every 5 minutes
                let msg = await GooseSpeechGenerator.shared.push(goalTitle: goal.title, level: l, ignored: true)
                let c = makeContent(title: pushTitle(l), body: msg, category: "PUSH_CATEGORY",
                                    goalID: goal.id, goalTitle: goal.title, type: "push", extra: ["level": l])
                schedule(UNNotificationRequest(
                    identifier: "push_\(goal.id.uuidString)_\(l)",
                    content: c,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: cumDelay, repeats: false)
                ))
            }
            EscalationTracker.shared.advanceScheduledLevel(for: goal.id, through: startLevel + 9)
        } else {
            EscalationTracker.shared.advanceScheduledLevel(for: goal.id, through: levelB)
        }
    }

    // MARK: - Type 3: Reset Suggestion

    private func scheduleResetSuggestion(goal: Goal, failures: Int) async {
        let isDeadline = goal.type == "deadline"
        let message = await GooseSpeechGenerator.shared.resetSuggestion(
            goalTitle: goal.title, failCount: failures, isDeadline: isDeadline
        )
        let content = makeContent(
            title: "maybe time to adjust?",
            body: message,
            category: "RESET_CATEGORY",
            goalID: goal.id,
            type: "reset"
        )
        // Schedule for this evening at 7pm
        var comps = DateComponents()
        comps.hour = 19; comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        schedule(UNNotificationRequest(identifier: "reset_\(goal.id.uuidString)", content: content, trigger: trigger))
    }

    // MARK: - Detection

    private func isBehindSchedule(goal: Goal) -> Bool {
        guard goal.type != "deadline" else { return false }

        let now = Date.now
        let cal = Calendar.current

        let preferred = goal.preferredTime
        let cutoffComps = preferred.map { cal.dateComponents([.hour, .minute], from: $0) }
        let cutoffMinutes = cutoffComps.flatMap { c in
            guard let h = c.hour, let m = c.minute else { return nil as Int? }
            return h * 60 + m
        } ?? (20 * 60)   // default 8pm

        let nowComps = cal.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (nowComps.hour ?? 0) * 60 + (nowComps.minute ?? 0)
        guard nowMinutes >= cutoffMinutes else { return false }

        let weekday = cal.component(.weekday, from: now)
        switch goal.goalFrequency {
        case .daily:    return true
        case .weekdays: return (2...6).contains(weekday)
        case .weekends: return weekday == 1 || weekday == 7
        case .weekly:   return weekday >= 5   // past Thursday
        case .custom:   return goal.customDaysSet.contains(weekday)
        }
    }

    private func shouldSuggestReset(goal: Goal, failures: Int) -> Bool {
        if goal.type == "deadline" {
            guard let dueDate = goal.dueDate else { return false }
            let total = dueDate.timeIntervalSince(goal.createdAt)
            let elapsed = Date.now.timeIntervalSince(goal.createdAt)
            return total > 0 && elapsed / total > 0.5 && goal.percentageProgress < 0.30
        }
        return failures >= 3
    }

    // MARK: - Helpers

    private func makeContent(
        title: String,
        body: String,
        category: String?,
        goalID: UUID,
        goalTitle: String = "",
        type: String,
        extra: [String: Any] = [:]
    ) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        if let category { c.categoryIdentifier = category }
        var info: [String: Any] = ["goalID": goalID.uuidString, "goalTitle": goalTitle, "type": type]
        info.merge(extra) { _, new in new }
        c.userInfo = info
        return c
    }

    private func schedule(_ request: UNNotificationRequest) {
        center.add(request) { error in
            if let error { print("[GooseNotifications] error: \(error)") }
        }
    }

    private func pushIDs(for goalID: UUID) -> [String] {
        (1...30).map { "push_\(goalID.uuidString)_\($0)" }
    }

    private func escalationDelay(for level: Int) -> TimeInterval {
        switch level {
        case 2: return 3600   // 1 hr
        case 3: return 1800   // 30 min
        case 4: return 900    // 15 min
        default: return 300   // 5 min
        }
    }

    private func pushTitle(_ level: Int) -> String {
        switch level {
        case 1: return "hey, don't forget!"
        case 2: return "still waiting..."
        case 3: return "honk honk!!"
        case 4: return "please!!"
        default: return "honk."
        }
    }
}
