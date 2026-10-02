import XCTest
@testable import HabitRewards

@MainActor
final class ParentLockTests: XCTestCase {
    /// Counts how often Face ID / passcode would have been shown.
    private final class FakeCheck {
        var answer: Bool
        var calls = 0
        init(answer: Bool) { self.answer = answer }
    }

    private func makeLock(_ check: FakeCheck) -> ParentLock {
        ParentLock { _ in
            check.calls += 1
            await Task.yield()
            return check.answer
        }
    }

    func testStartsLocked() {
        XCTAssertFalse(makeLock(FakeCheck(answer: true)).isUnlocked)
    }

    func testSuccessfulCheckUnlocks() async {
        let lock = makeLock(FakeCheck(answer: true))
        let allowed = await lock.authorize(reason: "test")
        XCTAssertTrue(allowed)
        XCTAssertTrue(lock.isUnlocked)
    }

    func testFailedCheckStaysLocked() async {
        let lock = makeLock(FakeCheck(answer: false))
        let allowed = await lock.authorize(reason: "test")
        XCTAssertFalse(allowed)
        XCTAssertFalse(lock.isUnlocked)
    }

    func testDoesNotAskAgainOnceUnlocked() async {
        let check = FakeCheck(answer: true)
        let lock = makeLock(check)
        _ = await lock.authorize(reason: "test")
        _ = await lock.authorize(reason: "test")
        XCTAssertEqual(check.calls, 1)
    }

    func testLockingMeansAskingAgain() async {
        let check = FakeCheck(answer: true)
        let lock = makeLock(check)
        _ = await lock.authorize(reason: "test")
        lock.lock()
        XCTAssertFalse(lock.isUnlocked)

        _ = await lock.authorize(reason: "test")
        XCTAssertEqual(check.calls, 2)
    }

    func testTwoQuickTapsShareOneCheck() async {
        let check = FakeCheck(answer: true)
        let lock = makeLock(check)
        async let first = lock.authorize(reason: "test")
        async let second = lock.authorize(reason: "test")
        let results = await [first, second]

        XCTAssertEqual(results, [true, true])
        XCTAssertEqual(check.calls, 1)
    }
}
