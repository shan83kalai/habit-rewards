import Foundation
import SwiftData

/// One payment to a child for a month's earnings. A month can have several (a top-up after
/// late ticks), so the amount paid for a month is the sum of its payouts.
@Model
final class Payout: Syncable {
    var id: UUID = UUID()
    var child: Child?
    var year: Int = 0
    /// 1...12
    var month: Int = 0
    var amountPence: Int = 0
    var paidOn: Date?
    /// Kept alongside `child` so a payout synced before its child arrives can be linked later.
    var childID: UUID?

    // Sync bookkeeping: see `Syncable`.
    var modifiedAt: Date = Date.distantPast
    var syncedAt: Date = Date.distantPast
    var cloudSystemFields: Data?

    init(year: Int, month: Int, amountPence: Int, paidOn: Date? = nil) {
        self.year = year
        self.month = month
        self.amountPence = amountPence
        self.paidOn = paidOn
    }

    /// Records a payment. Inserts before linking the child so both ends share a context.
    @discardableResult
    static func record(_ amountPence: Int, to child: Child, for month: CalendarMonth, paidOn: Date = .now, in context: ModelContext) -> Payout {
        let payout = Payout(year: month.year, month: month.month, amountPence: amountPence, paidOn: paidOn)
        context.insert(payout)
        payout.child = child
        payout.childID = child.id
        payout.touch()
        return payout
    }

    var cloudRecordName: String { "payout-\(id.uuidString)" }

    /// The child's payments for that month, oldest first.
    static func payments(to child: Child, for month: CalendarMonth, from payouts: [Payout]) -> [Payout] {
        payouts
            .filter { $0.child?.id == child.id && $0.year == month.year && $0.month == month.month }
            .sorted { ($0.paidOn ?? .distantPast) < ($1.paidOn ?? .distantPast) }
    }
}
