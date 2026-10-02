import Foundation

/// Everything the Today screen shows for one child on one day: the habit rows and the live totals.
struct DayBoard {
    struct Row: Identifiable {
        let habit: Habit
        let status: HabitStatus
        var id: UUID { habit.id }
    }

    let rows: [Row]
    let dayPence: Int
    let monthPence: Int

    /// - Parameter entries: Any entries; only this child's entries in `day`'s month are used.
    init(child: Child, day: Date, habits: [Habit], entries: [DayEntry], rules: ScoringRules, calendar: Calendar = .current) {
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
                return habit.counts(withStatus: status) ? Row(habit: habit, status: status) : nil
            }
        dayPence = engine.dayScore(dayEntries.map(\.status))
        monthPence = engine.monthTotal(entries: monthEntries.map { (day: calendar.startOfDay(for: $0.date), status: $0.status) })
    }
}
