// TamaGoosie/Features/Challenges/ChallengeViewModel.swift
import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class ChallengeViewModel {
    var pendingCompletions: [ChallengeRun] = []
    var lastError: ChallengeError?

    func active(from runs: [ChallengeRun]) -> [ChallengeRun] {
        runs.filter { $0.statusEnum == .active }
            .sorted { $0.startedAt < $1.startedAt }
    }

    func browseable(
        from templates: [ChallengeTemplate],
        runs: [ChallengeRun],
        now: Date = Date()
    ) -> [ChallengeTemplate] {
        templates
            .filter { $0.isActive }
            .sorted { $0.sortHint < $1.sortHint }
    }

    func isInCooldown(_ template: ChallengeTemplate, runs: [ChallengeRun], now: Date = Date()) -> Bool {
        ChallengeEngine.isInCooldown(templateId: template.templateId, runs: runs, now: now)
    }

    func cooldownEnds(for template: ChallengeTemplate, runs: [ChallengeRun]) -> Date? {
        runs
            .filter { $0.templateId == template.templateId && $0.statusEnum == .expired }
            .map { $0.expiresAt.addingTimeInterval(Double($0.windowDaysSnapshot) * 86_400) }
            .max()
    }

    func activeCount(_ runs: [ChallengeRun]) -> Int {
        runs.filter { $0.statusEnum == .active }.count
    }

    func canAccept(_ runs: [ChallengeRun]) -> Bool {
        activeCount(runs) < GoosieConstants.challengeActiveCap
    }

    func accept(
        template: ChallengeTemplate, tier: ChallengeTier,
        runs: [ChallengeRun], logs: [DailyLog], state: GooseState?,
        context: ModelContext
    ) {
        do {
            let run = try ChallengeEngine.accept(
                template: template, tier: tier,
                existingRuns: runs, context: context, now: Date()
            )
            try? context.save()
            Task { await ChallengeSyncService.shared.pushAccept(run) }
            // Same-day completion check — covers e.g. a 1-day challenge whose target is already met.
            if let state {
                let completed = ChallengeEngine.recomputeActive(
                    state: state, logs: logs, runs: runs + [run]
                )
                if !completed.isEmpty { enqueueCompletions(completed) }
            }
        } catch let err as ChallengeError {
            lastError = err
        } catch {
            // unexpected
        }
    }

    func abandon(_ run: ChallengeRun, context: ModelContext) {
        run.status = ChallengeStatus.expired.rawValue
        try? context.save()
        Task { await ChallengeSyncService.shared.pushExpire(run) }
    }

    func enqueueCompletions(_ runs: [ChallengeRun]) {
        pendingCompletions.append(contentsOf: runs)
    }

    func popNextCompletion() -> ChallengeRun? {
        pendingCompletions.isEmpty ? nil : pendingCompletions.removeFirst()
    }

    /// Live progress for an active run. Returns the raw aggregate value.
    func currentProgress(for run: ChallengeRun, logs: [DailyLog], now: Date = Date()) -> Double {
        ChallengeEngine.aggregate(
            shape: run.shapeEnum, metric: run.metricEnum,
            target: run.targetSnapshot, logs: logs,
            windowStart: run.startedAt, now: now
        )
    }

    /// 0...1 fraction for the progress bar.
    func progressFraction(for run: ChallengeRun, logs: [DailyLog]) -> Double {
        let target: Double = run.shapeEnum == .dailyCeiling
            ? Double(run.windowDaysSnapshot)
            : run.targetSnapshot
        guard target > 0 else { return 0 }
        return min(1.0, currentProgress(for: run, logs: logs) / target)
    }
}
