import SwiftData
import XCTest
@testable import HabitRewards

final class BackupTests: SwiftDataTestCase {
    private let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private let october = CalendarMonth(year: 2026, month: 10)

    private func day(_ month: Int, _ day: Int) -> Date {
        london.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    /// Seed data plus ticks over two months, a rules change, an archived child and a payment.
    private func makeFamily() throws -> ModelContext {
        let context = try makeContext()
        try SeedData.seedIfNeeded(context)
        let children = try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
        let habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
        for (index, habit) in habits.enumerated() {
            try DayEntry.upsert(child: children[0], habit: habit, date: day(9, 30), status: .done, in: context, calendar: london)
            try DayEntry.upsert(child: children[0], habit: habit, date: day(10, 1), status: index == 2 ? .missed : .done, in: context, calendar: london)
            try DayEntry.upsert(child: children[1], habit: habit, date: day(10, 1), status: index < 3 ? .done : .unset, in: context, calendar: london)
        }
        habits[5].isActive = false
        habits[4].childIDs = [children[1].id]
        children[1].colourHex = "#14B8A6"
        try MonthRules.set(.standard, for: october.previous, in: context)
        try MonthRules.set(ScoringRules(rewardPence: 60, penaltyPence: 80), for: october, in: context)
        Payout.record(300, to: children[0], for: october.previous, paidOn: day(10, 1), in: context)
        let archived = Child(name: "Cousin", colourHex: "#3B82F6", sortOrder: 2)
        archived.isArchived = true
        context.insert(archived)
        try context.save()
        return context
    }

    private func totals(in context: ModelContext) throws -> [String: Int] {
        let children = try context.fetch(FetchDescriptor<Child>())
        let habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
        let entries = try context.fetch(FetchDescriptor<DayEntry>())
        let rules = try context.fetch(FetchDescriptor<MonthRules>())
        var totals: [String: Int] = [:]
        for child in children {
            for month in [october.previous, october] {
                let sheet = MonthSheet(
                    child: child, month: month, today: day(10, 31), habits: habits, entries: entries,
                    rules: MonthRules.rules(for: month, from: rules), calendar: london
                )
                totals["\(child.name) \(month.month)"] = sheet.total
            }
        }
        return totals
    }

    // MARK: - Round trip

    func testBackupRestoresIntoAnEmptyPhoneExactly() throws {
        let original = try makeFamily()
        let data = try Backup.make(from: original, calendar: london).encoded()

        let fresh = try makeContext()
        try Backup.decode(data).restore(into: fresh, calendar: london)

        XCTAssertEqual(try totals(in: fresh), try totals(in: original))
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<Child>()), 3)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<Habit>()), 6)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<DayEntry>()), try original.fetchCount(FetchDescriptor<DayEntry>()))
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<Payout>()), 1)
        XCTAssertEqual(MonthRules.rules(for: october, from: try fresh.fetch(FetchDescriptor<MonthRules>())), ScoringRules(rewardPence: 60, penaltyPence: 80))
    }

    func testRestoreKeepsIDsSettingsAndRelationships() throws {
        let original = try makeFamily()
        let backup = try Backup.make(from: original, calendar: london)
        let fresh = try makeContext()
        try backup.restore(into: fresh, calendar: london)

        let originalIDs = Set(try original.fetch(FetchDescriptor<Child>()).map(\.id))
        let children = try fresh.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertEqual(Set(children.map(\.id)), originalIDs)
        XCTAssertEqual(children.map(\.name), ["Child 1", "Child 2", "Cousin"])
        XCTAssertEqual(children[1].colourHex, "#14B8A6")
        XCTAssertTrue(children[2].isArchived)
        let habits = try fresh.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertFalse(habits[5].isActive)
        XCTAssertEqual(habits[4].childIDs, [children[1].id])
        XCTAssertEqual(habits[0].childIDs, [])

        let payout = try XCTUnwrap(fresh.fetch(FetchDescriptor<Payout>()).first)
        XCTAssertTrue(payout.child === children[0])
        XCTAssertEqual(payout.paidOn, day(10, 1))
        XCTAssertTrue(try fresh.fetch(FetchDescriptor<DayEntry>()).allSatisfy { $0.child != nil && $0.habit != nil })
    }

    func testRestoreReplacesWhatWasThere() throws {
        let original = try makeFamily()
        let backup = try Backup.make(from: original, calendar: london)

        // The phone being restored already has different data.
        let other = try makeContext()
        try SeedData.seedIfNeeded(other)
        let stranger = Child(name: "Someone else", colourHex: "#000000", sortOrder: 5)
        other.insert(stranger)
        try other.save()

        try backup.restore(into: other, calendar: london)
        let names = try other.fetch(FetchDescriptor<Child>()).map(\.name)
        XCTAssertEqual(Set(names), ["Child 1", "Child 2", "Cousin"])
        XCTAssertEqual(try other.fetchCount(FetchDescriptor<Habit>()), 6)
    }

    func testRestoringOverTheSameDataPutsItBack() throws {
        let context = try makeFamily()
        let backup = try Backup.make(from: context, calendar: london)
        let before = try totals(in: context)
        let entryCount = try context.fetchCount(FetchDescriptor<DayEntry>())

        // Mess things up after the backup: clear a day and remove the payment.
        let children = try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
        for habit in try context.fetch(FetchDescriptor<Habit>()) {
            try DayEntry.upsert(child: children[0], habit: habit, date: day(10, 1), status: .unset, in: context, calendar: london)
        }
        for payout in try context.fetch(FetchDescriptor<Payout>()) { context.delete(payout) }
        try context.save()
        XCTAssertNotEqual(try totals(in: context), before)

        try backup.restore(into: context, calendar: london)
        XCTAssertEqual(try totals(in: context), before)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DayEntry>()), entryCount)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Payout>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Child>()), 3)
    }

    func testDayStringsRoundTripAndRejectImpossibleDates() {
        let date = DayEntry.date(fromDayString: "2028-02-29", calendar: london)
        XCTAssertEqual(date.map { DayEntry.dayString(for: $0, calendar: london) }, "2028-02-29")
        XCTAssertNil(DayEntry.date(fromDayString: "2027-02-29", calendar: london))
        XCTAssertNil(DayEntry.date(fromDayString: "2026-10", calendar: london))
        XCTAssertNil(DayEntry.date(fromDayString: "yesterday", calendar: london))
    }

    func testDaysSurviveAChangeOfTimeZone() throws {
        let original = try makeFamily()
        let data = try Backup.make(from: original, calendar: london).encoded()

        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let fresh = try makeContext()
        try Backup.decode(data).restore(into: fresh, calendar: newYork)

        let days = Set(try fresh.fetch(FetchDescriptor<DayEntry>()).map { DayEntry.dayString(for: $0.date, calendar: newYork) })
        XCTAssertEqual(days, ["2026-09-30", "2026-10-01"])
    }

    // MARK: - File format

    func testBackupFileIsReadableJSONWithAVersion() throws {
        let data = try Backup.make(from: try makeFamily(), calendar: london).encoded()
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["version"] as? Int, Backup.currentVersion)
        let entries = try XCTUnwrap(json["entries"] as? [[String: Any]])
        XCTAssertTrue(entries.contains { $0["day"] as? String == "2026-09-30" && $0["status"] as? String == "done" })
    }

    func testVersionOneBackupRestoresEveryHabitForEveryone() throws {
        // Version 1 files have no childIDs.
        let data = try Backup.make(from: try makeFamily(), calendar: london).encoded()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["version"] = 1
        json["habits"] = try XCTUnwrap(json["habits"] as? [[String: Any]]).map { $0.filter { $0.key != "childIDs" } }
        let fresh = try makeContext()
        try Backup.decode(try JSONSerialization.data(withJSONObject: json)).restore(into: fresh, calendar: london)

        XCTAssertTrue(try fresh.fetch(FetchDescriptor<Habit>()).allSatisfy { $0.childIDs.isEmpty })
    }

    // MARK: - Bad files

    func testRejectsAFileThatIsNotABackup() {
        XCTAssertThrowsError(try Backup.decode(Data("{\"hello\": 1}".utf8))) { error in
            XCTAssertEqual(error as? Backup.RestoreError, .unreadable)
        }
        XCTAssertThrowsError(try Backup.decode(Data("not json".utf8)))
    }

    func testRejectsABackupFromANewerVersionOfTheApp() throws {
        var backup = try Backup.make(from: try makeFamily(), calendar: london)
        backup.version = Backup.currentVersion + 1
        XCTAssertThrowsError(try Backup.decode(try backup.encoded())) { error in
            XCTAssertEqual(error as? Backup.RestoreError, .newerVersion)
        }
    }

    func testBrokenBackupLeavesTheCurrentDataAlone() throws {
        let context = try makeFamily()
        var backup = try Backup.make(from: context, calendar: london)
        backup.entries.append(.init(childID: UUID(), habitID: UUID(), day: "2026-10-02", status: .done))
        let before = try totals(in: context)

        XCTAssertThrowsError(try backup.restore(into: context, calendar: london)) { error in
            XCTAssertEqual(error as? Backup.RestoreError, .brokenReference)
        }
        XCTAssertEqual(try totals(in: context), before)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Child>()), 3)
    }

    func testRejectsAnImpossibleDay() throws {
        var backup = try Backup.make(from: try makeFamily(), calendar: london)
        backup.entries[0].day = "2026-13-45"
        XCTAssertThrowsError(try backup.restore(into: try makeContext(), calendar: london)) { error in
            XCTAssertEqual(error as? Backup.RestoreError, .badDay)
        }
    }

    func testSummaryDescribesTheBackup() throws {
        let backup = try Backup.make(from: try makeFamily(), calendar: london)
        XCTAssertEqual(backup.children.count, 3)
        XCTAssertEqual(backup.tickCount, backup.entries.filter { $0.status != .unset }.count)
    }
}
