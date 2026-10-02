import SwiftData
import XCTest
@testable import HabitRewards

final class SeedDataTests: SwiftDataTestCase {
    func testSeedsTwoChildrenInOrder() throws {
        let context = try makeContext()
        try SeedData.seedIfNeeded(context)

        let children = try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertEqual(children.map(\.name), ["Child 1", "Child 2"])
        XCTAssertFalse(children.contains(where: \.isArchived))
    }

    func testSeedsSixActiveHabitsInOrder() throws {
        let context = try makeContext()
        try SeedData.seedIfNeeded(context)

        let habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertEqual(habits.map(\.title), [
            "Homework",
            "Reading",
            "Brush teeth",
            "Bed on time",
            "Tidy room",
            "Exercise",
        ])
        XCTAssertTrue(habits.allSatisfy(\.isActive))
    }

    func testSeedingTwiceDoesNotDuplicate() throws {
        let context = try makeContext()
        try SeedData.seedIfNeeded(context)
        try SeedData.seedIfNeeded(context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Child>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Habit>()), 6)
    }

    func testBestDayWithSeededHabitsIs300p() throws {
        let context = try makeContext()
        try SeedData.seedIfNeeded(context)

        let habitCount = try context.fetchCount(FetchDescriptor<Habit>())
        XCTAssertEqual(ScoringEngine().dayScore(done: habitCount, missed: 0), 300)
    }
}
