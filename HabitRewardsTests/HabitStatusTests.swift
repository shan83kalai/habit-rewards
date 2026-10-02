import XCTest
@testable import HabitRewards

final class HabitStatusTests: XCTestCase {
    func testTapCycleIsDoneThenMissedThenClear() {
        XCTAssertEqual(HabitStatus.unset.next, .done)
        XCTAssertEqual(HabitStatus.done.next, .missed)
        XCTAssertEqual(HabitStatus.missed.next, .unset)
    }

    func testThreeTapsReturnToWhereYouStarted() {
        for status in HabitStatus.allCases {
            XCTAssertEqual(status.next.next.next, status)
        }
    }
}
