import Foundation

/// Lightweight Codable struct for syncing goose state to Watch/Widgets via app group
public struct GooseSyncPayload: Codable, Sendable, Hashable {
    public var healthiness: Double
    public var happiness: Double
    public var mood: String
    public var name: String
    public var streakDays: Int
    public var spriteID: String
    public var topGoals: [GoalSummary]

    public init(
        healthiness: Double = 0.8,
        happiness: Double = 0.7,
        mood: String = GooseMood.content.rawValue,
        name: String = "Harold",
        streakDays: Int = 0,
        spriteID: String = "default",
        topGoals: [GoalSummary] = []
    ) {
        self.healthiness = healthiness
        self.happiness = happiness
        self.mood = mood
        self.name = name
        self.streakDays = streakDays
        self.spriteID = spriteID
        self.topGoals = topGoals
    }

    public var moodEnum: GooseMood {
        GooseMood(rawValue: mood) ?? .content
    }

    /// Display-ready healthiness percentage (0–100)
    public var healthinessPercent: Int {
        Int(healthiness * 100)
    }
}
