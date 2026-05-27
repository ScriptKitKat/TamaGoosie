import Testing
import Foundation
@testable import TamaGoosie

@MainActor
@Suite("ChallengeEngine.aggregate — cumulative")
struct AggregateCumulativeTests {
    @Test("Sums steps over the window")
    func sumsSteps() {
        let day0 = Date(timeIntervalSince1970: 0)
        let logs = [
            makeLog(date: day0,                     steps: 10_000),
            makeLog(date: day0.addingTimeInterval(86_400),     steps: 8_000),
            makeLog(date: day0.addingTimeInterval(2 * 86_400), steps: 12_000),
        ]
        let progress = ChallengeEngine.aggregate(
            shape: .cumulative,
            metric: .steps,
            target: 50_000,
            logs: logs,
            windowStart: day0,
            now: day0.addingTimeInterval(3 * 86_400)
        )
        #expect(progress == 30_000)
    }

    @Test("Ignores logs outside the window")
    func ignoresOutOfWindow() {
        let day0 = Date(timeIntervalSince1970: 0)
        let logs = [
            makeLog(date: day0.addingTimeInterval(-86_400), steps: 99_999), // before
            makeLog(date: day0, steps: 1_000),
        ]
        let progress = ChallengeEngine.aggregate(
            shape: .cumulative, metric: .steps, target: 5_000,
            logs: logs, windowStart: day0, now: day0.addingTimeInterval(86_400)
        )
        #expect(progress == 1_000)
    }
}

// Test fixture builder — uses the model's init, then overwrites `date` to bypass
// `DailyLog.init`'s `Calendar.current.startOfDay(for:)` normalization so tests can
// control the exact timestamp used by `ChallengeEngine.aggregate`'s window check.
@MainActor
func makeLog(date: Date, steps: Int = 0, exerciseMinutes: Int = 0,
             sleepHours: Double = 0, outsideMinutes: Int = 0,
             sittingHours: Double = 0, standHours: Int = 0) -> DailyLog {
    let log = DailyLog(date: date)
    log.date = date
    log.steps = steps
    log.exerciseMinutes = exerciseMinutes
    log.sleepHours = sleepHours
    log.outsideMinutes = outsideMinutes
    log.sittingHours = sittingHours
    log.standHours = standHours
    return log
}
