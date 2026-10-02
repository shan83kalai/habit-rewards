import XCTest
@testable import HabitRewards

final class MonthStatsTests: XCTestCase {
    // MARK: - Perfect days

    func testPerfectDayNeedsEveryHabitDone() {
        XCTAssertTrue(MonthStats.isPerfectDay(Array(repeating: HabitStatus.done, count: 6)))
        XCTAssertFalse(MonthStats.isPerfectDay([.done, .done, .done, .done, .done, .missed]))
        XCTAssertFalse(MonthStats.isPerfectDay([.done, .done, .done, .done, .done, .unset]))
    }

    func testDayWithNoHabitsIsNotPerfect() {
        XCTAssertFalse(MonthStats.isPerfectDay([HabitStatus]()))
    }

    // MARK: - Streaks

    func testLongestStreakFindsTheLongestRun() {
        XCTAssertEqual(MonthStats.longestStreak([true, true, false, true, true, true, false, true]), 3)
    }

    func testLongestStreakEdgeCases() {
        XCTAssertEqual(MonthStats.longestStreak([]), 0)
        XCTAssertEqual(MonthStats.longestStreak([false, false]), 0)
        XCTAssertEqual(MonthStats.longestStreak([true, true, true]), 3)
        XCTAssertEqual(MonthStats.longestStreak([false, true, true]), 2)
    }

    // MARK: - Best and most-missed habit

    private let tallies = [
        HabitTally(id: "maths", statuses: [.done, .done, .missed]),
        HabitTally(id: "yoga", statuses: [.done, .done, .done]),
        HabitTally(id: "teeth", statuses: [.missed, .missed, .unset]),
        HabitTally(id: "walk", statuses: [.done, .done, .done]),
    ]

    func testTallyCountsDoneAndMissed() {
        XCTAssertEqual(tallies[0].done, 2)
        XCTAssertEqual(tallies[0].missed, 1)
        XCTAssertEqual(tallies[2].done, 0)
        XCTAssertEqual(tallies[2].missed, 2)
    }

    func testMostDoneHabitBreaksTiesByHabitOrder() {
        // Yoga and walk are both done 3 times; yoga comes first.
        XCTAssertEqual(MonthStats.mostDone(tallies), "yoga")
    }

    func testMostMissedHabit() {
        XCTAssertEqual(MonthStats.mostMissed(tallies), "teeth")
    }

    func testNoBestOrMostMissedWhenNothingHappened() {
        let empty = [HabitTally(id: "maths", statuses: [.unset, .unset]), HabitTally(id: "yoga", statuses: [])]
        XCTAssertNil(MonthStats.mostDone(empty))
        XCTAssertNil(MonthStats.mostMissed(empty))
    }

    func testNothingMissedMeansNoMostMissedHabit() {
        let allDone = [HabitTally(id: "maths", statuses: [.done]), HabitTally(id: "yoga", statuses: [.done, .unset])]
        XCTAssertNil(MonthStats.mostMissed(allDone))
        XCTAssertEqual(MonthStats.mostDone(allDone), "maths")
    }
}
