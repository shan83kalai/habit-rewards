import SwiftData
import XCTest
@testable import HabitRewards

/// One-off extra tasks: what they add to a day, where they show, and what they never change.
final class ExtraTaskTests: SwiftDataTestCase {
    private let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private let october = CalendarMonth(year: 2026, month: 10)

    private func day(_ month: Int, _ day: Int) -> Date {
        london.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private var context: ModelContext!
    private var children: [Child] = []
    private var habits: [Habit] = []

    private func seed() throws {
        context = try makeContext()
        try SeedData.seedIfNeeded(context)
        children = try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
        habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    private func set(_ child: Child, _ statuses: [HabitStatus], on date: Date) throws {
        for (habit, status) in zip(habits, statuses) {
            try DayEntry.upsert(child: child, habit: habit, date: date, status: status, in: context, calendar: london)
        }
    }

    @discardableResult
    private func task(_ title: String, _ pence: Int, for child: Child, on date: Date, done: Bool) -> ExtraTask {
        let task = ExtraTask.add(title, rewardPence: pence, for: child, on: date, calendar: london, in: context)
        task.isDone = done
        return task
    }

    private func board(_ child: Child, _ date: Date) throws -> DayBoard {
        DayBoard(
            child: child, day: date, habits: habits, entries: try context.fetch(FetchDescriptor<DayEntry>()),
            extraTasks: try context.fetch(FetchDescriptor<ExtraTask>()), rules: .standard, calendar: london
        )
    }

    private func sheet(_ child: Child) throws -> MonthSheet {
        MonthSheet(
            child: child, month: october, today: day(10, 10), habits: habits, entries: try context.fetch(FetchDescriptor<DayEntry>()),
            extraTasks: try context.fetch(FetchDescriptor<ExtraTask>()), rules: .standard, calendar: london
        )
    }

    // MARK: - Scoring

    func testExtrasGoOnAfterTheDaysFloor() {
        let engine = ScoringEngine(rules: .standard)
        // Six misses floor at £0; the £1 task still counts in full.
        XCTAssertEqual(engine.dayScore(Array(repeating: HabitStatus.missed, count: 6), extrasPence: 100), 100)
        XCTAssertEqual(engine.dayScore([.done, .done], extrasPence: 50), 150)
    }

    // MARK: - The task

    func testAddingATaskSetsItsDayChildAndReward() throws {
        try seed()
        let added = task("Wash the car", 100, for: children[0], on: day(10, 3), done: false)
        XCTAssertEqual(added.day, "2026-10-03")
        XCTAssertEqual(added.date, london.startOfDay(for: day(10, 3)))
        XCTAssertTrue(added.child === children[0])
        XCTAssertEqual(added.childID, children[0].id)
        XCTAssertEqual(added.cloudRecordName, "extra-\(added.id.uuidString)")
        XCTAssertTrue(added.hasUnsyncedChanges)
        XCTAssertEqual(added.earnedPence, 0)
        added.isDone = true
        XCTAssertEqual(added.earnedPence, 100)
    }

    // MARK: - Today

    func testTodayShowsOnlyThatChildsTasksForThatDay() throws {
        try seed()
        task("Wash the car", 100, for: children[0], on: day(10, 3), done: false)
        task("Tidy the garden", 200, for: children[0], on: day(10, 3), done: false)
        task("Yesterday's job", 100, for: children[0], on: day(10, 2), done: true)
        task("Someone else's", 100, for: children[1], on: day(10, 3), done: true)

        XCTAssertEqual(try board(children[0], day(10, 3)).extras.map(\.title), ["Wash the car", "Tidy the garden"])
    }

    func testOnlyDoneTasksAddToTheDayAndMonth() throws {
        try seed()
        try set(children[0], [.done, .done], on: day(10, 3)) // £1.00 from habits
        task("Wash the car", 100, for: children[0], on: day(10, 3), done: true)
        task("Not done", 500, for: children[0], on: day(10, 3), done: false)
        task("Earlier", 200, for: children[0], on: day(10, 1), done: true)

        let board = try board(children[0], day(10, 3))
        XCTAssertEqual(board.dayPence, 200)
        XCTAssertEqual(board.monthPence, 400)
        XCTAssertEqual(board.rows.count, 6, "extras aren't habits")
    }

    // MARK: - Month

    func testMonthAddsExtrasToTheirDaysAndTotals() throws {
        try seed()
        try set(children[0], Array(repeating: .done, count: 6), on: day(10, 1)) // £3.00, perfect
        task("Wash the car", 100, for: children[0], on: day(10, 1), done: true)
        task("Garden", 200, for: children[0], on: day(10, 2), done: true)
        task("Skipped", 100, for: children[0], on: day(10, 2), done: false)

        let sheet = try sheet(children[0])
        XCTAssertEqual(Array(sheet.extrasByDay.prefix(3)), [100, 200, 0])
        XCTAssertEqual(Array(sheet.dayScores.prefix(3)), [400, 200, 0])
        XCTAssertEqual(sheet.total, 600)
        XCTAssertEqual(sheet.extrasTotal, 300)
        XCTAssertEqual(sheet.extrasDone, 2)
        XCTAssertEqual(sheet.extraTasks.map(\.title), ["Wash the car", "Garden", "Skipped"])
        XCTAssertEqual(sheet.perfectDays, 1, "extras never make or break a perfect day")
    }

    func testMonthIgnoresOtherMonthsAndChildren() throws {
        try seed()
        task("September", 100, for: children[0], on: day(9, 30), done: true)
        task("Other child", 100, for: children[1], on: day(10, 2), done: true)
        let sheet = try sheet(children[0])
        XCTAssertTrue(sheet.extraTasks.isEmpty)
        XCTAssertEqual(sheet.total, 0)
    }

    // MARK: - Export

    func testCSVListsTheMonthsExtraTasks() throws {
        try seed()
        task("Wash the car", 100, for: children[0], on: day(10, 2), done: true)
        let report = MonthReport(title: "October 2026", sheets: [(name: children[0].name, sheet: try sheet(children[0]))], currencyCode: "GBP")
        let lines = report.csv.components(separatedBy: "\r\n")

        let extrasRow = try XCTUnwrap(lines.first { $0.hasPrefix("Extras (") })
        XCTAssertEqual(Array(extrasRow.components(separatedBy: ",")[1...3]), ["", "1.00", ""])
        XCTAssertTrue(lines.contains { $0.hasPrefix("Extra task,Day,Reward (") })
        XCTAssertTrue(lines.contains("Wash the car,2,1.00,✓"))
        XCTAssertTrue(lines.contains { $0.hasPrefix("Day score (£),0.00,1.00,") })
    }

    func testCSVWithoutExtrasIsUnchanged() throws {
        try seed()
        let report = MonthReport(title: "October 2026", sheets: [(name: children[0].name, sheet: try sheet(children[0]))], currencyCode: "GBP")
        XCTAssertFalse(report.csv.contains("Extra"))
    }

    // MARK: - Quick picks

    func testQuickPicksFollowTheMonthsReward() {
        XCTAssertEqual(ExtraTaskEditor.quickPicks(for: .standard), [50, 100, 200])
        XCTAssertEqual(ExtraTaskEditor.quickPicks(for: ScoringRules(rewardPence: 10, penaltyPence: 0)), [10, 20, 40])
        XCTAssertEqual(ExtraTaskEditor.quickPicks(for: ScoringRules(rewardPence: 0, penaltyPence: 0)), [50, 100, 200])
    }
}
