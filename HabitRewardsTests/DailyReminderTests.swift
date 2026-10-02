import UserNotifications
import XCTest
@testable import HabitRewards

final class DailyReminderTests: XCTestCase {
    func testDefaultTimeIsHalfPastSeven() {
        XCTAssertEqual(ReminderTime.standard, ReminderTime(hour: 19, minute: 30))
        XCTAssertEqual(ReminderTime.standard.minutesSinceMidnight, 1_170)
    }

    func testMinutesRoundTrip() {
        XCTAssertEqual(ReminderTime(minutesSinceMidnight: 1_170), ReminderTime(hour: 19, minute: 30))
        XCTAssertEqual(ReminderTime(minutesSinceMidnight: 0), ReminderTime(hour: 0, minute: 0))
        XCTAssertEqual(ReminderTime(minutesSinceMidnight: 1_439), ReminderTime(hour: 23, minute: 59))
    }

    func testOutOfRangeMinutesWrapIntoTheDay() {
        XCTAssertEqual(ReminderTime(minutesSinceMidnight: 1_440 + 75), ReminderTime(hour: 1, minute: 15))
        XCTAssertEqual(ReminderTime(minutesSinceMidnight: -30), ReminderTime(hour: 23, minute: 30))
    }

    func testDateConversionUsesTheTimeOfDayOnly() {
        var london = Calendar(identifier: .gregorian)
        london.timeZone = TimeZone(identifier: "Europe/London")!
        let evening = london.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 20, minute: 15))!

        XCTAssertEqual(ReminderTime(date: evening, calendar: london), ReminderTime(hour: 20, minute: 15))
        let date = ReminderTime(hour: 7, minute: 5).date(on: evening, calendar: london)
        XCTAssertEqual(london.dateComponents([.year, .month, .day, .hour, .minute], from: date), DateComponents(year: 2026, month: 10, day: 2, hour: 7, minute: 5))
    }

    func testRequestRepeatsEveryDayAtTheChosenTime() throws {
        let request = DailyReminder.request(at: ReminderTime(hour: 19, minute: 30))

        XCTAssertEqual(request.identifier, DailyReminder.identifier)
        XCTAssertEqual(request.content.body, "Have you ticked today's habits?")
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 19)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
        XCTAssertNil(trigger.dateComponents.day) // every day, not one date
    }
}
