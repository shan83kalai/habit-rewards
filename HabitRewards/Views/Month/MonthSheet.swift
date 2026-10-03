import Foundation

/// One child's month as a spreadsheet (habits × days) plus the summary numbers, for the
/// month grid and the summary screen.
struct MonthSheet {
    struct Row: Identifiable {
        let habit: Habit
        /// One status per day of the month.
        let statuses: [HabitStatus]
        var id: UUID { habit.id }
    }

    let month: CalendarMonth
    let days: [Date]
    let rows: [Row]
    /// What each day's done extra tasks add; 0 for days without any.
    let extrasByDay: [Int]
    /// The child's extra tasks this month, by day and then the order they were set.
    let extraTasks: [ExtraTask]
    /// `nil` for days after today.
    let dayScores: [Int?]
    let runningTotals: [Int?]
    let total: Int
    let perfectDays: Int
    let bestStreak: Int
    let mostDoneHabit: Habit?
    let mostMissedHabit: Habit?
    /// Where today is in `days`, if it's this month.
    let todayIndex: Int?

    /// - Parameters:
    ///   - entries: Any entries; only this child's entries in `month` are used.
    ///   - extraTasks: Any tasks; likewise only this child's in `month`.
    init(child: Child, month: CalendarMonth, today: Date, habits: [Habit], entries: [DayEntry], extraTasks: [ExtraTask] = [], rules: ScoringRules, calendar: Calendar = .current) {
        let engine = ScoringEngine(rules: rules)
        let days = month.days(in: calendar)
        let startOfToday = calendar.startOfDay(for: today)
        let dayIndex = Dictionary(uniqueKeysWithValues: days.enumerated().map { ($1, $0) })
        let blank = Array(repeating: HabitStatus.unset, count: days.count)

        var statusesByHabit: [UUID: [HabitStatus]] = [:]
        for entry in entries where entry.child?.id == child.id {
            guard let habitID = entry.habit?.id, let index = dayIndex[calendar.startOfDay(for: entry.date)] else { continue }
            statusesByHabit[habitID, default: blank][index] = entry.status
        }

        let rows = habits
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { habit -> Row? in
                // Habits that are off, or not this child's, get a row only in months they were ticked.
                let statuses = statusesByHabit[habit.id] ?? blank
                let usedThisMonth = statuses.contains { $0 != .unset }
                return (habit.isActive && habit.isFor(child)) || usedThisMonth ? Row(habit: habit, statuses: statuses) : nil
            }

        let tasks = ExtraTask.tasks(for: child, in: extraTasks).filter { dayIndex[calendar.startOfDay(for: $0.date)] != nil }
        var extrasByDay = Array(repeating: 0, count: days.count)
        for task in tasks {
            if let index = dayIndex[calendar.startOfDay(for: task.date)] {
                extrasByDay[index] += task.earnedPence
            }
        }

        // Score each day up to today; later days stay nil (locked).
        var dayScores = [Int?](repeating: nil, count: days.count)
        var runningTotals = [Int?](repeating: nil, count: days.count)
        var perfect: [Bool] = []
        var runningTotal = 0
        for index in days.indices where days[index] <= startOfToday {
            let score = engine.dayScore(rows.map { $0.statuses[index] }, extrasPence: extrasByDay[index])
            runningTotal += score
            dayScores[index] = score
            runningTotals[index] = runningTotal

            let counted = rows.filter { $0.habit.counts(for: child, withStatus: $0.statuses[index]) }
            perfect.append(MonthStats.isPerfectDay(counted.map { $0.statuses[index] }))
        }

        let tallies = rows.map { HabitTally(id: $0.habit.id, statuses: $0.statuses) }
        let habitsByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.habit.id, $0.habit) })

        self.month = month
        self.days = days
        self.rows = rows
        self.extrasByDay = extrasByDay
        self.extraTasks = tasks
        self.dayScores = dayScores
        self.runningTotals = runningTotals
        self.total = runningTotal
        self.perfectDays = perfect.filter { $0 }.count
        self.bestStreak = MonthStats.longestStreak(perfect)
        self.mostDoneHabit = MonthStats.mostDone(tallies).flatMap { habitsByID[$0] }
        self.mostMissedHabit = MonthStats.mostMissed(tallies).flatMap { habitsByID[$0] }
        self.todayIndex = dayIndex[startOfToday]
    }

    /// What the month's done extra tasks added, and how many there were.
    var extrasTotal: Int { extraTasks.map(\.earnedPence).reduce(0, +) }
    var extrasDone: Int { extraTasks.filter(\.isDone).count }

    /// Days after today can't be ticked.
    func isLocked(dayIndex: Int) -> Bool {
        dayScores[dayIndex] == nil
    }

    /// How many days this month the habit had that status.
    func count(_ status: HabitStatus, for habit: Habit) -> Int {
        rows.first { $0.habit.id == habit.id }?.statuses.filter { $0 == status }.count ?? 0
    }
}
