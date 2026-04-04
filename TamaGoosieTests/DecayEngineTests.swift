import XCTest
@testable import TamaGoosie

final class DecayEngineTests: XCTestCase {

    // MARK: - Basic Decay

    func test_applyDecay_reducesHealthinessOverTime() {
        let state = GooseState()
        state.healthiness = 0.8
        state.lastUpdated = Date.now.addingTimeInterval(-7200) // 2 hours ago

        DecayEngine.applyDecay(to: state)

        XCTAssertLessThan(state.healthiness, 0.8)
    }

    func test_applyDecay_reducesHappinessOverTime() {
        let state = GooseState()
        state.happiness = 0.8
        state.lastUpdated = Date.now.addingTimeInterval(-7200)

        DecayEngine.applyDecay(to: state)

        XCTAssertLessThan(state.happiness, 0.8)
    }

    // MARK: - Grace Period

    func test_gracePeriod_shortAbsence_noDecay() {
        let state = GooseState()
        state.healthiness = 0.8
        state.happiness = 0.8
        // 1 hour absence — within 2h grace period for absences < 8h
        state.lastUpdated = Date.now.addingTimeInterval(-3600)

        let healthBefore = state.healthiness
        let happyBefore = state.happiness

        DecayEngine.applyDecay(to: state)

        // Decay should still occur for normal intervals (grace only for 8+ hour gaps)
        // 1 hour should see normal decay
        XCTAssertLessThan(state.healthiness, healthBefore)
        XCTAssertLessThan(state.happiness, happyBefore)
    }

    func test_gracePeriod_longAbsence_gracePeriodApplied() {
        let state = GooseState()
        state.healthiness = 0.8
        state.happiness = 0.8
        // 9 hours absence — 8+ hours triggers grace period (first 2h free)
        state.lastUpdated = Date.now.addingTimeInterval(-9 * 3600)

        DecayEngine.applyDecay(to: state)

        // Should decay for 7 hours (9 - 2 grace), not 9 hours
        let expectedHealthDecay = GoosieConstants.healthinessDecayPerHour * 7
        let expectedHappyDecay = GoosieConstants.happinessDecayPerHour * 7
        let healthDecay = 0.8 - state.healthiness
        let happyDecay = 0.8 - state.happiness

        XCTAssertEqual(healthDecay, expectedHealthDecay, accuracy: 0.01)
        XCTAssertEqual(happyDecay, expectedHappyDecay, accuracy: 0.01)
    }

    // MARK: - Compound Penalty

    func test_compoundPenalty_triggersWhenBothStatsLow() {
        let state = GooseState()
        state.healthiness = 0.1 // below 0.2 threshold
        state.happiness = 0.1   // below 0.2 threshold
        state.lastUpdated = Date.now.addingTimeInterval(-3600) // 1 hour

        DecayEngine.applyDecay(to: state)

        // Compound adds 0.004/hr extra to each stat
        let expectedHealthDecay = (GoosieConstants.healthinessDecayPerHour + GoosieConstants.compoundDecayPerHour) * 1
        let expectedHappyDecay = (GoosieConstants.happinessDecayPerHour + GoosieConstants.compoundDecayPerHour) * 1

        let healthDecay = 0.1 - state.healthiness
        let happyDecay = 0.1 - state.happiness

        XCTAssertEqual(healthDecay, expectedHealthDecay, accuracy: 0.005)
        XCTAssertEqual(happyDecay, expectedHappyDecay, accuracy: 0.005)
    }

    func test_compoundPenalty_doesNotTriggerAboveThreshold() {
        let state = GooseState()
        state.healthiness = 0.5  // above 0.2 threshold
        state.happiness = 0.5
        state.lastUpdated = Date.now.addingTimeInterval(-3600)

        DecayEngine.applyDecay(to: state)

        let healthDecay = 0.5 - state.healthiness
        let happyDecay = 0.5 - state.happiness

        // Only base decay, no compound penalty
        XCTAssertEqual(healthDecay, GoosieConstants.healthinessDecayPerHour, accuracy: 0.005)
        XCTAssertEqual(happyDecay, GoosieConstants.happinessDecayPerHour, accuracy: 0.005)
    }

    // MARK: - Stat Floor

    func test_decay_doesNotGoBelowStatMin() {
        let state = GooseState()
        state.healthiness = 0.5
        state.happiness = 0.5
        state.lastUpdated = Date.now.addingTimeInterval(-200 * 3600) // extreme: 200 hours

        DecayEngine.applyDecay(to: state)

        // Stats clamp at statMin (0.0), not negative
        XCTAssertGreaterThanOrEqual(state.healthiness, GoosieConstants.statMin)
        XCTAssertGreaterThanOrEqual(state.happiness, GoosieConstants.statMin)
    }

    // MARK: - Death Trigger

    func test_death_triggersWhenHealthinessReachesZero() {
        let state = GooseState()
        state.healthiness = 0.001
        state.happiness = 0.8
        state.lastUpdated = Date.now.addingTimeInterval(-72 * 3600) // 72 hours

        DecayEngine.applyDecay(to: state)

        XCTAssertTrue(state.isDead, "Goose should die when healthiness depleted")
        XCTAssertNotNil(state.deathCause)
        XCTAssertNotNil(state.deathDate)
    }

    func test_death_happinessAloneCannotKill_shortAbsence() {
        // With a short absence (2h), low happiness cannot kill the goose
        // even with compound penalty: healthDecay = (0.008 + 0.004) * 2 = 0.024
        let state = GooseState()
        state.healthiness = 0.8
        state.happiness = 0.0  // zero happiness → triggers compound penalty
        state.lastUpdated = Date.now.addingTimeInterval(-2 * 3600) // 2 hours

        DecayEngine.applyDecay(to: state)

        XCTAssertFalse(state.isDead, "Short absence with low happiness should not kill the goose")
        XCTAssertGreaterThan(state.healthiness, 0)
    }

    // MARK: - Vacation Mode

    func test_vacationMode_preventsDecay() {
        let state = GooseState()
        state.isVacationMode = true
        state.healthiness = 0.8
        state.happiness = 0.7
        state.lastUpdated = Date.now.addingTimeInterval(-24 * 3600)

        let engine = GooseEngine.shared
        engine.update(state: state)

        // Stats should not change in vacation mode
        XCTAssertEqual(state.healthiness, 0.8, accuracy: 0.001)
        XCTAssertEqual(state.happiness, 0.7, accuracy: 0.001)
    }
}
