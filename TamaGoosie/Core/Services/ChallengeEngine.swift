// TamaGoosie/Core/Services/ChallengeEngine.swift
import Foundation
import SwiftData
import Observation

@Observable
final class ChallengeEngine {
    static let shared = ChallengeEngine()
    private init() {}

    /// Pure aggregator. `target` is forwarded for `dailyCeiling` (ignored by `cumulative`).
    /// `windowStart..<now` is the inclusive-exclusive window evaluated.
    static func aggregate(
        shape: ChallengeShape,
        metric: ChallengeMetric,
        target: Double,
        logs: [DailyLog],
        windowStart: Date,
        now: Date
    ) -> Double {
        let inWindow = logs.filter { $0.date >= windowStart && $0.date < now }
            .sorted { $0.date < $1.date }

        switch shape {
        case .cumulative:
            return inWindow.reduce(0.0) { $0 + value(of: metric, in: $1) }

        case .dailyCeiling:
            // Consecutive in-window days under target. A failing day resets to 0.
            var streak = 0
            for log in inWindow {
                if value(of: metric, in: log) <= target {
                    streak += 1
                } else {
                    streak = 0
                }
            }
            return Double(streak)
        }
    }

    /// For `cumulative`, target is the metric target (e.g. 50_000 steps).
    /// For `dailyCeiling`, target is `windowDays` (number of in-window days required under ceiling).
    static func reached(progress: Double, target: Double, shape: ChallengeShape) -> Bool {
        progress >= target
    }

    private static func value(of metric: ChallengeMetric, in log: DailyLog) -> Double {
        switch metric {
        case .steps:           return Double(log.steps)
        case .exerciseMinutes: return Double(log.exerciseMinutes)
        case .sleepHours:      return log.sleepHours
        case .outsideMinutes:  return Double(log.outsideMinutes)
        case .sittingHours:    return log.sittingHours
        case .standHours:      return Double(log.standHours)
        }
    }
}
