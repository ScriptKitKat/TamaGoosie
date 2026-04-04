import Foundation
import SwiftData

@Model
final class DailyLog {
    var id: UUID
    var date: Date

    // HealthKit data
    var steps: Int
    var exerciseMinutes: Int
    var sleepHours: Double
    var standHours: Int
    var sittingHours: Double
    var outsideMinutes: Int

    // Distraction tracking
    var distractionOpens: Int
    var distractionMinutes: Int

    // Goal snapshot
    var goalsCompleted: Int
    var goalsTotal: Int

    // Cached deltas (after GooseEngine runs)
    var healthinessDelta: Double
    var happinessDelta: Double

    // XP earned
    var xpEarned: Int

    // Back-reference to owning UserProfile
    var userProfile: UserProfile?

    // 1:many — HealthKit snapshots collected during this day
    @Relationship(deleteRule: .cascade, inverse: \HealthSnapshot.dailyLog)
    var healthSnapshots: [HealthSnapshot] = []

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
        self.healthinessDelta = 0
        self.happinessDelta = 0
        self.xpEarned = 0
    }
}
