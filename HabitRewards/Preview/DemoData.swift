import Foundation
import SwiftData

/// A lived-in family for the App Store screenshots: two children, last month complete and one of
/// them paid, this month up to today, and a few extra tasks. Only loaded when UI tests launch the app with `-demoData`.
enum DemoData {
    static func load(into context: ModelContext, today: Date = .now, calendar: Calendar = .current) throws {
        try SeedData.seedIfNeeded(context)
        let children = try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
        let habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
        for (child, name) in zip(children, ["Maya", "Leo"]) {
            child.name = name
        }
        // One habit that's just Maya's, to show habits can be for some children only.
        if let maya = children.first, habits.count > 4 {
            habits[4].childIDs = [maya.id]
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
                let theirs = zip(habits, statuses).filter { $0.0.isFor(child) }
                for (habit, status) in theirs {
                    try DayEntry.upsert(child: child, habit: habit, date: day, status: status, in: context, calendar: calendar)
                }
                if CalendarMonth(containing: day, calendar: calendar) == lastMonth {
                    lastMonthTotal += engine.dayScore(theirs.map(\.1))
                }
            }
            // Today, half way through, with something still to do.
            let todays: [HabitStatus] = childIndex == 0
                ? [.done, .done, .missed, .done, .done, .unset]
                : [.done, .missed, .done, .unset, .done, .unset]
            for (habit, status) in zip(habits, todays) where status != .unset && habit.isFor(child) {
                try DayEntry.upsert(child: child, habit: habit, date: today, status: status, in: context, calendar: calendar)
            }
            if childIndex == 0 {
                _ = Payout.record(lastMonthTotal, to: child, for: lastMonth, in: context)
            }
        }

        // A few extra tasks: two of Leo's last month (still to be paid), and one each today.
        let september = lastMonth.days(in: calendar)
        for (title, pence, dayIndex) in [("Tidy the garden", 200, 11), ("Help with the shopping", 100, 19)] where children.count > 1 {
            ExtraTask.add(title, rewardPence: pence, for: children[1], on: september[dayIndex], calendar: calendar, in: context).isDone = true
        }
        if let maya = children.first {
            ExtraTask.add("Wash the car", rewardPence: 100, for: maya, on: today, calendar: calendar, in: context).isDone = true
        }
        if children.count > 1 {
            ExtraTask.add("Help make dinner", rewardPence: 100, for: children[1], on: today, calendar: calendar, in: context)
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
