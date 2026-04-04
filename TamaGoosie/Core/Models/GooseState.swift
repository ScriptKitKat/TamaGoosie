import Foundation
import SwiftData

@Model
final class GooseState {
    var id: UUID = UUID()
    var name: String = "Harold"
    var spriteID: String = "default"
    var hatID: String?
    var colorID: String?

    // Core stats (0.0 – 1.0)
    var healthiness: Double = 0.8
    var happiness: Double = 0.7

    // Streak
    var streakDays: Int = 0
    var longestStreak: Int = 0
    var lastStreakDate: Date?

    // Derived state (cached for Watch sync)
    var mood: String = GooseMood.content.rawValue

    // Timestamps
    var lastUpdated: Date = Date()
    var createdAt: Date = Date()

    // Back-reference to owning UserProfile
    var userProfile: UserProfile?

    init(
        name: String = "Harold",
        healthiness: Double = 0.8,
        happiness: Double = 0.7,
        mood: String = GooseMood.content.rawValue,
        streakDays: Int = 0,
        longestStreak: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.healthiness = healthiness
        self.happiness = happiness
        self.mood = mood
        self.streakDays = streakDays
        self.longestStreak = longestStreak
        self.lastUpdated = .now
        self.createdAt = .now
    }

    // MARK: - Computed Helpers

    var currentMood: GooseMood {
        GooseMood(rawValue: mood) ?? .content
    }

    func toSyncPayload(topGoals: [GoalSummary] = []) -> GooseSyncPayload {
        GooseSyncPayload(
            healthiness: healthiness,
            happiness: happiness,
            mood: mood,
            name: name,
            streakDays: streakDays,
            spriteID: spriteID,
            topGoals: topGoals
        )
    }

    func updateMood() {
        mood = GooseMood.deriveMood(healthiness: healthiness, happiness: happiness).rawValue
    }
}
