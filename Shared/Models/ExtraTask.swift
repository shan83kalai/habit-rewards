import Foundation
import SwiftData

/// A one-off task for one child on one day, with its own reward: "Wash the car, £1". Done adds
/// the reward to that day, on top of the habits; not done costs nothing.
@Model
final class ExtraTask: Syncable {
    var id: UUID = UUID()
    var child: Child?
    /// Kept alongside `child` so a task synced before its child arrives can be linked later.
    var childID: UUID?
    var title: String = ""
    /// Fixed when the task is set, so changing the month's reward never changes it.
    var rewardPence: Int = 0
    /// "2026-10-03", as in `DayEntry` keys, so the day survives a change of time zone.
    var day: String = ""
    /// The start of `day`, for fetching a month's tasks.
    var date: Date = Date.distantPast
    var isDone: Bool = false
    /// Keeps a day's tasks in the order they were set.
    var createdAt: Date = Date.distantPast

    // Sync bookkeeping: see `Syncable`.
    var modifiedAt: Date = Date.distantPast
    var syncedAt: Date = Date.distantPast
    var cloudSystemFields: Data?

    init(title: String, rewardPence: Int) {
        self.title = title
        self.rewardPence = rewardPence
    }

    /// Sets a task for a child on a day. Inserts before linking the child so both ends share a context.
    @discardableResult
    static func add(_ title: String, rewardPence: Int, for child: Child, on day: Date, calendar: Calendar = .current, in context: ModelContext) -> ExtraTask {
        let task = ExtraTask(title: title, rewardPence: rewardPence)
        task.day = DayEntry.dayString(for: day, calendar: calendar)
        task.date = calendar.startOfDay(for: day)
        task.createdAt = .now
        context.insert(task)
        task.child = child
        task.childID = child.id
        task.touch()
        return task
    }

    var cloudRecordName: String { "extra-\(id.uuidString)" }

    /// The reward this task adds to its day: all of it once done, nothing otherwise.
    var earnedPence: Int {
        isDone ? rewardPence : 0
    }

    /// A child's tasks among `tasks`, in the order they were set.
    static func tasks(for child: Child, in tasks: [ExtraTask]) -> [ExtraTask] {
        tasks
            .filter { ($0.child?.id ?? $0.childID) == child.id }
            .sorted { ($0.date, $0.createdAt) < ($1.date, $1.createdAt) }
    }
}
