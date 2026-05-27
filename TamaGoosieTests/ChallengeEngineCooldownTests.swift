// TamaGoosieTests/ChallengeEngineCooldownTests.swift
import Testing
import Foundation
@testable import TamaGoosie

@MainActor
@Suite("ChallengeEngine.isInCooldown")
struct CooldownTests {
    @Test("No prior runs → not in cooldown")
    func noPriors() {
        let result = ChallengeEngine.isInCooldown(
            templateId: "step-it-up", runs: [], now: Date()
        )
        #expect(result == false)
    }

    @Test("Active run for template → NOT cooldown (cap covers that)")
    func activeRunNotCooldown() {
        let run = ChallengeRun(templateId: "step-it-up", tier: .bronze,
            startedAt: Date(), windowDays: 7,
            targetSnapshot: 30_000, rewardSnapshot: 25,
            metricSnapshot: .steps, shapeSnapshot: .cumulative)
        #expect(ChallengeEngine.isInCooldown(templateId: "step-it-up", runs: [run], now: Date()) == false)
    }

    @Test("Expired run within window → cooldown")
    func recentExpired() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let run = ChallengeRun(templateId: "step-it-up", tier: .bronze,
            startedAt: now.addingTimeInterval(-14 * 86_400),  // started 14d ago
            windowDays: 7,                                     // expired 7d ago
            targetSnapshot: 30_000, rewardSnapshot: 25,
            metricSnapshot: .steps, shapeSnapshot: .cumulative)
        run.status = ChallengeStatus.expired.rawValue
        // Cooldown ends 7d after expiresAt → 0d ago. Still inside.
        #expect(ChallengeEngine.isInCooldown(templateId: "step-it-up", runs: [run], now: now) == true)
    }

    @Test("Expired run with cooldown elapsed → NOT cooldown")
    func cooldownElapsed() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let run = ChallengeRun(templateId: "step-it-up", tier: .bronze,
            startedAt: now.addingTimeInterval(-30 * 86_400),
            windowDays: 7,
            targetSnapshot: 30_000, rewardSnapshot: 25,
            metricSnapshot: .steps, shapeSnapshot: .cumulative)
        run.status = ChallengeStatus.expired.rawValue
        #expect(ChallengeEngine.isInCooldown(templateId: "step-it-up", runs: [run], now: now) == false)
    }
}
