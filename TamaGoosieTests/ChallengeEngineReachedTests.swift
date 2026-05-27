// TamaGoosieTests/ChallengeEngineReachedTests.swift
import Testing
@testable import TamaGoosie

@Suite("ChallengeEngine.reached")
struct ReachedTests {
    @Test("cumulative: progress ≥ target")
    func cumulativeMeetsTarget() {
        #expect(ChallengeEngine.reached(progress: 50_000, target: 50_000, shape: .cumulative))
        #expect(ChallengeEngine.reached(progress: 50_001, target: 50_000, shape: .cumulative))
        #expect(!ChallengeEngine.reached(progress: 49_999, target: 50_000, shape: .cumulative))
    }

    @Test("dailyCeiling: progress (day count) ≥ target (= windowDays)")
    func dailyCeilingMeetsTarget() {
        // For dailyCeiling the "target" passed to reached() is windowDays, not the metric ceiling.
        #expect(ChallengeEngine.reached(progress: 3, target: 3, shape: .dailyCeiling))
        #expect(!ChallengeEngine.reached(progress: 2, target: 3, shape: .dailyCeiling))
    }
}
