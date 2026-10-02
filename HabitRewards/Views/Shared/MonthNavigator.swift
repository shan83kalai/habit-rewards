import SwiftUI

/// Arrows either side of the month name. The forward arrow stops at the current month.
struct MonthNavigator: View {
    @Binding var month: CalendarMonth
    let current: CalendarMonth

    var body: some View {
        HStack {
            NavigationArrow(symbol: "chevron.left", label: "Previous month") { month = month.previous }

            Text(month.firstDay(in: .current), format: .dateTime.month(.wide).year())
                .font(.title2.bold())
                .frame(maxWidth: .infinity)

            NavigationArrow(symbol: "chevron.right", label: "Next month") { month = month.next }
                .disabled(month >= current)
        }
        .sensoryFeedback(.selection, trigger: month)
    }
}

#Preview {
    @Previewable @State var month = DayNavigation(today: .now).currentMonth
    MonthNavigator(month: $month, current: DayNavigation(today: .now).currentMonth)
        .padding()
}
