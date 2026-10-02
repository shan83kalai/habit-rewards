import XCTest
@testable import HabitRewards

final class ScoringEngineTests: XCTestCase {
    private let engine = ScoringEngine()

    /// Builds one day's statuses, e.g. `day(done: 5, missed: 1)`.
    private func day(done: Int = 0, missed: Int = 0, unset: Int = 0) -> [HabitStatus] {
        Array(repeating: .done, count: done)
            + Array(repeating: .missed, count: missed)
            + Array(repeating: .unset, count: unset)
    }

    // MARK: - Defaults

    func testDefaultRulesAre50pRewardAnd75pPenalty() {
        XCTAssertEqual(ScoringRules.standard, ScoringRules(rewardPence: 50, penaltyPence: 75))
        XCTAssertEqual(engine.rules, .standard)
    }

    // MARK: - Day score (cases from the plan)

    func testSixDoneScores300p() {
        XCTAssertEqual(engine.dayScore(day(done: 6)), 300)
    }

    func testFiveDoneOneMissedScores175p() {
        XCTAssertEqual(engine.dayScore(day(done: 5, missed: 1)), 175)
    }

    func testTwoDoneFourMissedFloorsAtZero() {
        // 2 × 50 − 4 × 75 = −200, floored to 0.
        XCTAssertEqual(engine.dayScore(day(done: 2, missed: 4)), 0)
    }

    func testAllUnsetScoresZero() {
        XCTAssertEqual(engine.dayScore(day(unset: 6)), 0)
    }

    // MARK: - Day score (edge cases)

    func testNoEntriesScoresZero() {
        XCTAssertEqual(engine.dayScore([]), 0)
    }

    func testAllMissedFloorsAtZero() {
        XCTAssertEqual(engine.dayScore(day(missed: 6)), 0)
    }

    func testUnsetCountsAsNothing() {
        XCTAssertEqual(engine.dayScore(day(done: 3, unset: 3)), 150)
        XCTAssertEqual(engine.dayScore(day(done: 3, missed: 1, unset: 2)), 75)
    }

    func testBreakEvenScoresZero() {
        // 3 × 50 − 2 × 75 = 0 exactly.
        XCTAssertEqual(engine.dayScore(day(done: 3, missed: 2)), 0)
    }

    func testOrderOfStatusesDoesNotMatter() {
        let statuses: [HabitStatus] = [.missed, .done, .unset, .done, .done, .done]
        XCTAssertEqual(engine.dayScore(statuses), engine.dayScore(statuses.reversed()))
        XCTAssertEqual(engine.dayScore(statuses), 125)
    }

    func testCountsAndStatusesGiveSameScore() {
        XCTAssertEqual(engine.dayScore(done: 4, missed: 1), engine.dayScore(day(done: 4, missed: 1, unset: 1)))
    }

    func testEveryCombinationOfSixHabitsMatchesFormulaAndIsNeverNegative() {
        for done in 0...6 {
            for missed in 0...(6 - done) {
                let unset = 6 - done - missed
                let score = engine.dayScore(day(done: done, missed: missed, unset: unset))
                XCTAssertGreaterThanOrEqual(score, 0, "done \(done), missed \(missed)")
                XCTAssertEqual(score, max(0, done * 50 - missed * 75), "done \(done), missed \(missed)")
            }
        }
    }

    // MARK: - Month total

    func testMonthTotalSumsDayScores() {
        let month = [day(done: 6), day(done: 5, missed: 1), day(done: 2, missed: 4), day(unset: 6)]
        XCTAssertEqual(engine.monthTotal(month), 300 + 175 + 0 + 0)
    }

    func testMonthTotalFloorsEachDayBeforeSumming() {
        // A bad day can't eat into a good day's earnings: 300 + 0, not 300 − 450.
        let month = [day(done: 6), day(missed: 6)]
        XCTAssertEqual(engine.monthTotal(month), 300)
    }

    func testEmptyMonthIsZero() {
        XCTAssertEqual(engine.monthTotal([[HabitStatus]]()), 0)
    }

    func testMonthTotalFromDayScores() {
        XCTAssertEqual(engine.monthTotal(dayScores: [300, 175, 0, 250]), 725)
        XCTAssertEqual(engine.monthTotal(dayScores: []), 0)
    }

    func testThirtyOnePerfectDaysIs9300p() {
        let october = Array(repeating: day(done: 6), count: 31)
        XCTAssertEqual(engine.monthTotal(october), 9_300)
    }

    // MARK: - Month total from stored entries

    private let mixedEntries: [(day: Int, status: HabitStatus)] = [
        (1, .done), (1, .done), (1, .done), (1, .done), (1, .done), (1, .done), // 300
        (2, .done), (2, .missed), (2, .missed), (2, .missed),                   // 50 − 225 → 0
        (3, .done), (3, .done), (3, .missed), (3, .unset),                      // 25
    ]

    func testMonthTotalFromEntriesGroupsByDayAndFloorsEachDay() {
        XCTAssertEqual(engine.monthTotal(entries: mixedEntries), 325)
    }

    func testMonthTotalFromEntriesIgnoresOrder() {
        XCTAssertEqual(engine.monthTotal(entries: mixedEntries.reversed()), 325)
    }

    func testMonthTotalFromNoEntriesIsZero() {
        XCTAssertEqual(engine.monthTotal(entries: [(day: Int, status: HabitStatus)]()), 0)
    }

    // MARK: - Custom rules

    func testCustomRewardAndPenalty() {
        let custom = ScoringEngine(rules: ScoringRules(rewardPence: 100, penaltyPence: 25))
        XCTAssertEqual(custom.dayScore(day(done: 6)), 600)
        XCTAssertEqual(custom.dayScore(day(done: 5, missed: 1)), 475)
        XCTAssertEqual(custom.dayScore(day(done: 1, missed: 5)), 0) // 100 − 125, floored
        XCTAssertEqual(custom.dayScore(day(done: 2, missed: 4)), 100)
    }

    func testCustomRulesMonthTotal() {
        let custom = ScoringEngine(rules: ScoringRules(rewardPence: 40, penaltyPence: 60))
        let month = [day(done: 6), day(done: 4, missed: 2), day(done: 1, missed: 5)]
        // 240 + (160 − 120) + max(0, 40 − 300)
        XCTAssertEqual(custom.monthTotal(month), 240 + 40 + 0)
    }

    func testZeroPenaltyNeverSubtracts() {
        let custom = ScoringEngine(rules: ScoringRules(rewardPence: 50, penaltyPence: 0))
        XCTAssertEqual(custom.dayScore(day(done: 1, missed: 5)), 50)
    }

    func testSameStatusesScoreDifferentlyUnderDifferentRules() {
        let statuses = day(done: 5, missed: 1)
        let november = ScoringEngine(rules: ScoringRules(rewardPence: 50, penaltyPence: 100))
        XCTAssertEqual(engine.dayScore(statuses), 175)
        XCTAssertEqual(november.dayScore(statuses), 150)
    }
}
