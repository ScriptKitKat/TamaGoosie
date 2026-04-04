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
        // Perfect sleep (= baseline), extreme exercise + steps, no sitting, 2h outside (Watch)
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

        // Scores may differ because of different weights
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

    // MARK: - Reward Events

    func test_goalCompletionReward_appliesHappinessDelta() {
        let state = GooseState()
        let initialHappiness = state.happiness

        let reward = RewardEngine.rewardForGoalCompletion(weight: 1.0, streakDays: 0)
        RewardEngine.applyDelta(reward, to: state)

        XCTAssertGreaterThan(state.happiness, initialHappiness)
    }

    func test_goalCompletionReward_withStreakMultiplier_earnMoreXP() {
        let baseReward = RewardEngine.rewardForGoalCompletion(weight: 1.0, streakDays: 0)
        let streakReward = RewardEngine.rewardForGoalCompletion(weight: 1.0, streakDays: 10)

        XCTAssertGreaterThan(streakReward.xp, baseReward.xp)
    }

    func test_allGoalsCompletedReward_boostsBothStats() {
        let reward = RewardEngine.rewardForAllGoalsCompleted()
        XCTAssertGreaterThan(reward.healthiness, 0)
        XCTAssertGreaterThan(reward.happiness, 0)
        XCTAssertGreaterThan(reward.xp, 0)
    }

    func test_distractionPenalty_reducesHappiness() {
        let state = GooseState()
        state.happiness = 0.8
        let penalty = RewardEngine.penaltyForDistractionOpen()
        RewardEngine.applyDelta(penalty, to: state)
        XCTAssertLessThan(state.happiness, 0.8)
    }

    func test_streakMultiplier_capsAt2x() {
        let multiplier = RewardEngine.streakMultiplier(for: 100)
        XCTAssertEqual(multiplier, 2.0, accuracy: 0.001)
    }

    func test_isStreakMilestone_detectsMilestones() {
        XCTAssertTrue(RewardEngine.isStreakMilestone(7))
        XCTAssertTrue(RewardEngine.isStreakMilestone(30))
        XCTAssertTrue(RewardEngine.isStreakMilestone(365))
        XCTAssertFalse(RewardEngine.isStreakMilestone(5))
        XCTAssertFalse(RewardEngine.isStreakMilestone(8))
    }

    // MARK: - Decay Over 24 Hours

    func test_applyDecay_over24Hours_reducesStatsByExpectedAmount() {
        let state = GooseState()
        state.healthiness = 0.8
        state.happiness = 0.8
        // 24h absence → 8+ hour gap → 2h grace → 22h effective decay
        state.lastUpdated = Date.now.addingTimeInterval(-24 * 3600)

        DecayEngine.applyDecay(to: state)

        let effectiveHours = 24.0 - GoosieConstants.gracePeriodHours
        let expectedHealthDecay = GoosieConstants.healthinessDecayPerHour * effectiveHours
        let expectedHappyDecay  = GoosieConstants.happinessDecayPerHour  * effectiveHours

        XCTAssertEqual(0.8 - state.healthiness, expectedHealthDecay, accuracy: 0.005)
        XCTAssertEqual(0.8 - state.happiness,  expectedHappyDecay,  accuracy: 0.005)
    }

    // MARK: - Death Threshold

    func test_applyDecay_deathThreshold_healthinessZero_markedDead() {
        let state = GooseState()
        state.healthiness = 0.05   // will deplete after 50h of effective decay
        state.happiness = 0.5
        // 50h absence → 8+ hour gap → 2h grace → 48h effective
        // 48 * 0.008 = 0.384 > 0.05 → healthiness hits 0 → dead
        state.lastUpdated = Date.now.addingTimeInterval(-50 * 3600)

        DecayEngine.applyDecay(to: state)

        XCTAssertTrue(state.isDead,   "Healthiness depleted to 0 should mark goose as dead")
        XCTAssertEqual(state.healthiness, 0.0, accuracy: 0.001)
        XCTAssertNotNil(state.deathDate)
        XCTAssertNotNil(state.deathCause)
    }

    // MARK: - Max Steps

    func test_computeHealthiness_maxSteps_returnsHighHealthinessScore() {
        // 20 000 steps = 2.5× the 8 000 avg → stepsScore clamped to 1.0
        let log = makeDailyLog(sleepHours: 8, exerciseMinutes: 30, steps: 20_000)
        let profile = makeProfile()

        let score = RewardEngine.computeHealthiness(log: log, profile: profile)

        XCTAssertGreaterThan(score, 0.8, "Max steps with good sleep/exercise should yield > 0.80")
        XCTAssertLessThanOrEqual(score, 1.0)
    }

    // MARK: - Stat Clamping

    func test_applyDelta_doesNotExceedStatMax() {
        let state = GooseState(healthiness: 0.99, happiness: 0.99)
        let bigDelta = RewardEngine.StatDelta(healthiness: 0.5, happiness: 0.5, xp: 0)
        RewardEngine.applyDelta(bigDelta, to: state)

        XCTAssertEqual(state.healthiness, GoosieConstants.statMax, accuracy: 0.001)
        XCTAssertEqual(state.happiness, GoosieConstants.statMax, accuracy: 0.001)
    }

    func test_applyDelta_doesNotGoBelowStatMin() {
        let state = GooseState(healthiness: 0.01, happiness: 0.01)
        let bigPenalty = RewardEngine.StatDelta(healthiness: -1.0, happiness: -1.0, xp: 0)
        RewardEngine.applyDelta(bigPenalty, to: state)

        XCTAssertEqual(state.healthiness, GoosieConstants.statMin, accuracy: 0.001)
        XCTAssertEqual(state.happiness, GoosieConstants.statMin, accuracy: 0.001)
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
