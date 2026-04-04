import XCTest
@testable import TamaGoosie

final class SyncPayloadTests: XCTestCase {

    func test_gooseSyncPayload_encodeDecode_roundtrip() throws {
        let original = GooseSyncPayload(
            healthiness: 0.75,
            happiness: 0.65,
            mood: GooseMood.happy.rawValue,
            name: "Harold",
            streakDays: 12,
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
        XCTAssertEqual(decoded.streakDays, original.streakDays)
        XCTAssertEqual(decoded.topGoals.count, 2)
        XCTAssertEqual(decoded.topGoals[0].title, "Walk")
        XCTAssertEqual(decoded.topGoals[1].progress, 0.5, accuracy: 0.001)
    }

    func test_gooseSyncPayload_defaultsAreValid() {
        let payload = GooseSyncPayload()
        XCTAssertGreaterThanOrEqual(payload.healthiness, 0.0)
        XCTAssertLessThanOrEqual(payload.healthiness, 1.0)
        XCTAssertGreaterThanOrEqual(payload.happiness, 0.0)
        XCTAssertLessThanOrEqual(payload.happiness, 1.0)
        XCTAssertTrue(payload.topGoals.isEmpty)
    }

    func test_gooseMood_deriveMood_returnsCorrectMood() {
        XCTAssertEqual(GooseMood.deriveMood(healthiness: 1.0, happiness: 1.0), .ecstatic)
        XCTAssertEqual(GooseMood.deriveMood(healthiness: 0.7, happiness: 0.7), .happy)
        XCTAssertEqual(GooseMood.deriveMood(healthiness: 0.5, happiness: 0.5), .content)
        XCTAssertEqual(GooseMood.deriveMood(healthiness: 0.3, happiness: 0.3), .bored)
        XCTAssertEqual(GooseMood.deriveMood(healthiness: 0.15, happiness: 0.15), .sad)
        XCTAssertEqual(GooseMood.deriveMood(healthiness: 0.05, happiness: 0.05), .sick)
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

    func test_gooseSyncPayload_moodEnum_derivedFromRawValue() {
        let payload = GooseSyncPayload(mood: GooseMood.sick.rawValue)
        XCTAssertEqual(payload.moodEnum, .sick)
    }
}
