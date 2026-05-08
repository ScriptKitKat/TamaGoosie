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

    // Health data from DailyLog (synced from phone)
    public var steps: Int
    public var exerciseMinutes: Int
    public var sleepHours: Double
    public var standHours: Int
    public var activeCalories: Double

    public init(
        healthiness: Double = 0.8,
        happiness: Double = 0.7,
        mood: String = GooseMood.content.rawValue,
        name: String = "Harold",
        streakDays: Int = 0,
        spriteID: String = "default",
        topGoals: [GoalSummary] = [],
        steps: Int = 0,
        exerciseMinutes: Int = 0,
        sleepHours: Double = 0.0,
        standHours: Int = 0,
        activeCalories: Double = 0.0
    ) {
        self.healthiness = healthiness
        self.happiness = happiness
        self.mood = mood
        self.name = name
        self.streakDays = streakDays
        self.spriteID = spriteID
        self.topGoals = topGoals
        self.steps = steps
        self.exerciseMinutes = exerciseMinutes
        self.sleepHours = sleepHours
        self.standHours = standHours
        self.activeCalories = activeCalories
    }

    public var moodEnum: GooseMood {
        GooseMood(rawValue: mood) ?? .content
    }

    /// Display-ready healthiness percentage (0–100)
    public var healthinessPercent: Int {
        Int(healthiness * 100)
    }
}
