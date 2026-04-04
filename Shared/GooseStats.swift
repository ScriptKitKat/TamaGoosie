import Foundation

/// Lightweight Codable struct for syncing goose stats to Watch/Widgets
public struct GooseStats: Codable, Sendable, Hashable {
    public var health: Double
    public var happiness: Double
    public var energy: Double
    public var hygiene: Double
    public var level: Int
    public var xp: Int
    public var mood: GooseMood
    public var phase: GoosePhase
    public var streakDays: Int
    public var gooseName: String
    public var isDead: Bool

    public init(
        health: Double = 100,
        happiness: Double = 100,
        energy: Double = 100,
        hygiene: Double = 100,
        level: Int = 1,
        xp: Int = 0,
        mood: GooseMood = .happy,
        phase: GoosePhase = .baby,
        streakDays: Int = 0,
        gooseName: String = "Harnold",
        isDead: Bool = false
    ) {
        self.health = health
        self.happiness = happiness
        self.energy = energy
        self.hygiene = hygiene
        self.level = level
        self.xp = xp
        self.mood = mood
        self.phase = phase
        self.streakDays = streakDays
        self.gooseName = gooseName
        self.isDead = isDead
    }
}
