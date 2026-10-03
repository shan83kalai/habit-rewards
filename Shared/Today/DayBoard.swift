import Foundation

/// Everything the Today screen shows for one child on one day: the habit rows, the extra tasks,
/// and the live totals.
struct DayBoard {
    struct Row: Identifiable {
        let habit: Habit
        let status: HabitStatus
        var id: UUID { habit.id }
    }

    let rows: [Row]
    /// The day's extra tasks, in the order they were set.
    let extras: [ExtraTask]
    let dayPence: Int
    let monthPence: Int

    /// - Parameters:
    ///   - entries: Any entries; only this child's entries in `day`'s month are used.
    ///   - extraTasks: Any tasks; likewise only this child's in `day`'s month.
    init(child: Child, day: Date, habits: [Habit], entries: [DayEntry], extraTasks: [ExtraTask] = [], rules: ScoringRules, calendar: Calendar = .current) {
        let engine = ScoringEngine(rules: rules)
        let monthEntries = entries.filter {
            $0.child?.id == child.id && calendar.isDate($0.date, equalTo: day, toGranularity: .month)
        }
        let dayEntries = monthEntries.filter { calendar.isDate($0.date, inSameDayAs: day) }

        var statusByHabit: [UUID: HabitStatus] = [:]
        for entry in dayEntries {
            if let habitID = entry.habit?.id {
                statusByHabit[habitID] = entry.status
            }
        }

        rows = habits
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { habit in
                let status = statusByHabit[habit.id] ?? .unset
                return habit.counts(for: child, withStatus: status) ? Row(habit: habit, status: status) : nil
            }
        let monthExtras = ExtraTask.tasks(for: child, in: extraTasks).filter {
            calendar.isDate($0.date, equalTo: day, toGranularity: .month)
        }
        extras = monthExtras.filter { calendar.isDate($0.date, inSameDayAs: day) }
        dayPence = engine.dayScore(dayEntries.map(\.status), extrasPence: extras.map(\.earnedPence).reduce(0, +))
        monthPence = engine.monthTotal(entries: monthEntries.map { (day: calendar.startOfDay(for: $0.date), status: $0.status) })
            + monthExtras.map(\.earnedPence).reduce(0, +)
    }
}
