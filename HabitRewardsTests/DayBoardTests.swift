import SwiftData
import XCTest
@testable import HabitRewards

/// The Today screen's rows and live totals, built from real (in-memory) SwiftData entries.
final class DayBoardTests: SwiftDataTestCase {
    private let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private func day(_ month: Int, _ day: Int) -> Date {
        london.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private var context: ModelContext!
    private var firstChild: Child!
    private var secondChild: Child!
    private var habits: [Habit] = []

    /// Seeds the real children and six habits.
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

    private func board(_ child: Child, _ date: Date, rules: ScoringRules = .standard) throws -> DayBoard {
        let entries = try context.fetch(FetchDescriptor<DayEntry>())
        return DayBoard(child: child, day: date, habits: habits, entries: entries, rules: rules, calendar: london)
    }

    private let sixDone: [HabitStatus] = Array(repeating: .done, count: 6)
    private let sixMissed: [HabitStatus] = Array(repeating: .missed, count: 6)

    func testEmptyDayShowsSixUnsetHabitsAndZeroTotals() throws {
        try seed()
        let board = try board(firstChild, day(10, 2))

        XCTAssertEqual(board.rows.map(\.habit.title), habits.map(\.title))
        XCTAssertTrue(board.rows.allSatisfy { $0.status == .unset })
        XCTAssertEqual(board.dayPence, 0)
        XCTAssertEqual(board.monthPence, 0)
    }

    func testRowsShowThatDaysStatuses() throws {
        try seed()
        try set(firstChild, [.done, .missed, .unset, .done, .done, .missed], on: day(10, 2))
        try set(firstChild, sixDone, on: day(10, 1))

        let board = try board(firstChild, day(10, 2))
        XCTAssertEqual(board.rows.map(\.status), [.done, .missed, .unset, .done, .done, .missed])
    }

    func testDayAndMonthTotals() throws {
        try seed()
        try set(firstChild, sixDone, on: day(10, 1))                                     // 300
        try set(firstChild, [.done, .done, .done, .done, .done, .missed], on: day(10, 2)) // 175

        let board = try board(firstChild, day(10, 2))
        XCTAssertEqual(board.dayPence, 175)
        XCTAssertEqual(board.monthPence, 475)
    }

    func testBadDayDoesNotReduceMonthTotal() throws {
        try seed()
        try set(firstChild, sixDone, on: day(10, 1))
        try set(firstChild, sixMissed, on: day(10, 2))

        let board = try board(firstChild, day(10, 2))
        XCTAssertEqual(board.dayPence, 0)
        XCTAssertEqual(board.monthPence, 300)
    }

    func testEachChildOnlySeesTheirOwnEntries() throws {
        try seed()
        try set(firstChild, sixDone, on: day(10, 2))

        let secondChildBoard = try board(secondChild, day(10, 2))
        XCTAssertTrue(secondChildBoard.rows.allSatisfy { $0.status == .unset })
        XCTAssertEqual(secondChildBoard.dayPence, 0)
        XCTAssertEqual(secondChildBoard.monthPence, 0)
        XCTAssertEqual(try board(firstChild, day(10, 2)).dayPence, 300)
    }

    func testMonthTotalOnlyCountsTheShownDaysMonth() throws {
        try seed()
        try set(firstChild, sixDone, on: day(9, 30))
        try set(firstChild, [.done, .unset, .unset, .unset, .unset, .unset], on: day(10, 1))

        XCTAssertEqual(try board(firstChild, day(10, 1)).monthPence, 50)
        XCTAssertEqual(try board(firstChild, day(9, 30)).monthPence, 300)
    }

    func testTappingThroughTheCycleUpdatesTheTotals() throws {
        try seed()
        try set(firstChild, [.unset, .done, .done, .done, .done, .done], on: day(10, 2)) // 250
        let homework = habits[0]
        var status = HabitStatus.unset

        var dayTotals: [Int] = []
        for _ in 0..<3 {
            status = status.next
            try DayEntry.upsert(child: firstChild, habit: homework, date: day(10, 2), status: status, in: context, calendar: london)
            dayTotals.append(try board(firstChild, day(10, 2)).dayPence)
        }
        // Done (+50), missed (−75), cleared.
        XCTAssertEqual(dayTotals, [300, 175, 250])
    }

    func testInactiveHabitIsHiddenUnlessItHasAnEntryThatDay() throws {
        try seed()
        let exercise = habits[5]
        try DayEntry.upsert(child: firstChild, habit: exercise, date: day(10, 1), status: .done, in: context, calendar: london)
        exercise.isActive = false

        let dayWithoutEntry = try board(firstChild, day(10, 2))
        XCTAssertEqual(dayWithoutEntry.rows.count, 5)
        XCTAssertFalse(dayWithoutEntry.rows.contains { $0.habit === exercise })

        let dayWithEntry = try board(firstChild, day(10, 1))
        XCTAssertEqual(dayWithEntry.rows.count, 6)
        XCTAssertEqual(dayWithEntry.dayPence, 50)
    }

    func testUsesTheGivenRules() throws {
        try seed()
        try set(firstChild, [.done, .done, .done, .done, .done, .missed], on: day(10, 2))

        let board = try board(firstChild, day(10, 2), rules: ScoringRules(rewardPence: 100, penaltyPence: 25))
        XCTAssertEqual(board.dayPence, 475)
        XCTAssertEqual(board.monthPence, 475)
    }
}
