import XCTest
@testable import TamaGoosie

final class ScheduleWindowTests: XCTestCase {

    // MARK: - Same-day windows (no wrap)

    func test_sameDay_insideWindow_returnsTrue() {
        // Sunday (weekday 1), 14:30, window 14:00 → 17:00, active days {1}
        XCTAssertTrue(ScreenBlock.isInScheduleWindow(
            weekday: 1, nowMins: 14 * 60 + 30,
            startMins: 14 * 60, endMins: 17 * 60,
            activeDays: [1]
        ))
    }

    func test_sameDay_beforeWindow_returnsFalse() {
        XCTAssertFalse(ScreenBlock.isInScheduleWindow(
            weekday: 1, nowMins: 13 * 60,
            startMins: 14 * 60, endMins: 17 * 60,
            activeDays: [1]
        ))
    }

    func test_sameDay_atEnd_returnsFalse() {
        // End is exclusive
        XCTAssertFalse(ScreenBlock.isInScheduleWindow(
            weekday: 1, nowMins: 17 * 60,
            startMins: 14 * 60, endMins: 17 * 60,
            activeDays: [1]
        ))
    }

    func test_sameDay_wrongWeekday_returnsFalse() {
        XCTAssertFalse(ScreenBlock.isInScheduleWindow(
            weekday: 2, nowMins: 14 * 60 + 30,
            startMins: 14 * 60, endMins: 17 * 60,
            activeDays: [1]
        ))
    }

    // MARK: - Wrap windows (22:00 → 08:00)

    func test_wrap_lateSunday_returnsTrue_whenSundayActive() {
        // Sunday (weekday 1), 23:00, window 22:00 → 08:00, active {1}
        XCTAssertTrue(ScreenBlock.isInScheduleWindow(
            weekday: 1, nowMins: 23 * 60,
            startMins: 22 * 60, endMins: 8 * 60,
            activeDays: [1]
        ))
    }

    func test_wrap_earlyMonday_returnsTrue_whenSundayActive() {
        // Monday (weekday 2), 02:00 — inside Sunday's trailing wrap
        XCTAssertTrue(ScreenBlock.isInScheduleWindow(
            weekday: 2, nowMins: 2 * 60,
            startMins: 22 * 60, endMins: 8 * 60,
            activeDays: [1]
        ))
    }

    func test_wrap_earlyMonday_returnsFalse_whenSundayNotActive() {
        // Monday 02:00, Sunday is NOT in activeDays → not active
        XCTAssertFalse(ScreenBlock.isInScheduleWindow(
            weekday: 2, nowMins: 2 * 60,
            startMins: 22 * 60, endMins: 8 * 60,
            activeDays: [2]
        ))
    }

    func test_wrap_atEnd_returnsFalse() {
        // Monday 08:00 exactly — window has ended
        XCTAssertFalse(ScreenBlock.isInScheduleWindow(
            weekday: 2, nowMins: 8 * 60,
            startMins: 22 * 60, endMins: 8 * 60,
            activeDays: [1]
        ))
    }

    func test_wrap_lateMonday_returnsTrue_whenMondayActive() {
        // Monday 23:00, window 22→08 active on Monday → in next wrap session
        XCTAssertTrue(ScreenBlock.isInScheduleWindow(
            weekday: 2, nowMins: 23 * 60,
            startMins: 22 * 60, endMins: 8 * 60,
            activeDays: [2]
        ))
    }

    func test_wrap_middleOfDay_returnsFalse() {
        // Sunday 14:00 — outside both halves
        XCTAssertFalse(ScreenBlock.isInScheduleWindow(
            weekday: 1, nowMins: 14 * 60,
            startMins: 22 * 60, endMins: 8 * 60,
            activeDays: [1, 2, 3, 4, 5, 6, 7]
        ))
    }

    // MARK: - Weekday rollover (Saturday → Sunday)

    func test_wrap_earlySunday_returnsTrue_whenSaturdayActive() {
        // Sunday (1), 03:00, window 22→08, active {7=Saturday}
        // yesterday of Sunday (1) = ((1-2+7)%7)+1 = (6%7)+1 = 7 ✅
        XCTAssertTrue(ScreenBlock.isInScheduleWindow(
            weekday: 1, nowMins: 3 * 60,
            startMins: 22 * 60, endMins: 8 * 60,
            activeDays: [7]
        ))
    }

    // MARK: - Malformed windows

    func test_startEqualsEnd_returnsFalse() {
        XCTAssertFalse(ScreenBlock.isInScheduleWindow(
            weekday: 1, nowMins: 12 * 60,
            startMins: 22 * 60, endMins: 22 * 60,
            activeDays: [1, 2, 3, 4, 5, 6, 7]
        ))
    }

    func test_startEqualsEnd_anyTime_returnsFalse() {
        for nowMins in stride(from: 0, to: 1440, by: 60) {
            XCTAssertFalse(ScreenBlock.isInScheduleWindow(
                weekday: 1, nowMins: nowMins,
                startMins: 9 * 60, endMins: 9 * 60,
                activeDays: [1, 2, 3, 4, 5, 6, 7]
            ), "Should be false at \(nowMins)m for malformed start==end")
        }
    }

    // MARK: - Boundary cases

    func test_sameDay_atStart_returnsTrue() {
        XCTAssertTrue(ScreenBlock.isInScheduleWindow(
            weekday: 1, nowMins: 14 * 60,
            startMins: 14 * 60, endMins: 17 * 60,
            activeDays: [1]
        ))
    }

    func test_wrap_atStart_returnsTrue() {
        // Sunday 22:00 exactly — start of wrap window
        XCTAssertTrue(ScreenBlock.isInScheduleWindow(
            weekday: 1, nowMins: 22 * 60,
            startMins: 22 * 60, endMins: 8 * 60,
            activeDays: [1]
        ))
    }
}
