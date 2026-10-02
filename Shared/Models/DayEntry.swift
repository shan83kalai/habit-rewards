import Foundation
import SwiftData

/// One habit's status for one child on one day.
@Model
final class DayEntry: Syncable {
    /// `childID|yyyy-MM-dd|habitID`. SwiftData on iOS 17 can't make a compound unique
    /// constraint, so this derived key carries the (child, date, habit) uniqueness.
    @Attribute(.unique) var key: String = ""
    var id: UUID = UUID()
    var child: Child?
    /// Always the start of the day in the calendar the entry was made with.
    var date: Date = Date.distantPast
    var habit: Habit?
    /// Stored as a raw string so it can be used in `#Predicate`s.
    var statusRaw: String = HabitStatus.unset.rawValue

    // Sync bookkeeping: see `Syncable`.
    var modifiedAt: Date = Date.distantPast
    var syncedAt: Date = Date.distantPast
    var cloudSystemFields: Data?

    var status: HabitStatus {
        get { HabitStatus(rawValue: statusRaw) ?? .unset }
        set { statusRaw = newValue.rawValue }
    }

    /// Use `upsert(...)` (or `fromSync` for records arriving from iCloud) so the uniqueness rule holds.
    private init(key: String, date: Date, status: HabitStatus) {
        self.key = key
        self.date = date
        self.statusRaw = status.rawValue
    }

    /// A new entry for a record that arrived from iCloud. The caller checks no entry has this key yet.
    static func fromSync(key: String, date: Date, status: HabitStatus) -> DayEntry {
        DayEntry(key: key, date: date, status: status)
    }

    var cloudRecordName: String {
        "entry_" + key.replacingOccurrences(of: "|", with: "_")
    }

    /// The child, day and habit inside `key`, used to link entries that arrive before their child or habit.
    nonisolated static func parts(ofKey key: String) -> (childID: UUID, day: String, habitID: UUID)? {
        let parts = key.split(separator: "|").map(String.init)
        guard parts.count == 3, let child = UUID(uuidString: parts[0]), let habit = UUID(uuidString: parts[2]) else { return nil }
        return (child, parts[1], habit)
    }

    static func key(childID: UUID, day: Date, habitID: UUID, calendar: Calendar) -> String {
        "\(childID.uuidString)|\(dayString(for: day, calendar: calendar))|\(habitID.uuidString)"
    }

    /// `"2026-10-02"`: the calendar day, with no time or time zone.
    nonisolated static func dayString(for day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The start of that day, or `nil` if it isn't a real date (e.g. "2026-02-30").
    nonisolated static func date(fromDayString string: String, calendar: Calendar) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let wanted = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        // Calendar quietly rolls "13th month" into next year, so check the date round-trips.
        guard let date = calendar.date(from: wanted),
              calendar.dateComponents([.year, .month, .day], from: date) == wanted
        else { return nil }
        return calendar.startOfDay(for: date)
    }

    /// Sets the status for (child, day, habit), updating the existing entry if there is one.
    @discardableResult
    static func upsert(
        child: Child,
        habit: Habit,
        date: Date,
        status: HabitStatus,
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> DayEntry {
        let day = calendar.startOfDay(for: date)
        let key = key(childID: child.id, day: day, habitID: habit.id, calendar: calendar)

        var descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.status = status
            existing.touch()
            return existing
        }

        let entry = DayEntry(key: key, date: day, status: status)
        // Insert before setting relationships so both ends live in the same context.
        context.insert(entry)
        entry.child = child
        entry.habit = habit
        entry.touch()
        return entry
    }
}

extension ModelContext {
    /// Sets a habit's status for a day and saves straight away, rolling back if the save fails.
    func saveStatus(_ status: HabitStatus, child: Child, habit: Habit, day: Date, calendar: Calendar) throws {
        do {
            try DayEntry.upsert(child: child, habit: habit, date: day, status: status, in: self, calendar: calendar)
            try save()
            LocalChanges.post()
        } catch {
            rollback()
            throw error
        }
    }
}
