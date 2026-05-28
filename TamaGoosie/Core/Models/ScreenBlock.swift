import Foundation
import SwiftData
import FamilyControls

@Model
final class ScreenBlock {
    var id: UUID = UUID()
    var name: String = ""
    var type: String = "blockNow"       // "blockNow" | "schedule" | "appLimit" | "lock"
    var isActive: Bool = true
    var createdAt: Date = Date()

    // App selection (encoded FamilyActivitySelection)
    var selectionData: Data?

    // Block Now
    var durationMinutes: Int = 25
    var startedAt: Date?
    var endedAt: Date?

    // Schedule
    var scheduleStartHour: Int = 8
    var scheduleStartMinute: Int = 0
    var scheduleEndHour: Int = 22
    var scheduleEndMinute: Int = 0
    var activeDays: String = "1,2,3,4,5,6,7"
    var isVacationMode: Bool = false

    // App Limit
    var timeLimitMinutes: Int = 30

    // Lock
    var opensAllowed: Int = 3
    var unlockDurationMinutes: Int = 5
    var opensUsedToday: Int = 0

    // Tracking
    var completedAt: Date?

    init(
        name: String,
        type: String,
        selectionData: Data? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.selectionData = selectionData
        self.createdAt = .now
    }

    // MARK: - Computed

    var activeDaysSet: Set<Int> {
        get {
            Set(activeDays.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) })
        }
        set {
            activeDays = newValue.sorted().map(String.init).joined(separator: ",")
        }
    }

    var isExpired: Bool {
        completedAt != nil
    }

    var isPast: Bool {
        if type == "blockNow" {
            return endedAt != nil
        }
        return completedAt != nil
    }

    /// Pure helper: is a schedule window active right now, treating wrap
    /// schedules (end < start) as windows attributed to their start day?
    ///
    /// - `weekday` / `nowMins`: derived from `Date.now` (1-based weekday).
    /// - `startMins` / `endMins`: start and end of the window in minutes-of-day.
    /// - `activeDays`: 1-based weekdays the block runs on (start-day semantics).
    ///
    /// Returns `false` for malformed `start == end` blocks (see plan D-3.2).
    static func isInScheduleWindow(
        weekday: Int,
        nowMins: Int,
        startMins: Int,
        endMins: Int,
        activeDays: Set<Int>
    ) -> Bool {
        guard startMins != endMins else { return false }
        let yesterday = ((weekday - 2 + 7) % 7) + 1
        if endMins < startMins {
            // Wrap: same-day half checks today; wrapped half checks yesterday.
            if nowMins >= startMins, activeDays.contains(weekday) { return true }
            if nowMins < endMins, activeDays.contains(yesterday) { return true }
            return false
        }
        return activeDays.contains(weekday) && nowMins >= startMins && nowMins < endMins
    }

    /// Convenience: is this `schedule`-type block currently inside its window?
    func isScheduleActive(now: Date = .now) -> Bool {
        guard type == "schedule", !isVacationMode else { return false }
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now)
        let nowMins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        return Self.isInScheduleWindow(
            weekday: weekday,
            nowMins: nowMins,
            startMins: scheduleStartHour * 60 + scheduleStartMinute,
            endMins: scheduleEndHour * 60 + scheduleEndMinute,
            activeDays: activeDaysSet
        )
    }

    /// Decode the stored FamilyActivitySelection
    var selection: FamilyActivitySelection? {
        get {
            guard let data = selectionData else { return nil }
            return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        }
        set {
            selectionData = newValue.flatMap { try? PropertyListEncoder().encode($0) }
        }
    }

    /// Human-readable schedule summary for card display
    var scheduleSummary: String {
        switch type {
        case "blockNow":
            return "\(durationMinutes)m session"
        case "schedule":
            let start = String(format: "%02d:%02d", scheduleStartHour, scheduleStartMinute)
            let end = String(format: "%02d:%02d", scheduleEndHour, scheduleEndMinute)
            let dayCount = activeDaysSet.count
            let dayLabel = dayCount == 7 ? "Every day" : "\(dayCount) days/week"
            return "\(dayLabel), \(start) - \(end)"
        case "appLimit":
            return "\(timeLimitMinutes)m daily limit"
        case "lock":
            return "\(opensAllowed) opens/day, \(unlockDurationMinutes)m each"
        default:
            return ""
        }
    }

    /// Status label for block cards
    var statusLabel: String {
        if type == "blockNow" {
            if let started = startedAt, endedAt == nil {
                let remaining = durationMinutes * 60 - Int(Date().timeIntervalSince(started))
                if remaining > 0 {
                    let mins = remaining / 60
                    let secs = remaining % 60
                    return "Active - \(mins)m \(secs)s left"
                }
                return "Completed"
            }
            return "Ready"
        }
        if isVacationMode { return "Disabled" }
        if type == "schedule" {
            if isScheduleActive() { return "Active" }
            let now = Date()
            let cal = Calendar.current
            let weekday = cal.component(.weekday, from: now)
            let nowMins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
            let startMins = scheduleStartHour * 60 + scheduleStartMinute
            guard activeDaysSet.contains(weekday) else { return "Off today" }
            if nowMins < startMins {
                let diff = startMins - nowMins
                return "Starting in \(diff / 60)h \(diff % 60)m"
            }
            return "Done for today"
        }
        return "Active"
    }

    // MARK: - Block Now helpers

    func startSession() {
        startedAt = .now
    }

    func endSession() {
        endedAt = .now
        completedAt = .now
    }

    var blockNowRemainingSeconds: Int {
        guard let started = startedAt else { return durationMinutes * 60 }
        let elapsed = Int(Date().timeIntervalSince(started))
        return max(0, durationMinutes * 60 - elapsed)
    }

    var blockNowProgress: Double {
        let total = Double(durationMinutes * 60)
        guard total > 0 else { return 0 }
        return 1.0 - (Double(blockNowRemainingSeconds) / total)
    }

    var blockNowDisplayTime: String {
        let remaining = blockNowRemainingSeconds
        let mins = remaining / 60
        let secs = remaining % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
