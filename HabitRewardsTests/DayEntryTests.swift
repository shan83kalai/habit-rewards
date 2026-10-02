import SwiftData
import XCTest
@testable import HabitRewards

final class DayEntryTests: SwiftDataTestCase {
    private var london: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        london.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// A store with one child and two habits.
    private func makeStore() throws -> (context: ModelContext, child: Child, yoga: Habit, walk: Habit) {
        let context = try makeContext()
        let child = Child(name: "Test", colourHex: "#000000", sortOrder: 0)
        let yoga = Habit(title: "Yoga", sfSymbol: "figure.yoga", sortOrder: 0)
        let walk = Habit(title: "Walk", sfSymbol: "figure.walk", sortOrder: 1)
        context.insert(child)
        context.insert(yoga)
        context.insert(walk)
        return (context, child, yoga, walk)
    }

    func testDateIsNormalisedToStartOfDay() throws {
        let (context, child, yoga, _) = try makeStore()
        let entry = try DayEntry.upsert(
            child: child, habit: yoga, date: date(2026, 10, 2, hour: 19), status: .done,
            in: context, calendar: london
        )
        XCTAssertEqual(entry.date, date(2026, 10, 2, hour: 0))
    }

    func testSameChildDayAndHabitKeepsOneEntry() throws {
        let (context, child, yoga, _) = try makeStore()
        try DayEntry.upsert(child: child, habit: yoga, date: date(2026, 10, 2, hour: 8), status: .done, in: context, calendar: london)
        try DayEntry.upsert(child: child, habit: yoga, date: date(2026, 10, 2, hour: 21), status: .missed, in: context, calendar: london)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<DayEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.status, .missed)
    }

    func testDifferentHabitDayOrChildGetSeparateEntries() throws {
        let (context, child, yoga, walk) = try makeStore()
        let sibling = Child(name: "Sibling", colourHex: "#FFFFFF", sortOrder: 1)
        context.insert(sibling)

        try DayEntry.upsert(child: child, habit: yoga, date: date(2026, 10, 2), status: .done, in: context, calendar: london)
        try DayEntry.upsert(child: child, habit: walk, date: date(2026, 10, 2), status: .done, in: context, calendar: london)
        try DayEntry.upsert(child: child, habit: yoga, date: date(2026, 10, 3), status: .done, in: context, calendar: london)
        try DayEntry.upsert(child: sibling, habit: yoga, date: date(2026, 10, 2), status: .done, in: context, calendar: london)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DayEntry>()), 4)
    }

    func testRelationshipsAreSetBothWays() throws {
        let (context, child, yoga, _) = try makeStore()
        let entry = try DayEntry.upsert(child: child, habit: yoga, date: date(2026, 10, 2), status: .done, in: context, calendar: london)
        try context.save()

        XCTAssertTrue(entry.child === child)
        XCTAssertTrue(entry.habit === yoga)
        XCTAssertEqual(child.entries?.count, 1)
        XCTAssertEqual(yoga.entries?.count, 1)
    }

    func testUnknownStoredStatusReadsAsUnset() throws {
        let (context, child, yoga, _) = try makeStore()
        let entry = try DayEntry.upsert(child: child, habit: yoga, date: date(2026, 10, 2), status: .done, in: context, calendar: london)
        entry.statusRaw = "something-else"
        XCTAssertEqual(entry.status, .unset)
    }

    func testDeactivatingHabitKeepsItsHistory() throws {
        let (context, child, yoga, _) = try makeStore()
        try DayEntry.upsert(child: child, habit: yoga, date: date(2026, 10, 2), status: .done, in: context, calendar: london)
        yoga.isActive = false
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DayEntry>()), 1)
        XCTAssertEqual(yoga.entries?.first?.status, .done)
    }
}
