import SwiftData
import XCTest
@testable import HabitRewards

/// The month grid and summary numbers, built from real (in-memory) SwiftData entries.
final class MonthSheetTests: SwiftDataTestCase {
    private let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private let october = CalendarMonth(year: 2026, month: 10)

    private func day(_ month: Int, _ day: Int, hour: Int = 12) -> Date {
        london.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private var context: ModelContext!
    private var firstChild: Child!
    private var secondChild: Child!
    private var habits: [Habit] = []

    private let sixDone: [HabitStatus] = Array(repeating: .done, count: 6)
    private let fiveAndAMiss: [HabitStatus] = [.done, .done, .done, .done, .done, .missed]

    private func seed() throws {
        context = try makeContext()
        try SeedData.seedIfNeeded(context)
        let children = try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
        firstChild = children[0]
        secondChild = children[1]
        habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    private func set(_ child: Child, _ statuses: [HabitStatus], on date: Date) throws {
        for (habit, status) in zip(habits, statuses) {
            try DayEntry.upsert(child: child, habit: habit, date: date, status: status, in: context, calendar: london)
        }
    }

    /// "Today" defaults to 10 October 2026.
    private func sheet(_ child: Child, month: CalendarMonth? = nil, today: Date? = nil, rules: ScoringRules = .standard) throws -> MonthSheet {
        let entries = try context.fetch(FetchDescriptor<DayEntry>())
        return MonthSheet(
            child: child, month: month ?? october, today: today ?? day(10, 10), habits: habits,
            entries: entries, rules: rules, calendar: london
        )
    }

    // MARK: - Grid

    func testGridHasEveryDayAndEveryHabit() throws {
        try seed()
        let sheet = try sheet(firstChild)

        XCTAssertEqual(sheet.days.count, 31)
        XCTAssertEqual(sheet.rows.map(\.habit.title), habits.map(\.title))
        XCTAssertTrue(sheet.rows.allSatisfy { $0.statuses.count == 31 })
    }

    func testCellsLineUpWithTheirDays() throws {
        try seed()
        try set(firstChild, fiveAndAMiss, on: day(10, 3))

        let sheet = try sheet(firstChild)
        XCTAssertEqual(sheet.rows.map { $0.statuses[2] }, fiveAndAMiss) // 3 October
        XCTAssertTrue(sheet.rows.allSatisfy { $0.statuses[1] == .unset }) // 2 October
    }

    func testDaysAfterTodayAreLockedAndHaveNoScore() throws {
        try seed()
        let sheet = try sheet(firstChild)

        XCTAssertEqual(sheet.todayIndex, 9)
        XCTAssertFalse(sheet.isLocked(dayIndex: 9))
        XCTAssertTrue(sheet.isLocked(dayIndex: 10))
        XCTAssertEqual(sheet.dayScores[9], 0)
        XCTAssertNil(sheet.dayScores[10])
        XCTAssertNil(sheet.runningTotals[30])
    }

    func testDayScoresAndRunningTotals() throws {
        try seed()
        try set(firstChild, sixDone, on: day(10, 1))                                        // 300
        try set(firstChild, fiveAndAMiss, on: day(10, 2))                                   // 175
        try set(firstChild, [.done, .done, .missed, .missed, .missed, .missed], on: day(10, 3)) // −200 → 0
        try set(firstChild, [.done, .unset, .unset, .unset, .unset, .unset], on: day(10, 4)) // 50

        let sheet = try sheet(firstChild)
        XCTAssertEqual(Array(sheet.dayScores.prefix(5)), [300, 175, 0, 50, 0])
        XCTAssertEqual(Array(sheet.runningTotals.prefix(5)), [300, 475, 475, 525, 525])
        XCTAssertEqual(sheet.runningTotals[9], 525)
        XCTAssertEqual(sheet.total, 525)
    }

    func testMonthTotalMatchesTheTodayScreen() throws {
        try seed()
        try set(firstChild, sixDone, on: day(10, 1))
        try set(firstChild, fiveAndAMiss, on: day(10, 5))
        try set(firstChild, [.missed, .missed, .done, .done, .done, .unset], on: day(10, 9))
        let entries = try context.fetch(FetchDescriptor<DayEntry>())

        let today = DayBoard(child: firstChild, day: day(10, 10), habits: habits, entries: entries, rules: .standard, calendar: london)
        XCTAssertEqual(try sheet(firstChild).total, today.monthPence)
    }

    func testPastMonthHasNoLockedDays() throws {
        try seed()
        try set(firstChild, sixDone, on: day(9, 30))

        let september = try sheet(firstChild, month: CalendarMonth(year: 2026, month: 9))
        XCTAssertEqual(september.days.count, 30)
        XCTAssertNil(september.todayIndex)
        XCTAssertFalse((0..<30).contains { september.isLocked(dayIndex: $0) })
        XCTAssertEqual(september.total, 300)
        XCTAssertEqual(try sheet(firstChild).total, 0) // and none of it leaks into October
    }

    func testOnlyThatChildsEntriesCount() throws {
        try seed()
        try set(firstChild, sixDone, on: day(10, 1))

        let sheet = try sheet(secondChild)
        XCTAssertEqual(sheet.total, 0)
        XCTAssertTrue(sheet.rows.allSatisfy { $0.statuses.allSatisfy { $0 == .unset } })
    }

    func testUsesTheGivenRules() throws {
        try seed()
        try set(firstChild, fiveAndAMiss, on: day(10, 1))
        XCTAssertEqual(try sheet(firstChild, rules: ScoringRules(rewardPence: 50, penaltyPence: 100)).total, 150)
    }

    func testInactiveHabitOnlyShowsInMonthsWhereItWasUsed() throws {
        try seed()
        let exercise = habits[5]
        try DayEntry.upsert(child: firstChild, habit: exercise, date: day(9, 15), status: .done, in: context, calendar: london)
        exercise.isActive = false

        XCTAssertEqual(try sheet(firstChild).rows.count, 5)
        XCTAssertEqual(try sheet(firstChild, month: CalendarMonth(year: 2026, month: 9)).rows.count, 6)
    }

    func testHabitForAnotherChildOnlyShowsInMonthsTheyTickedIt() throws {
        try seed()
        let exercise = habits[5]
        try DayEntry.upsert(child: firstChild, habit: exercise, date: day(9, 15), status: .done, in: context, calendar: london)
        exercise.childIDs = [secondChild.id]

        XCTAssertEqual(try sheet(firstChild).rows.count, 5)
        XCTAssertEqual(try sheet(firstChild, month: CalendarMonth(year: 2026, month: 9)).rows.count, 6)
        XCTAssertEqual(try sheet(secondChild).rows.count, 6)
    }

    // MARK: - Summary stats

    func testPerfectDaysAndBestStreak() throws {
        try seed()
        for date in [day(10, 1), day(10, 2), day(10, 4), day(10, 5), day(10, 6)] {
            try set(firstChild, sixDone, on: date)
        }
        try set(firstChild, fiveAndAMiss, on: day(10, 3))

        let sheet = try sheet(firstChild)
        XCTAssertEqual(sheet.perfectDays, 5)
        XCTAssertEqual(sheet.bestStreak, 3) // 4–6 October
    }

    func testDayWithAnUntickedHabitIsNotPerfect() throws {
        try seed()
        try set(firstChild, [.done, .done, .done, .done, .done, .unset], on: day(10, 1))
        XCTAssertEqual(try sheet(firstChild).perfectDays, 0)
    }

    func testPerfectDayOnlyNeedsTheHabitsThatCountThatDay() throws {
        try seed()
        habits[5].isActive = false
        try set(firstChild, [.done, .done, .done, .done, .done], on: day(10, 1))
        XCTAssertEqual(try sheet(firstChild).perfectDays, 1)
    }

    func testEachChildsPerfectDayNeedsOnlyTheirOwnHabits() throws {
        try seed()
        habits[5].childIDs = [secondChild.id]
        // Five done is perfect for the first child; the second child also has the sixth habit.
        try set(firstChild, [.done, .done, .done, .done, .done], on: day(10, 1))
        try set(secondChild, [.done, .done, .done, .done, .done], on: day(10, 1))

        XCTAssertEqual(try sheet(firstChild).perfectDays, 1)
        XCTAssertEqual(try sheet(secondChild).perfectDays, 0)
        XCTAssertEqual(try sheet(firstChild).total, 250)
    }

    func testBestAndMostMissedHabits() throws {
        try seed()
        try set(firstChild, [.done, .done, .done, .done, .missed, .done], on: day(10, 1))
        try set(firstChild, [.done, .done, .missed, .done, .missed, .unset], on: day(10, 2))
        try set(firstChild, [.missed, .done, .done, .unset, .missed, .unset], on: day(10, 3))

        let sheet = try sheet(firstChild)
        XCTAssertEqual(sheet.mostDoneHabit?.title, "Reading")    // done 3 times
        XCTAssertEqual(sheet.mostMissedHabit?.title, "Tidy room") // missed 3 times
        XCTAssertEqual(sheet.count(.done, for: habits[1]), 3)
        XCTAssertEqual(sheet.count(.missed, for: habits[4]), 3)
        XCTAssertEqual(sheet.count(.missed, for: habits[0]), 1)
    }

    func testEmptyMonthHasNoStats() throws {
        try seed()
        let sheet = try sheet(firstChild)
        XCTAssertEqual(sheet.total, 0)
        XCTAssertEqual(sheet.perfectDays, 0)
        XCTAssertEqual(sheet.bestStreak, 0)
        XCTAssertNil(sheet.mostDoneHabit)
        XCTAssertNil(sheet.mostMissedHabit)
    }
}
