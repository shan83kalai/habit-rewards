import XCTest
@testable import HabitRewards

final class PayoutStatusTests: XCTestCase {
    func testNothingPaidYet() {
        let status = PayoutStatus(earnedPence: 1_250, payments: [])
        XCTAssertEqual(status.paidPence, 0)
        XCTAssertEqual(status.outstandingPence, 1_250)
        XCTAssertEqual(status.overpaidPence, 0)
        XCTAssertFalse(status.isSettled)
    }

    func testPaidInFull() {
        let status = PayoutStatus(earnedPence: 1_250, payments: [1_250])
        XCTAssertEqual(status.outstandingPence, 0)
        XCTAssertTrue(status.isSettled)
    }

    func testTopUpAfterLateTicks() {
        // £12.50 paid, then two more habits were ticked for that month.
        let status = PayoutStatus(earnedPence: 1_350, payments: [1_250])
        XCTAssertEqual(status.outstandingPence, 100)
        XCTAssertFalse(status.isSettled)

        let toppedUp = PayoutStatus(earnedPence: 1_350, payments: [1_250, 100])
        XCTAssertEqual(toppedUp.paidPence, 1_350)
        XCTAssertTrue(toppedUp.isSettled)
    }

    func testOverpaidWhenTicksAreRemovedAfterPaying() {
        let status = PayoutStatus(earnedPence: 1_175, payments: [1_250])
        XCTAssertEqual(status.outstandingPence, 0)
        XCTAssertEqual(status.overpaidPence, 75)
        XCTAssertTrue(status.isSettled)
    }

    func testNothingEarnedIsAlreadySettled() {
        let status = PayoutStatus(earnedPence: 0, payments: [])
        XCTAssertEqual(status.outstandingPence, 0)
        XCTAssertTrue(status.isSettled)
    }
}
