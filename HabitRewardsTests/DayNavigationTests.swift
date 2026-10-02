import XCTest
@testable import HabitRewards

final class DayNavigationTests: XCTestCase {
    private let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        london.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// "Today" is Friday 2 October 2026, mid-afternoon.
    private var navigation: DayNavigation {
        DayNavigation(today: day(2026, 10, 2, hour: 15), calendar: london)
    }

    func testTodayIsNormalisedToStartOfDay() {
        XCTAssertEqual(navigation.today, day(2026, 10, 2))
    }

    func testPreviousCrossesMonthBoundary() {
        XCTAssertEqual(navigation.previous(day(2026, 10, 1)), day(2026, 9, 30))
    }

    func testNextMovesForwardUpToToday() {
        XCTAssertEqual(navigation.next(day(2026, 9, 30)), day(2026, 10, 1))
        XCTAssertEqual(navigation.next(day(2026, 10, 1)), day(2026, 10, 2))
    }

    func testFutureDaysAreLocked() {
        XCTAssertEqual(navigation.next(day(2026, 10, 2)), day(2026, 10, 2))
        XCTAssertFalse(navigation.canGoForward(from: day(2026, 10, 2)))
        XCTAssertTrue(navigation.canGoForward(from: day(2026, 10, 1)))
    }

    func testClampedPullsFutureDaysBackToToday() {
        XCTAssertEqual(navigation.clamped(day(2026, 10, 5)), day(2026, 10, 2))
        XCTAssertEqual(navigation.clamped(day(2026, 9, 1, hour: 9)), day(2026, 9, 1))
    }

    func testRelativeDayNames() {
        XCTAssertEqual(navigation.relative(day(2026, 10, 2, hour: 20)), .today)
        XCTAssertEqual(navigation.relative(day(2026, 10, 1)), .yesterday)
        XCTAssertEqual(navigation.relative(day(2026, 9, 30)), .earlier)
    }

    func testEarlierMonthsNeedAParent() {
        XCTAssertTrue(navigation.isInEarlierMonth(day(2026, 9, 30)))
        XCTAssertTrue(navigation.isInEarlierMonth(day(2025, 12, 1)))
        XCTAssertFalse(navigation.isInEarlierMonth(day(2026, 10, 1)))
        XCTAssertFalse(navigation.isInEarlierMonth(day(2026, 10, 2, hour: 20)))
        XCTAssertEqual(navigation.currentMonth, CalendarMonth(year: 2026, month: 10))
    }

    func testIsInCurrentMonth() {
        XCTAssertTrue(navigation.isInCurrentMonth(day(2026, 10, 1)))
        XCTAssertFalse(navigation.isInCurrentMonth(day(2026, 9, 30)))
        XCTAssertFalse(navigation.isInCurrentMonth(day(2025, 10, 2)))
    }

    func testStepsCleanlyOverTheClocksGoingBack() {
        // UK clocks go back on Sunday 25 October 2026, so that day is 25 hours long.
        let lateOctober = DayNavigation(today: day(2026, 10, 27), calendar: london)
        XCTAssertEqual(lateOctober.previous(day(2026, 10, 26)), day(2026, 10, 25))
        XCTAssertEqual(lateOctober.previous(day(2026, 10, 25)), day(2026, 10, 24))
        XCTAssertEqual(lateOctober.next(day(2026, 10, 25)), day(2026, 10, 26))
    }

    func testMonthIntervalCoversTheWholeMonth() {
        let october = london.monthInterval(containing: day(2026, 10, 15, hour: 12))
        XCTAssertEqual(october.start, day(2026, 10, 1))
        XCTAssertEqual(october.end, day(2026, 11, 1))
    }
}
