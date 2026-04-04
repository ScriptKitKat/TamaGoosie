import Foundation

/// Lightweight Codable struct for syncing goose state to Watch/Widgets via app group
public struct GooseSyncPayload: Codable, Sendable, Hashable {
    public var healthiness: Double
    public var happiness: Double
    public var mood: String
    public var phase: String
    public var name: String
    public var level: Int
    public var streakDays: Int
    public var isDead: Bool
    public var spriteID: String
    public var topGoals: [GoalSummary]

    public init(
        healthiness: Double = 0.8,
        happiness: Double = 0.7,
        mood: String = GooseMood.content.rawValue,
        phase: String = GoosePhase.baby.rawValue,
        name: String = "Harold",
        level: Int = 1,
        streakDays: Int = 0,
        isDead: Bool = false,
        spriteID: String = "default",
        topGoals: [GoalSummary] = []
    ) {
        self.healthiness = healthiness
        self.happiness = happiness
        self.mood = mood
        self.phase = phase
        self.name = name
        self.level = level
        self.streakDays = streakDays
        self.isDead = isDead
        self.spriteID = spriteID
        self.topGoals = topGoals
    }

    public var moodEnum: GooseMood {
        GooseMood(rawValue: mood) ?? .content
    }

    public var phaseEnum: GoosePhase {
        GoosePhase(rawValue: phase) ?? .baby
    }

    /// Display-ready healthiness percentage (0–100)
    public var healthinessPercent: Int {
        Int(healthiness * 100)
    }
}
