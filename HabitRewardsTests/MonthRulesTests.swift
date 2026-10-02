import SwiftData
import XCTest
@testable import HabitRewards

final class MonthRulesTests: SwiftDataTestCase {
    private let september = CalendarMonth(year: 2026, month: 9)
    private let october = CalendarMonth(year: 2026, month: 10)
    private let november = CalendarMonth(year: 2026, month: 11)
    private let higherPenalty = ScoringRules(rewardPence: 50, penaltyPence: 100)

    // MARK: - Which rules apply to a month

    func testSavedRulesApplyToTheirOwnMonth() {
        let saved = [MonthRules(year: 2026, month: 10, rules: .standard), MonthRules(year: 2026, month: 11, rules: higherPenalty)]
        XCTAssertEqual(MonthRules.rules(for: october, from: saved), .standard)
        XCTAssertEqual(MonthRules.rules(for: november, from: saved), higherPenalty)
    }

    func testMonthWithoutItsOwnRulesCarriesOnTheLatestEarlierRules() {
        let saved = [MonthRules(year: 2026, month: 11, rules: higherPenalty), MonthRules(year: 2026, month: 10, rules: .standard)]
        XCTAssertEqual(MonthRules.rules(for: CalendarMonth(year: 2026, month: 12), from: saved), higherPenalty)
        XCTAssertEqual(MonthRules.rules(for: CalendarMonth(year: 2027, month: 3), from: saved), higherPenalty)
    }

    func testLaterRulesNeverApplyToEarlierMonths() {
        let saved = [MonthRules(year: 2026, month: 11, rules: higherPenalty)]
        XCTAssertEqual(MonthRules.rules(for: october, from: saved), .standard)
        XCTAssertEqual(MonthRules.rules(for: september, from: saved), .standard)
    }

    func testNoSavedRulesMeansStandardRules() {
        XCTAssertEqual(MonthRules.rules(for: october, from: []), .standard)
    }

    // MARK: - Saving

    func testSetCreatesRulesForAMonth() throws {
        let context = try makeContext()
        try MonthRules.set(higherPenalty, for: november, in: context)

        let saved = try context.fetch(FetchDescriptor<MonthRules>())
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(MonthRules.rules(for: november, from: saved), higherPenalty)
    }

    func testSetUpdatesTheMonthsRulesWithoutDuplicating() throws {
        let context = try makeContext()
        try MonthRules.set(higherPenalty, for: november, in: context)
        try MonthRules.set(ScoringRules(rewardPence: 60, penaltyPence: 100), for: november, in: context)

        let saved = try context.fetch(FetchDescriptor<MonthRules>())
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.rewardPence, 60)
    }

    // MARK: - Snapshot when a month starts

    func testSnapshotCopiesTheRulesInForceWhenTheMonthStarts() throws {
        let context = try makeContext()
        try MonthRules.set(higherPenalty, for: october, in: context)
        try MonthRules.ensureSnapshot(for: november, in: context)

        let saved = try context.fetch(FetchDescriptor<MonthRules>())
        XCTAssertEqual(saved.count, 2)
        XCTAssertTrue(saved.contains { $0.year == 2026 && $0.month == 11 && $0.rules == higherPenalty })
    }

    func testSnapshotOfTheFirstMonthUsesStandardRules() throws {
        let context = try makeContext()
        try MonthRules.ensureSnapshot(for: october, in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MonthRules>()).map(\.rules), [.standard])
    }

    func testSnapshotKeepsRulesAlreadySetForThatMonth() throws {
        let context = try makeContext()
        try MonthRules.set(higherPenalty, for: november, in: context)
        try MonthRules.ensureSnapshot(for: november, in: context)

        let saved = try context.fetch(FetchDescriptor<MonthRules>())
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.rules, higherPenalty)
    }

    func testSnapshotIsOnlyTakenOnce() throws {
        let context = try makeContext()
        try MonthRules.ensureSnapshot(for: october, in: context)
        try MonthRules.ensureSnapshot(for: october, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthRules>()), 1)
    }

    // MARK: - Acceptance check from the plan

    func testChangingNovembersPenaltyDoesNotChangeOctobersTotal() throws {
        var london = Calendar(identifier: .gregorian)
        london.timeZone = TimeZone(identifier: "Europe/London")!
        let context = try makeContext()
        try SeedData.seedIfNeeded(context)
        let child = try XCTUnwrap(context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)])).first)
        let habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))

        // Two October days and two November days of five done, one missed.
        let fiveAndAMiss: [HabitStatus] = [.done, .done, .done, .done, .done, .missed]
        for (month, day) in [(10, 5), (10, 6), (11, 2), (11, 3)] {
            let date = london.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
            for (habit, status) in zip(habits, fiveAndAMiss) {
                try DayEntry.upsert(child: child, habit: habit, date: date, status: status, in: context, calendar: london)
            }
        }

        func total(_ month: CalendarMonth) throws -> Int {
            let entries = try context.fetch(FetchDescriptor<DayEntry>())
            let rules = MonthRules.rules(for: month, from: try context.fetch(FetchDescriptor<MonthRules>()))
            let lastDay = london.date(from: DateComponents(year: 2026, month: 12, day: 31))!
            return MonthSheet(child: child, month: month, today: lastDay, habits: habits, entries: entries, rules: rules, calendar: london).total
        }

        try MonthRules.ensureSnapshot(for: october, in: context)
        XCTAssertEqual(try total(october), 350)

        try MonthRules.ensureSnapshot(for: november, in: context)
        try MonthRules.set(higherPenalty, for: november, in: context)

        XCTAssertEqual(try total(october), 350) // unchanged
        XCTAssertEqual(try total(november), 300) // 2 × (250 − 100)
    }
}
