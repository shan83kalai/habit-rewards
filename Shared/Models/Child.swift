import Foundation
import SwiftData

@Model
final class Child: Syncable {
    var id: UUID = UUID()
    var name: String = ""
    var colourHex: String = "#4F8EF7"
    var sortOrder: Int = 0
    /// Archived children are hidden from day-to-day screens but keep their history.
    var isArchived: Bool = false

    // Sync bookkeeping: see `Syncable`.
    var modifiedAt: Date = Date.distantPast
    var syncedAt: Date = Date.distantPast
    var cloudSystemFields: Data?

    @Relationship(deleteRule: .cascade, inverse: \DayEntry.child)
    var entries: [DayEntry]? = []

    @Relationship(deleteRule: .cascade, inverse: \Payout.child)
    var payouts: [Payout]? = []

    init(name: String, colourHex: String, sortOrder: Int) {
        self.name = name
        self.colourHex = colourHex
        self.sortOrder = sortOrder
    }

    var cloudRecordName: String { "child-\(id.uuidString)" }
}
