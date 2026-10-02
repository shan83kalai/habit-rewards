import XCTest
@testable import HabitRewards

final class CalendarMonthTests: XCTestCase {
    private let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        london.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testMonthContainingADate() {
        XCTAssertEqual(CalendarMonth(containing: date(2026, 10, 2, hour: 23), calendar: london), CalendarMonth(year: 2026, month: 10))
    }

    func testPreviousAndNextWrapAroundTheYear() {
        XCTAssertEqual(CalendarMonth(year: 2026, month: 1).previous, CalendarMonth(year: 2025, month: 12))
        XCTAssertEqual(CalendarMonth(year: 2026, month: 12).next, CalendarMonth(year: 2027, month: 1))
        XCTAssertEqual(CalendarMonth(year: 2026, month: 10).previous, CalendarMonth(year: 2026, month: 9))
        XCTAssertEqual(CalendarMonth(year: 2026, month: 10).next, CalendarMonth(year: 2026, month: 11))
    }

    func testMonthsAreOrdered() {
        XCTAssertLessThan(CalendarMonth(year: 2026, month: 9), CalendarMonth(year: 2026, month: 10))
        XCTAssertLessThan(CalendarMonth(year: 2025, month: 12), CalendarMonth(year: 2026, month: 1))
    }

    func testDaysAreEveryStartOfDayInTheMonth() {
        let october = CalendarMonth(year: 2026, month: 10).days(in: london)
        XCTAssertEqual(october.count, 31)
        XCTAssertEqual(october.first, date(2026, 10, 1))
        XCTAssertEqual(october.last, date(2026, 10, 31))
        // Includes the 25-hour day when the clocks go back, without skipping or repeating a day.
        XCTAssertEqual(october[24], date(2026, 10, 25))
        XCTAssertEqual(october[25], date(2026, 10, 26))
    }

    func testDayCountsFollowTheCalendar() {
        XCTAssertEqual(CalendarMonth(year: 2026, month: 9).days(in: london).count, 30)
        XCTAssertEqual(CalendarMonth(year: 2027, month: 2).days(in: london).count, 28)
        XCTAssertEqual(CalendarMonth(year: 2028, month: 2).days(in: london).count, 29)
    }

    func testIntervalRunsFromTheFirstToTheFirstOfNextMonth() {
        let interval = CalendarMonth(year: 2026, month: 12).interval(in: london)
        XCTAssertEqual(interval.start, date(2026, 12, 1))
        XCTAssertEqual(interval.end, date(2027, 1, 1))
    }
}
