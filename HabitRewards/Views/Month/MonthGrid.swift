import SwiftData
import SwiftUI

/// Habits as rows and days as columns, with day-score and running-total rows underneath.
/// The habit names stay put while the days scroll sideways, like a frozen spreadsheet column.
struct MonthGrid: View {
    let sheet: MonthSheet
    let tap: (MonthSheet.Row, Int) -> Void

    /// Grow with the text size (capped by the caller), so ticks and amounts stay readable.
    @ScaledMetric(relativeTo: .caption) private var cellSize: CGFloat = 44
    @ScaledMetric(relativeTo: .caption) private var labelWidth: CGFloat = 132

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            labelColumn
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(sheet.days.indices, id: \.self) { index in
                            dayColumn(index).id(index)
                        }
                    }
                }
                .onAppear { scrollToToday(proxy) }
                .onChange(of: sheet.month) { scrollToToday(proxy) }
            }
        }
        .background(.gray.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var labelColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            label("")
            ForEach(sheet.rows) { row in
                HStack(spacing: 8) {
                    Image(systemName: row.habit.sfSymbol)
                        .foregroundStyle(.tint)
                        .frame(width: 20)
                    Text(row.habit.title)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .font(.caption)
                .frame(width: labelWidth, height: cellSize, alignment: .leading)
            }
            label(String(localized: "Day")).bold()
            label(String(localized: "Running"))
        }
        .padding(.leading, 12)
        .accessibilityHidden(true)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .frame(width: labelWidth, height: cellSize, alignment: .leading)
    }

    private func dayColumn(_ index: Int) -> some View {
        let day = sheet.days[index]
        let isLocked = sheet.isLocked(dayIndex: index)
        return VStack(spacing: 0) {
            DayHeaderCell(day: day, isToday: index == sheet.todayIndex, size: cellSize)
            ForEach(sheet.rows) { row in
                MonthGridCell(habit: row.habit, day: day, status: row.statuses[index], isLocked: isLocked, size: cellSize) {
                    tap(row, index)
                }
            }
            MoneyCell(pence: sheet.dayScores[index], label: String(localized: "Day score"), size: cellSize).bold()
            MoneyCell(pence: sheet.runningTotals[index], label: String(localized: "Running total"), size: cellSize)
                .foregroundStyle(.subtle)
        }
        .background(index == sheet.todayIndex ? AnyShapeStyle(.tint.opacity(0.08)) : AnyShapeStyle(.clear))
    }

    private func scrollToToday(_ proxy: ScrollViewProxy) {
        proxy.scrollTo(sheet.todayIndex ?? 0, anchor: sheet.todayIndex == nil ? .leading : .center)
    }
}

private struct DayHeaderCell: View {
    let day: Date
    let isToday: Bool
    let size: CGFloat

    var body: some View {
        VStack(spacing: 1) {
            Text(day, format: .dateTime.weekday(.narrow))
                .font(.caption2)
                .foregroundStyle(.subtle)
            Text(day, format: .dateTime.day())
                .font(.caption.weight(.semibold))
                .foregroundStyle(isToday ? .white : .primary)
                .frame(width: size * 0.55, height: size * 0.55)
                .background {
                    if isToday { Circle().fill(.tint) }
                }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct MonthGridCell: View {
    let habit: Habit
    let day: Date
    let status: HabitStatus
    let isLocked: Bool
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if status != .unset { status.rowBackground }
                if let symbol = status.gridSymbol {
                    Image(systemName: symbol)
                        .font(.body.weight(.bold))
                        .foregroundStyle(status.colour)
                }
            }
            .frame(width: size, height: size)
            .overlay { Rectangle().strokeBorder(.gray.opacity(0.2), lineWidth: 0.5) }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked ? 0.35 : 1)
        .accessibilityLabel("\(habit.title), \(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
        .accessibilityValue(isLocked ? String(localized: "Future day") : status.accessibilityName)
        .accessibilityHint(isLocked ? "" : status.tapHint)
    }
}

private struct MoneyCell: View {
    let pence: Int?
    let label: String
    let size: CGFloat

    var body: some View {
        Text(pence.map { Money.format($0) } ?? "")
            .font(.caption2)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: size, height: size)
            .overlay { Rectangle().strokeBorder(.gray.opacity(0.2), lineWidth: 0.5) }
            .accessibilityLabel(label)
            .accessibilityValue(pence.map { Money.format($0) } ?? String(localized: "None yet"))
    }
}
