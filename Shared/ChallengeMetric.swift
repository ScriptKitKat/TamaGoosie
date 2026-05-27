// Shared/ChallengeMetric.swift
import Foundation

public enum ChallengeMetric: String, Codable, Sendable, CaseIterable {
    case steps
    case exerciseMinutes
    case sleepHours
    case outsideMinutes
    case sittingHours
    case standHours
}

public enum ChallengeShape: String, Codable, Sendable, CaseIterable {
    case cumulative
    case dailyCeiling
}

public enum ChallengeTier: String, Codable, Sendable, CaseIterable {
    case bronze, silver, gold
}

public enum ChallengeStatus: String, Codable, Sendable, CaseIterable {
    case active, completed, expired
}
