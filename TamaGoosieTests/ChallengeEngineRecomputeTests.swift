// TamaGoosieTests/ChallengeEngineRecomputeTests.swift
import Testing
import Foundation
import SwiftData
@testable import TamaGoosie

@MainActor
@Suite("ChallengeEngine.recomputeActive")
struct RecomputeTests {
    private func makeRun(
        startedAt: Date,
        windowDays: Int = 1,
        target: Double = 10_000,
        reward: Int = 25,
        metric: ChallengeMetric = .steps,
        shape: ChallengeShape = .cumulative
    ) -> ChallengeRun {
        ChallengeRun(
            templateId: "step-it-up",
            tier: .bronze,
            startedAt: startedAt,
            windowDays: windowDays,
            targetSnapshot: target,
            rewardSnapshot: reward,
            metricSnapshot: metric,
            shapeSnapshot: shape
        )
    }

    @Test("Progress below target → still active, no coins awarded")
    func belowTargetStaysActive() {
        let day0 = Date(timeIntervalSince1970: 1_000_000)
        let state = GooseState()
        state.coins = 50
        let run = makeRun(startedAt: day0, windowDays: 7, target: 50_000)
        let log = makeLog(date: day0, steps: 5_000)

        let completed = ChallengeEngine.recomputeActive(
            state: state,
            logs: [log],
            runs: [run],
            now: day0.addingTimeInterval(86_400) // 1 day in
        )

        #expect(completed.isEmpty)
        #expect(run.statusEnum == .active)
        #expect(run.coinsAwarded == nil)
        #expect(state.coins == 50)
    }

    @Test("Target met → completed, coins awarded once; second call is no-op")
    func targetMetCompletesAndIsIdempotent() {
        let day0 = Date(timeIntervalSince1970: 1_000_000)
        let state = GooseState()
        state.coins = 0
        let run = makeRun(startedAt: day0, windowDays: 7, target: 10_000, reward: 25)
        let log = makeLog(date: day0, steps: 15_000)

        let firstCall = ChallengeEngine.recomputeActive(
            state: state,
            logs: [log],
            runs: [run],
            now: day0.addingTimeInterval(86_400)
        )
        #expect(firstCall.count == 1)
        #expect(run.statusEnum == .completed)
        #expect(run.coinsAwarded == 25)
        #expect(run.completedAt != nil)
        #expect(state.coins == 25)

        // Second call: run is no longer active, so it should be skipped entirely.
        let secondCall = ChallengeEngine.recomputeActive(
            state: state,
            logs: [log],
            runs: [run],
            now: day0.addingTimeInterval(2 * 86_400)
        )
        #expect(secondCall.isEmpty)
        #expect(state.coins == 25) // unchanged
        #expect(run.coinsAwarded == 25) // unchanged
    }

    @Test("Expiry: now > expiresAt and target unmet → expired, no coins")
    func expiresWhenPastExpiry() {
        let day0 = Date(timeIntervalSince1970: 1_000_000)
        let state = GooseState()
        state.coins = 10
        let run = makeRun(startedAt: day0, windowDays: 1, target: 10_000, reward: 25)
        let log = makeLog(date: day0, steps: 3_000) // under target

        let completed = ChallengeEngine.recomputeActive(
            state: state,
            logs: [log],
            runs: [run],
            now: day0.addingTimeInterval(2 * 86_400) // past expiresAt (day0 + 1d)
        )

        #expect(completed.isEmpty)
        #expect(run.statusEnum == .expired)
        #expect(run.coinsAwarded == nil)
        #expect(state.coins == 10)
    }

    @Test("Target reached on the expiry tick (now == expiresAt) → completed")
    func targetBeatsExpiryOnBoundary() {
        let day0 = Date(timeIntervalSince1970: 1_000_000)
        let state = GooseState()
        state.coins = 0
        let run = makeRun(startedAt: day0, windowDays: 1, target: 10_000, reward: 25)
        let log = makeLog(date: day0, steps: 10_000)

        let completed = ChallengeEngine.recomputeActive(
            state: state,
            logs: [log],
            runs: [run],
            now: day0.addingTimeInterval(86_400) // == expiresAt
        )

        #expect(completed.count == 1)
        #expect(run.statusEnum == .completed)
        #expect(run.coinsAwarded == 25)
        #expect(state.coins == 25)
    }
}
