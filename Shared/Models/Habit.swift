import Foundation
import SwiftData

@Model
final class Habit: Syncable {
    var id: UUID = UUID()
    var title: String = ""
    var sfSymbol: String = "checkmark.circle"
    var sortOrder: Int = 0
    /// Inactive habits are hidden from new days but keep their history.
    var isActive: Bool = true

    // Sync bookkeeping: see `Syncable`.
    var modifiedAt: Date = Date.distantPast
    var syncedAt: Date = Date.distantPast
    var cloudSystemFields: Data?

    @Relationship(deleteRule: .cascade, inverse: \DayEntry.habit)
    var entries: [DayEntry]? = []

    init(title: String, sfSymbol: String, sortOrder: Int) {
        self.title = title
        self.sfSymbol = sfSymbol
        self.sortOrder = sortOrder
    }

    /// Whether the habit counts on a day it has this status: always if active, otherwise
    /// only if it was ticked that day, so its history still shows and adds up.
    func counts(withStatus status: HabitStatus) -> Bool {
        isActive || status != .unset
    }

    var cloudRecordName: String { "habit-\(id.uuidString)" }
}
