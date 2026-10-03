import Foundation
import SwiftData
import WidgetKit

/// What the home-screen widget shows: each child's total for today and this month.
nonisolated struct WidgetSummary: Sendable, Equatable {
    struct ChildLine: Sendable, Equatable, Identifiable {
        let id: UUID
        let name: String
        let colourHex: String
        let todayPence: Int
        let monthPence: Int
        let done: Int
        let habitCount: Int
    }

    let children: [ChildLine]

    /// For the widget gallery and placeholders.
    static let sample = WidgetSummary(children: [
        ChildLine(id: UUID(), name: "Child 1", colourHex: "#7B61FF", todayPence: 250, monthPence: 1_175, done: 5, habitCount: 6),
        ChildLine(id: UUID(), name: "Child 2", colourHex: "#FF8A3D", todayPence: 175, monthPence: 950, done: 4, habitCount: 6),
    ])
}

extension WidgetSummary {
    /// Built with the same `DayBoard` as the Today screen, so the numbers always agree.
    init(context: ModelContext, now: Date, calendar: Calendar = .current) throws {
        let month = calendar.monthInterval(containing: now)
        let start = month.start
        let end = month.end
        let children = try context.fetch(FetchDescriptor<Child>(predicate: #Predicate { !$0.isArchived }, sortBy: [SortDescriptor(\.sortOrder)]))
        let habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
        let entries = try context.fetch(FetchDescriptor<DayEntry>(predicate: #Predicate { $0.date >= start && $0.date < end }))
        let extras = try context.fetch(FetchDescriptor<ExtraTask>(predicate: #Predicate { $0.date >= start && $0.date < end }))
        let rules = MonthRules.rules(for: CalendarMonth(containing: now, calendar: calendar), from: try context.fetch(FetchDescriptor<MonthRules>()))

        self.init(children: children.map { child in
            let board = DayBoard(child: child, day: now, habits: habits, entries: entries, extraTasks: extras, rules: rules, calendar: calendar)
            return ChildLine(
                id: child.id, name: child.name, colourHex: child.colourHex,
                todayPence: board.dayPence, monthPence: board.monthPence,
                done: board.rows.filter { $0.status == .done }.count, habitCount: board.rows.count
            )
        })
    }

    /// Reads the shared store without writing to it. Empty if the store can't be opened yet.
    static func load(now: Date = .now) -> WidgetSummary {
        guard let container = try? AppSchema.makeContainer(readOnly: true),
              let summary = try? WidgetSummary(context: ModelContext(container), now: now)
        else { return WidgetSummary(children: []) }
        return summary
    }
}

nonisolated struct TodayEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary
}

extension WidgetCenter {
    static let todayKind = "TodayWidget"
}
