import Foundation
import SwiftData
import SwiftUI

/// Live totals, the habit rows and the extra tasks for one child on one day. Tapping a habit
/// cycles its status; tapping an extra task marks it done or not.
struct DayBoardView: View {
    let child: Child
    let day: Date
    let navigation: DayNavigation

    @Environment(\.modelContext) private var context
    @Environment(ParentLock.self) private var parentLock
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query private var savedRules: [MonthRules]
    /// Every child's entries for the shown month; `DayBoard` narrows them down.
    @Query private var monthEntries: [DayEntry]
    /// Likewise every child's extra tasks for the month.
    @Query private var monthExtras: [ExtraTask]

    @State private var lastTap: HabitTap?
    @State private var saveFailed = false
    @State private var editor: ExtraTaskTarget?

    init(child: Child, day: Date, navigation: DayNavigation) {
        self.child = child
        self.day = day
        self.navigation = navigation
        let month = navigation.calendar.monthInterval(containing: day)
        let start = month.start
        let end = month.end
        _monthEntries = Query(filter: #Predicate<DayEntry> { $0.date >= start && $0.date < end })
        _monthExtras = Query(filter: #Predicate<ExtraTask> { $0.date >= start && $0.date < end })
    }

    var body: some View {
        let board = makeBoard()
        VStack(spacing: 12) {
            TotalsHeader(
                dayTitle: navigation.dayTitle(day), dayPence: board.dayPence,
                monthTitle: navigation.monthTitle(day), monthPence: board.monthPence
            )
            .padding(.bottom, 8)

            if navigation.isInEarlierMonth(day) {
                EarlierMonthBanner()
            }

            ForEach(board.rows) { row in
                HabitRowButton(habit: row.habit, status: row.status) { tap(row) }
            }
            if !board.extras.isEmpty {
                Text("Extra tasks")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                ForEach(board.extras) { task in
                    ExtraTaskRow(task: task) {
                        toggle(task)
                    } edit: {
                        unlockThen { editor = .change(task) }
                    } delete: {
                        unlockThen { remove(task) }
                    }
                }
            }
            Button("Add extra task", systemImage: "plus") {
                unlockThen { editor = .add }
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .habitTapFeedback(lastTap, saveFailed: $saveFailed)
        .sheet(item: $editor) { target in
            ExtraTaskEditor(task: target.task, child: child, day: day, rules: rules, calendar: navigation.calendar)
        }
    }

    private var rules: ScoringRules {
        MonthRules.rules(for: CalendarMonth(containing: day, calendar: navigation.calendar), from: savedRules)
    }

    private func makeBoard() -> DayBoard {
        DayBoard(child: child, day: day, habits: habits, entries: monthEntries, extraTasks: monthExtras, rules: rules, calendar: navigation.calendar)
    }

    /// Extra tasks are money, so setting, changing or removing one needs a parent.
    private func unlockThen(_ action: @escaping () -> Void) {
        Task {
            if await parentLock.authorize(reason: ParentLock.Reason.extraTask) { action() }
        }
    }

    private func toggle(_ task: ExtraTask) {
        parentLock.allowChange(to: day, navigation: navigation) {
            task.isDone.toggle()
            task.touch()
            do {
                try context.save()
                LocalChanges.post()
                lastTap = HabitTap(status: task.isDone ? .done : .unset)
            } catch {
                context.rollback()
                saveFailed = true
            }
        }
    }

    private func remove(_ task: ExtraTask) {
        let name = task.cloudRecordName
        context.delete(task)
        do {
            try context.save()
            LocalChanges.post(deleted: [name])
        } catch {
            context.rollback()
            saveFailed = true
        }
    }

    private func tap(_ row: DayBoard.Row) {
        let status = row.status.next
        parentLock.allowChange(to: day, navigation: navigation) {
            do {
                try context.saveStatus(status, child: child, habit: row.habit, day: day, calendar: navigation.calendar)
                lastTap = HabitTap(status: status)
            } catch {
                saveFailed = true
            }
        }
    }
}

/// Which extra task the editor is open for.
private enum ExtraTaskTarget: Identifiable {
    case add
    case change(ExtraTask)

    var id: String {
        switch self {
        case .add: "add"
        case .change(let task): task.id.uuidString
        }
    }

    var task: ExtraTask? {
        if case .change(let task) = self { task } else { nil }
    }
}
