import SwiftData
import XCTest
@testable import HabitRewards

/// Which children a habit is for: the counting rule, the editor's ticks, and what Settings shows.
final class HabitAudienceTests: SwiftDataTestCase {
    private var children: [Child] = []
    private var habits: [Habit] = []

    private func seed() throws {
        let context = try makeContext()
        try SeedData.seedIfNeeded(context)
        children = try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
        habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    // MARK: - Counting

    func testAHabitForEveryoneCountsForEveryChild() throws {
        try seed()
        XCTAssertTrue(habits[0].isFor(children[0]))
        XCTAssertTrue(habits[0].counts(for: children[1], withStatus: .unset))
    }

    func testAHabitForOneChildCountsForOthersOnlyWhereTicked() throws {
        try seed()
        let habit = habits[0]
        habit.childIDs = [children[1].id]

        XCTAssertFalse(habit.isFor(children[0]))
        XCTAssertFalse(habit.counts(for: children[0], withStatus: .unset))
        XCTAssertTrue(habit.counts(for: children[0], withStatus: .done))
        XCTAssertTrue(habit.counts(for: children[1], withStatus: .unset))
    }

    // MARK: - Editing

    func testUntickingAChildFromAnEveryoneHabit() throws {
        try seed()
        let ids = children.map(\.id)
        var audience = HabitAudience(childIDs: [])
        XCTAssertTrue(audience.includes(ids[0]))

        audience.toggle(ids[0], among: ids)
        XCTAssertFalse(audience.includes(ids[0]))
        XCTAssertTrue(audience.includes(ids[1]))
        XCTAssertEqual(audience.childIDs(among: ids), [ids[1]])
    }

    func testTickingEveryChildMakesItEveryonesAgain() throws {
        try seed()
        let ids = children.map(\.id)
        var audience = HabitAudience(childIDs: [ids[1]])
        audience.toggle(ids[0], among: ids)
        XCTAssertTrue(audience.isEveryone)
        XCTAssertEqual(audience.childIDs(among: ids), [])
    }

    func testAHabitMustBeForSomeone() throws {
        try seed()
        let ids = children.map(\.id)
        var audience = HabitAudience(childIDs: [ids[1]])
        audience.toggle(ids[1], among: ids)
        XCTAssertFalse(audience.isForAnyone(among: ids))
    }

    func testArchivedChildrenItWasForAreKept() throws {
        try seed()
        let archived = UUID()
        let ids = children.map(\.id)
        var audience = HabitAudience(childIDs: [ids[0], archived])
        audience.toggle(ids[1], among: ids)
        audience.toggle(ids[0], among: ids)
        XCTAssertEqual(Set(audience.childIDs(among: ids)), [ids[1], archived])
    }

    // MARK: - Captions

    func testCaptions() throws {
        try seed()
        let habit = habits[0]
        XCTAssertNil(HabitAudience.caption(for: habit, children: children))
        habit.childIDs = [children[1].id]
        XCTAssertEqual(HabitAudience.caption(for: habit, children: children), "Child 2 only")
        habit.childIDs = [UUID()]
        XCTAssertEqual(HabitAudience.caption(for: habit, children: children), "Only archived children")
    }

    // MARK: - Best day

    func testBestDayIsTheSameForEveryoneWhenTheirHabitsMatch() throws {
        try seed()
        let summary = BestDay.summary(rules: .standard, activeHabits: habits, children: children)
        XCTAssertTrue(summary.hasPrefix("Best day: "))
        XCTAssertTrue(summary.contains(Money.format(300)))
        XCTAssertFalse(summary.contains("Child"))
    }

    func testBestDayNamesEachChildWhenTheirHabitsDiffer() throws {
        try seed()
        habits[5].childIDs = [children[0].id]
        habits[4].childIDs = [children[0].id]
        let summary = BestDay.summary(rules: .standard, activeHabits: habits, children: children)
        XCTAssertTrue(summary.contains("Child 1 \(Money.format(300))"))
        XCTAssertTrue(summary.contains("Child 2 \(Money.format(200))"))
    }
}
