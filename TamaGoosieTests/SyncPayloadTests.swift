import XCTest
@testable import TamaGoosie

final class SyncPayloadTests: XCTestCase {

    func test_gooseSyncPayload_encodeDecode_roundtrip() throws {
        let original = GooseSyncPayload(
            healthiness: 0.75,
            happiness: 0.65,
            mood: GooseMood.happy.rawValue,
            phase: GoosePhase.adult.rawValue,
            name: "Harold",
            level: 5,
            streakDays: 12,
            isDead: false,
            spriteID: "default",
            topGoals: [
                GoalSummary(id: UUID(), title: "Walk", progress: 1.0, category: "health"),
                GoalSummary(id: UUID(), title: "Sleep", progress: 0.5, category: "health"),
            ]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GooseSyncPayload.self, from: data)

        XCTAssertEqual(decoded.healthiness, original.healthiness, accuracy: 0.001)
        XCTAssertEqual(decoded.happiness, original.happiness, accuracy: 0.001)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.level, original.level)
        XCTAssertEqual(decoded.streakDays, original.streakDays)
        XCTAssertEqual(decoded.topGoals.count, 2)
        XCTAssertEqual(decoded.topGoals[0].title, "Walk")
        XCTAssertEqual(decoded.topGoals[1].progress, 0.5, accuracy: 0.001)
    }

    func test_gooseSyncPayload_moodEnum_derivedCorrectly() {
        let deadPayload = GooseSyncPayload(
            healthiness: 0, happiness: 0, mood: GooseMood.dead.rawValue,
            phase: GoosePhase.adult.rawValue, name: "Harold", level: 1,
            streakDays: 0, isDead: true, spriteID: "default", topGoals: []
        )
        XCTAssertEqual(deadPayload.moodEnum, .dead)
    }

    func test_gooseSyncPayload_defaultsAreValid() {
        let payload = GooseSyncPayload()
        XCTAssertGreaterThanOrEqual(payload.healthiness, 0.0)
        XCTAssertLessThanOrEqual(payload.healthiness, 1.0)
        XCTAssertGreaterThanOrEqual(payload.happiness, 0.0)
        XCTAssertLessThanOrEqual(payload.happiness, 1.0)
        XCTAssertFalse(payload.isDead)
        XCTAssertTrue(payload.topGoals.isEmpty)
    }

    func test_gooseMood_deriveMood_returnsCorrectMood() {
        // avg = 1.0 → ecstatic (>= 0.80)
        XCTAssertEqual(GooseMood.deriveMood(healthiness: 1.0, happiness: 1.0), .ecstatic)
        // avg = 0.7 → happy (0.60..<0.80)
        XCTAssertEqual(GooseMood.deriveMood(healthiness: 0.7, happiness: 0.7), .happy)
        // avg = 0.5 → content (0.40..<0.60)
        XCTAssertEqual(GooseMood.deriveMood(healthiness: 0.5, happiness: 0.5), .content)
        // avg = 0.3 → bored (0.25..<0.40)
        XCTAssertEqual(GooseMood.deriveMood(healthiness: 0.3, happiness: 0.3), .bored)
        // avg = 0.15 → sad (0.10..<0.25)
        XCTAssertEqual(GooseMood.deriveMood(healthiness: 0.15, happiness: 0.15), .sad)
        // avg = 0.05 → sick (< 0.10)
        XCTAssertEqual(GooseMood.deriveMood(healthiness: 0.05, happiness: 0.05), .sick)
        // healthiness = 0.0 → dead
        XCTAssertEqual(GooseMood.deriveMood(healthiness: 0.0, happiness: 0.5), .dead)
    }

    func test_goosePhase_phaseForLevel_returnsCorrectPhase() {
        XCTAssertEqual(GoosePhase.phase(forLevel: 0), .egg)
        XCTAssertEqual(GoosePhase.phase(forLevel: 1), .baby)
        XCTAssertEqual(GoosePhase.phase(forLevel: 5), .baby)  // 1...5 = baby
        XCTAssertEqual(GoosePhase.phase(forLevel: 6), .teen)  // 6...15 = teen
        XCTAssertEqual(GoosePhase.phase(forLevel: 20), .adult)
    }

    func test_gooseState_toSyncPayload_includesTopGoals() {
        let state = GooseState(name: "Test Goose", healthiness: 0.9, happiness: 0.8)
        let goals = [
            GoalSummary(id: UUID(), title: "Goal 1", progress: 0.5, category: "health"),
        ]
        let payload = state.toSyncPayload(topGoals: goals)

        XCTAssertEqual(payload.name, "Test Goose")
        XCTAssertEqual(payload.healthiness, 0.9, accuracy: 0.001)
        XCTAssertEqual(payload.topGoals.count, 1)
        XCTAssertEqual(payload.topGoals[0].title, "Goal 1")
    }
}
