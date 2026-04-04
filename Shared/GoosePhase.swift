import Foundation

// MARK: - Goose Phase

public enum GoosePhase: String, Codable, CaseIterable, Sendable {
    case egg
    case baby
    case teen
    case adult
    case elder

    public var displayName: String {
        switch self {
        case .egg: "Egg"
        case .baby: "Baby"
        case .teen: "Teen"
        case .adult: "Adult"
        case .elder: "Elder"
        }
    }

    public static func phase(forLevel level: Int) -> GoosePhase {
        switch level {
        case 0: .egg
        case 1...5: .baby
        case 6...15: .teen
        case 16...30: .adult
        default: .elder
        }
    }
}

// MARK: - Goose Mood

public enum GooseMood: String, Codable, CaseIterable, Sendable {
    case ecstatic
    case happy
    case content
    case neutral
    case sad
    case sick
    case sleeping
    case dead

    public var displayName: String {
        switch self {
        case .ecstatic: "Ecstatic"
        case .happy: "Happy"
        case .content: "Content"
        case .neutral: "Neutral"
        case .sad: "Sad"
        case .sick: "Sick"
        case .sleeping: "Sleeping"
        case .dead: "Dead"
        }
    }

    public var emoji: String {
        switch self {
        case .ecstatic: "🤩"
        case .happy: "😊"
        case .content: "😌"
        case .neutral: "😐"
        case .sad: "😢"
        case .sick: "🤢"
        case .sleeping: "😴"
        case .dead: "💀"
        }
    }

    public var color: String {
        switch self {
        case .ecstatic: "FFD93D"
        case .happy: "7ED6A5"
        case .content: "A8D8EA"
        case .neutral: "C8C8C8"
        case .sad: "6BC5F0"
        case .sick: "B8E8D0"
        case .sleeping: "A8D8EA"
        case .dead: "808080"
        }
    }

    public static func mood(health: Double, happiness: Double, energy: Double, hygiene: Double) -> GooseMood {
        let average = (health + happiness + energy + hygiene) / 4.0

        if health <= 0 { return .dead }
        if energy < 15 { return .sleeping }
        if health < 20 || hygiene < 15 { return .sick }
        if average < 25 { return .sad }
        if average >= 80 { return .ecstatic }
        if average >= 60 { return .happy }
        if average >= 40 { return .content }
        return .neutral
    }
}

// MARK: - Goal Category

public enum GoalCategory: String, Codable, CaseIterable, Sendable {
    case health
    case fitness
    case mindfulness
    case productivity
    case social
    case learning
    case hygiene
    case custom

    public var displayName: String {
        switch self {
        case .health: "Health"
        case .fitness: "Fitness"
        case .mindfulness: "Mindfulness"
        case .productivity: "Productivity"
        case .social: "Social"
        case .learning: "Learning"
        case .hygiene: "Hygiene"
        case .custom: "Custom"
        }
    }

    public var icon: String {
        switch self {
        case .health: "heart.fill"
        case .fitness: "figure.run"
        case .mindfulness: "brain.head.profile"
        case .productivity: "checkmark.circle.fill"
        case .social: "person.2.fill"
        case .learning: "book.fill"
        case .hygiene: "drop.fill"
        case .custom: "star.fill"
        }
    }

    public var color: String {
        switch self {
        case .health: "FF6B6B"
        case .fitness: "FFA652"
        case .mindfulness: "A8D8EA"
        case .productivity: "7ED6A5"
        case .social: "FFD1DC"
        case .learning: "B8E8D0"
        case .hygiene: "6BC5F0"
        case .custom: "FFD93D"
        }
    }
}

// MARK: - Goal Frequency

public enum GoalFrequency: String, Codable, CaseIterable, Sendable {
    case daily
    case weekdays
    case weekends
    case weekly
    case custom

    public var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekdays: "Weekdays"
        case .weekends: "Weekends"
        case .weekly: "Weekly"
        case .custom: "Custom"
        }
    }
}
