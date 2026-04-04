import Foundation
import SwiftData

@Model
final class GooseState {
    var name: String
    var health: Double
    var happiness: Double
    var energy: Double
    var hygiene: Double
    var xp: Int
    var level: Int
    var phase: String // GoosePhase raw value
    var mood: String // GooseMood raw value
    var streakDays: Int
    var longestStreak: Int
    var lastStreakDate: Date?
    var isDead: Bool
    var deathCount: Int
    var lastDeathDate: Date?
    var daysAlive: Int
    var totalGoalsCompleted: Int
    var birthDate: Date
    var lastUpdated: Date
    var isVacationMode: Bool
    var hasCompletedOnboarding: Bool

    init(
        name: String = "Harnold",
        health: Double = 100,
        happiness: Double = 100,
        energy: Double = 100,
        hygiene: Double = 100,
        xp: Int = 0,
        level: Int = 1,
        phase: String = GoosePhase.baby.rawValue,
        mood: String = GooseMood.happy.rawValue,
        streakDays: Int = 0,
        longestStreak: Int = 0,
        isDead: Bool = false,
        deathCount: Int = 0,
        birthDate: Date = .now,
        lastUpdated: Date = .now,
        isVacationMode: Bool = false,
        hasCompletedOnboarding: Bool = false
    ) {
        self.name = name
        self.health = health
        self.happiness = happiness
        self.energy = energy
        self.hygiene = hygiene
        self.xp = xp
        self.level = level
        self.phase = phase
        self.mood = mood
        self.streakDays = streakDays
        self.longestStreak = longestStreak
        self.isDead = isDead
        self.deathCount = deathCount
        self.daysAlive = 0
        self.totalGoalsCompleted = 0
        self.birthDate = birthDate
        self.lastUpdated = lastUpdated
        self.isVacationMode = isVacationMode
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    // MARK: - Computed Helpers

    var currentPhase: GoosePhase {
        GoosePhase(rawValue: phase) ?? .baby
    }

    var currentMood: GooseMood {
        GooseMood(rawValue: mood) ?? .neutral
    }

    func toStats() -> GooseStats {
        GooseStats(
            health: health,
            happiness: happiness,
            energy: energy,
            hygiene: hygiene,
            level: level,
            xp: xp,
            mood: currentMood,
            phase: currentPhase,
            streakDays: streakDays,
            gooseName: name,
            isDead: isDead
        )
    }

    func clampStats() {
        health = min(GoosieConstants.statMax, max(GoosieConstants.statMin, health))
        happiness = min(GoosieConstants.statMax, max(GoosieConstants.statMin, happiness))
        energy = min(GoosieConstants.statMax, max(GoosieConstants.statMin, energy))
        hygiene = min(GoosieConstants.statMax, max(GoosieConstants.statMin, hygiene))
    }

    func updateMood() {
        mood = GooseMood.mood(
            health: health,
            happiness: happiness,
            energy: energy,
            hygiene: hygiene
        ).rawValue
    }

    func updatePhase() {
        phase = GoosePhase.phase(forLevel: level).rawValue
    }
}
