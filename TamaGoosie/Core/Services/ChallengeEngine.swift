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

    /// A template is in cooldown if any expired run for it ended within its own snapshotted window.
    static func isInCooldown(templateId: String, runs: [ChallengeRun], now: Date) -> Bool {
        runs.contains { run in
            run.templateId == templateId
            && run.statusEnum == .expired
            && run.expiresAt.addingTimeInterval(Double(run.windowDaysSnapshot) * 86_400) >= now
        }
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

enum ChallengeError: Error, Equatable {
    case capReached
    case inCooldown
    case templateDisabled
}

extension ChallengeEngine {
    @discardableResult
    static func accept(
        template: ChallengeTemplate,
        tier: ChallengeTier,
        existingRuns: [ChallengeRun],
        context: ModelContext,
        now: Date
    ) throws(ChallengeError) -> ChallengeRun {
        guard template.isActive else { throw .templateDisabled }

        let activeCount = existingRuns.filter { $0.statusEnum == .active }.count
        guard activeCount < GoosieConstants.challengeActiveCap else { throw .capReached }

        guard !isInCooldown(templateId: template.templateId, runs: existingRuns, now: now)
        else { throw .inCooldown }

        let run = ChallengeRun(
            templateId: template.templateId,
            tier: tier,
            startedAt: now,
            windowDays: template.windowDays,
            targetSnapshot: template.target(for: tier),
            rewardSnapshot: template.reward(for: tier),
            metricSnapshot: ChallengeMetric(rawValue: template.metric) ?? .steps,
            shapeSnapshot: ChallengeShape(rawValue: template.shape) ?? .cumulative
        )
        context.insert(run)
        return run
    }

    /// Idempotent. Returns the runs that transitioned `active → completed` on this call.
    @MainActor
    @discardableResult
    static func recomputeActive(
        state: GooseState,
        logs: [DailyLog],
        runs: [ChallengeRun],
        now: Date = Date()
    ) -> [ChallengeRun] {
        var newlyCompleted: [ChallengeRun] = []

        for run in runs where run.statusEnum == .active {
            let progress = aggregate(
                shape: run.shapeEnum,
                metric: run.metricEnum,
                target: run.targetSnapshot,
                logs: logs,
                windowStart: run.startedAt,
                now: now
            )

            // Effective target for completion check: for dailyCeiling, target is windowDays (day count).
            let effectiveTarget: Double = run.shapeEnum == .dailyCeiling
                ? Double(run.windowDaysSnapshot)
                : run.targetSnapshot

            // Target check runs BEFORE expiry check — completion wins on the boundary tick.
            if reached(progress: progress, target: effectiveTarget, shape: run.shapeEnum) {
                run.status = ChallengeStatus.completed.rawValue
                run.completedAt = now
                run.coinsAwarded = run.rewardSnapshot
                state.coins += run.rewardSnapshot
                newlyCompleted.append(run)
                continue
            }

            if now >= run.expiresAt {
                run.status = ChallengeStatus.expired.rawValue
            }
        }
        return newlyCompleted
    }
}
