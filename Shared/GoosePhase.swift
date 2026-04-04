import Foundation

public enum GooseMood: String, Codable, CaseIterable, Sendable {
    case ecstatic
    case happy
    case content
    case bored
    case sad
    case sick

    public var displayName: String {
        switch self {
        case .ecstatic: "Ecstatic"
        case .happy: "Happy"
        case .content: "Content"
        case .bored: "Bored"
        case .sad: "Sad"
        case .sick: "Sick"
        }
    }

    public var emoji: String {
        switch self {
        case .ecstatic: "🤩"
        case .happy: "😊"
        case .content: "😌"
        case .bored: "😐"
        case .sad: "😢"
        case .sick: "🤢"
        }
    }

    public var color: String {
        switch self {
        case .ecstatic: "FFD93D"
        case .happy: "7ED6A5"
        case .content: "A8D8EA"
        case .bored: "C8C8C8"
        case .sad: "6BC5F0"
        case .sick: "B8E8D0"
        }
    }

    public static func deriveMood(healthiness: Double, happiness: Double) -> GooseMood {
        let avg = (healthiness + happiness) / 2.0
        switch avg {
        case 0.80...: return .ecstatic
        case 0.60..<0.80: return .happy
        case 0.40..<0.60: return .content
        case 0.25..<0.40: return .bored
        case 0.10..<0.25: return .sad
        default: return .sick
        }
    }
}

public enum GoalCategory: String, Codable, CaseIterable, Sendable {
    case exercise
    case water
    case screentime
    case study
    case health
    case fitness
    case mindfulness
    case productivity
    case social
    case learning
    case custom

    public var displayName: String {
        switch self {
        case .exercise: "Exercise"
        case .water: "Water"
        case .screentime: "Screen Time"
        case .study: "Study"
        case .health: "Health"
        case .fitness: "Fitness"
        case .mindfulness: "Mindfulness"
        case .productivity: "Productivity"
        case .social: "Social"
        case .learning: "Learning"
        case .custom: "Custom"
        }
    }

    public var icon: String {
        switch self {
        case .exercise: "figure.run"
        case .water: "drop.fill"
        case .screentime: "iphone"
        case .study: "book.fill"
        case .health: "heart.fill"
        case .fitness: "figure.run"
        case .mindfulness: "brain.head.profile"
        case .productivity: "checkmark.circle.fill"
        case .social: "person.2.fill"
        case .learning: "book.fill"
        case .custom: "star.fill"
        }
    }

    public var color: String {
        switch self {
        case .exercise: "FFA652"
        case .water: "6BC5F0"
        case .screentime: "FF6B6B"
        case .study: "B8E8D0"
        case .health: "FF6B6B"
        case .fitness: "FFA652"
        case .mindfulness: "A8D8EA"
        case .productivity: "7ED6A5"
        case .social: "FFD1DC"
        case .learning: "B8E8D0"
        case .custom: "FFD93D"
        }
    }
}

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
