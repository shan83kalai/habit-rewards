import Foundation
import SwiftData

/// A lived-in family for the App Store screenshots: two children, last month complete and one of
/// them paid, and this month up to today. Only loaded when UI tests launch the app with `-demoData`.
enum DemoData {
    static func load(into context: ModelContext, today: Date = .now, calendar: Calendar = .current) throws {
        try SeedData.seedIfNeeded(context)
        let children = try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
        let habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
        for (child, name) in zip(children, ["Maya", "Leo"]) {
            child.name = name
        }

        let thisMonth = CalendarMonth(containing: today, calendar: calendar)
        let lastMonth = thisMonth.previous
        let startOfToday = calendar.startOfDay(for: today)
        let days = (lastMonth.days(in: calendar) + thisMonth.days(in: calendar)).filter { $0 < startOfToday }
        let engine = ScoringEngine(rules: .standard)

        for (childIndex, child) in children.enumerated() {
            var lastMonthTotal = 0
            for (dayIndex, day) in days.enumerated() {
                let statuses = habits.indices.map { status(child: childIndex, day: dayIndex, habit: $0) }
                for (habit, status) in zip(habits, statuses) {
                    try DayEntry.upsert(child: child, habit: habit, date: day, status: status, in: context, calendar: calendar)
                }
                if CalendarMonth(containing: day, calendar: calendar) == lastMonth {
                    lastMonthTotal += engine.dayScore(statuses)
                }
            }
            // Today, half way through, with something still to do.
            let todays: [HabitStatus] = childIndex == 0
                ? [.done, .done, .missed, .done, .done, .unset]
                : [.done, .missed, .done, .unset, .done, .unset]
            for (habit, status) in zip(habits, todays) where status != .unset {
                try DayEntry.upsert(child: child, habit: habit, date: today, status: status, in: context, calendar: calendar)
            }
            if childIndex == 0 {
                _ = Payout.record(lastMonthTotal, to: child, for: lastMonth, in: context)
            }
        }
        try context.save()
    }

    /// Mostly done, the same every run. Maya misses one habit every sixth day; Leo a little more often.
    private static func status(child: Int, day: Int, habit: Int) -> HabitStatus {
        let missed = child == 0
            ? day % 6 == 2 && habit == (day / 6) % 6
            : (day % 4 == 1 && habit == (day / 4 + 2) % 6) || (day % 7 == 3 && habit == 5)
        return missed ? .missed : .done
    }
}
