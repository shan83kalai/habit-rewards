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
    /// The children it's for. Empty means every child, including ones added later.
    var childIDs: [UUID] = []

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

    /// Whether it's one of this child's habits: for everyone, or chosen for them.
    func isFor(_ child: Child) -> Bool {
        childIDs.isEmpty || childIDs.contains(child.id)
    }

    /// Whether the habit counts for a child on a day it has this status: always if it's active and
    /// one of theirs, otherwise only if it was ticked that day. Turning a habit off, or taking it
    /// away from a child, never changes their history.
    func counts(for child: Child, withStatus status: HabitStatus) -> Bool {
        (isActive && isFor(child)) || status != .unset
    }

    var cloudRecordName: String { "habit-\(id.uuidString)" }
}
