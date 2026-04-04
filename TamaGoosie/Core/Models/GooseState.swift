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

    // Progression
    var xp: Int = 0
    var level: Int = 1
    var streakDays: Int = 0
    var longestStreak: Int = 0
    var lastStreakDate: Date?

    // Derived state (cached for Watch sync)
    var phase: String = GoosePhase.baby.rawValue
    var mood: String = GooseMood.content.rawValue

    // Death
    var isDead: Bool = false
    var deathDate: Date?
    var deathCause: String?
    var reviveCount: Int = 0

    // Settings
    var isVacationMode: Bool = false

    // Timestamps
    var lastUpdated: Date = Date()
    var createdAt: Date = Date()

    init(
        name: String = "Harold",
        healthiness: Double = 0.8,
        happiness: Double = 0.7,
        xp: Int = 0,
        level: Int = 1,
        phase: String = GoosePhase.baby.rawValue,
        mood: String = GooseMood.content.rawValue,
        streakDays: Int = 0,
        longestStreak: Int = 0,
        isDead: Bool = false,
        isVacationMode: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.healthiness = healthiness
        self.happiness = happiness
        self.xp = xp
        self.level = level
        self.phase = phase
        self.mood = mood
        self.streakDays = streakDays
        self.longestStreak = longestStreak
        self.isDead = isDead
        self.isVacationMode = isVacationMode
        self.lastUpdated = .now
        self.createdAt = .now
    }

    // MARK: - Computed Helpers

    var currentPhase: GoosePhase {
        GoosePhase(rawValue: phase) ?? .baby
    }

    var currentMood: GooseMood {
        GooseMood(rawValue: mood) ?? .content
    }

    func toSyncPayload(topGoals: [GoalSummary] = []) -> GooseSyncPayload {
        GooseSyncPayload(
            healthiness: healthiness,
            happiness: happiness,
            mood: mood,
            phase: phase,
            name: name,
            level: level,
            streakDays: streakDays,
            isDead: isDead,
            spriteID: spriteID,
            topGoals: topGoals
        )
    }

    func clampStats() {
        healthiness = min(GoosieConstants.statMax, max(GoosieConstants.statMin, healthiness))
        happiness = min(GoosieConstants.statMax, max(GoosieConstants.statMin, happiness))
    }

    func updateMood() {
        mood = GooseMood.deriveMood(healthiness: healthiness, happiness: happiness).rawValue
    }

    func updatePhase() {
        phase = GoosePhase.phase(forLevel: level).rawValue
    }
}
