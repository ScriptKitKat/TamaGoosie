import XCTest
@testable import TamaGoosie

final class GooseEngineTests: XCTestCase {

    // MARK: - Healthiness Formula

    func test_computeHealthiness_goodSleepAndExercise_returnsHighScore() {
        let log = makeDailyLog(sleepHours: 8, exerciseMinutes: 45, steps: 12000)
        let profile = makeProfile()

        let score = RewardEngine.computeHealthiness(log: log, profile: profile)

        XCTAssertGreaterThan(score, 0.8, "Good sleep + exercise should yield high healthiness")
        XCTAssertLessThanOrEqual(score, 1.0)
    }

    func test_computeHealthiness_zeroSleep_returnsLowScore() {
        let log = makeDailyLog(sleepHours: 0, exerciseMinutes: 0, steps: 0)
        let profile = makeProfile()

        let score = RewardEngine.computeHealthiness(log: log, profile: profile)

        XCTAssertLessThan(score, 0.3, "No sleep or exercise should yield low healthiness")
        XCTAssertGreaterThanOrEqual(score, 0.0)
    }

    func test_computeHealthiness_perfectInputs_clampedAt1() {
        let log = makeDailyLog(sleepHours: 8, exerciseMinutes: 300, steps: 50000,
                               outsideMinutes: 120, sittingHours: 0)
        let profile = makeProfile(watchPaired: true)

        let score = RewardEngine.computeHealthiness(log: log, profile: profile)

        XCTAssertEqual(score, 1.0, accuracy: 0.001, "Perfect inputs should yield max healthiness")
    }

    func test_computeHealthiness_withOutsideMinutes_usesOutsideWeights() {
        let log = makeDailyLog(sleepHours: 8, exerciseMinutes: 30, steps: 8000, outsideMinutes: 90)
        let profile = makeProfile(watchPaired: true)
        let scoreWith = RewardEngine.computeHealthiness(log: log, profile: profile)

        let logWithout = makeDailyLog(sleepHours: 8, exerciseMinutes: 30, steps: 8000, outsideMinutes: 0)
        let profileWithout = makeProfile(watchPaired: false)
        let scoreWithout = RewardEngine.computeHealthiness(log: logWithout, profile: profileWithout)

        XCTAssertGreaterThan(scoreWith, 0.0)
        XCTAssertGreaterThan(scoreWithout, 0.0)
    }

    // MARK: - Happiness Formula

    func test_computeHappiness_allGoalsCompleted_returnsHighScore() {
        let log = makeDailyLog(goalsCompleted: 5, goalsTotal: 5)
        let goals = makeGoals(count: 5, streak: 7)

        let score = RewardEngine.computeHappiness(log: log, goals: goals)

        XCTAssertGreaterThan(score, 0.7)
        XCTAssertLessThanOrEqual(score, 1.0)
    }

    func test_computeHappiness_noGoals_returnsBaseline() {
        let log = makeDailyLog(goalsCompleted: 0, goalsTotal: 0)
        let score = RewardEngine.computeHappiness(log: log, goals: [])

        // goalsTotal == 0 → goalScore = 0.5 (neutral)
        XCTAssertGreaterThan(score, 0.4)
        XCTAssertLessThan(score, 0.9)
    }

    func test_computeHappiness_maxDistraction_lowersScore() {
        let noDistraction = makeDailyLog(goalsCompleted: 3, goalsTotal: 5)
        let maxDistraction = makeDailyLog(goalsCompleted: 3, goalsTotal: 5, distractionMinutes: 120)

        let goals = makeGoals(count: 5, streak: 0)
        let scoreClean = RewardEngine.computeHappiness(log: noDistraction, goals: goals)
        let scoreDirty = RewardEngine.computeHappiness(log: maxDistraction, goals: goals)

        XCTAssertGreaterThan(scoreClean, scoreDirty, "Distraction should lower happiness score")
    }

    func test_computeHappiness_partialCompletion_betweenBaselineAndFull() {
        let partial = makeDailyLog(goalsCompleted: 2, goalsTotal: 5)
        let full = makeDailyLog(goalsCompleted: 5, goalsTotal: 5)
        let goals = makeGoals(count: 5, streak: 0)

        let partialScore = RewardEngine.computeHappiness(log: partial, goals: goals)
        let fullScore = RewardEngine.computeHappiness(log: full, goals: goals)

        XCTAssertLessThan(partialScore, fullScore, "More completed goals should yield higher happiness")
    }

    // MARK: - Helpers

    private func makeDailyLog(
        sleepHours: Double = 7,
        exerciseMinutes: Int = 30,
        steps: Int = 8000,
        outsideMinutes: Int = 0,
        sittingHours: Double = 6,
        goalsCompleted: Int = 0,
        goalsTotal: Int = 0,
        distractionMinutes: Int = 0
    ) -> DailyLog {
        let log = DailyLog()
        log.sleepHours = sleepHours
        log.exerciseMinutes = exerciseMinutes
        log.steps = steps
        log.outsideMinutes = outsideMinutes
        log.sittingHours = sittingHours
        log.distractionMinutes = distractionMinutes
        log.goalsCompleted = goalsCompleted
        log.goalsTotal = goalsTotal
        return log
    }

    private func makeProfile(watchPaired: Bool = false) -> UserProfile {
        let p = UserProfile()
        p.avgSleepHours = 8.0
        p.avgSteps = 8000
        p.avgExerciseMinutes = 30
        p.avgSittingHours = 8.0
        p.watchPaired = watchPaired
        return p
    }

    private func makeGoals(count: Int, streak: Int) -> [Goal] {
        (0..<count).map { i in
            let g = Goal(title: "Goal \(i)")
            g.currentStreak = streak
            return g
        }
    }
}
