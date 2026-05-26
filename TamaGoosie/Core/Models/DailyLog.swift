import Foundation
import SwiftData

@Model
final class DailyLog {
    var id: UUID = UUID()
    var date: Date = Date()

    // HealthKit data
    var steps: Int = 0
    var exerciseMinutes: Int = 0
    var sleepHours: Double = 0
    var standHours: Int = 0
    var sittingHours: Double = 0
    var outsideMinutes: Int = 0

    // Distraction tracking
    var distractionOpens: Int = 0
    var distractionMinutes: Int = 0

    // Goal snapshot
    var goalsCompleted: Int = 0
    var goalsTotal: Int = 0

    // End-of-day goose stats (snapshotted once when the next day begins)
    var endOfDayHealthiness: Double = 0
    var endOfDayHappiness: Double = 0

    // Back-reference to owning UserProfile
    var userProfile: UserProfile?

    // 1:many — HealthKit snapshots collected during this day
    @Relationship(deleteRule: .cascade, inverse: \HealthSnapshot.dailyLog)
    var healthSnapshots: [HealthSnapshot] = []

    /// True when at least one HealthKit metric has been recorded.
    var hasHealthData: Bool {
        steps > 0 || exerciseMinutes > 0 || sleepHours > 0 || standHours > 0 || outsideMinutes > 0
    }

    /// True when any data (health, goals, or distraction) has been recorded.
    var hasAnyData: Bool {
        hasHealthData || goalsTotal > 0 || distractionMinutes > 0 || distractionOpens > 0
    }

    init(date: Date = .now) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.steps = 0
        self.exerciseMinutes = 0
        self.sleepHours = 0
        self.standHours = 0
        self.sittingHours = 0
        self.outsideMinutes = 0
        self.distractionOpens = 0
        self.distractionMinutes = 0
        self.goalsCompleted = 0
        self.goalsTotal = 0
    }
}
