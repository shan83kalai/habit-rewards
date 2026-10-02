import SwiftData
import XCTest
@testable import HabitRewards

final class PayoutTests: SwiftDataTestCase {
    private let october = CalendarMonth(year: 2026, month: 10)
    private let paidOn = Date(timeIntervalSince1970: 1_793_000_000)

    func testRecordingAPayoutLinksItToTheChildAndMonth() throws {
        let context = try makeContext()
        try SeedData.seedIfNeeded(context)
        let child = try XCTUnwrap(context.fetch(FetchDescriptor<Child>()).first)

        let payout = Payout.record(1_250, to: child, for: october, paidOn: paidOn, in: context)
        try context.save()

        XCTAssertTrue(payout.child === child)
        XCTAssertEqual(payout.year, 2026)
        XCTAssertEqual(payout.month, 10)
        XCTAssertEqual(payout.amountPence, 1_250)
        XCTAssertEqual(payout.paidOn, paidOn)
        XCTAssertEqual(child.payouts?.count, 1)
    }

    func testPaymentsAreFilteredByChildAndMonth() throws {
        let context = try makeContext()
        try SeedData.seedIfNeeded(context)
        let children = try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
        let (firstChild, secondChild) = (children[0], children[1])

        Payout.record(1_250, to: firstChild, for: october, paidOn: paidOn, in: context)
        Payout.record(100, to: firstChild, for: october, paidOn: paidOn.addingTimeInterval(60), in: context)
        Payout.record(900, to: secondChild, for: october, paidOn: paidOn, in: context)
        Payout.record(800, to: firstChild, for: october.previous, paidOn: paidOn, in: context)
        try context.save()

        let all = try context.fetch(FetchDescriptor<Payout>())
        let firstChildOctober = Payout.payments(to: firstChild, for: october, from: all)
        XCTAssertEqual(firstChildOctober.map(\.amountPence), [1_250, 100]) // oldest first
        XCTAssertEqual(Payout.payments(to: secondChild, for: october, from: all).map(\.amountPence), [900])
    }
}
