import Foundation
import SwiftUI

/// Arrows either side of the date. The forward arrow stops at today.
struct DayNavigator: View {
    @Binding var day: Date
    let navigation: DayNavigation

    var body: some View {
        HStack {
            NavigationArrow(symbol: "chevron.left", label: "Previous day") { day = navigation.previous(day) }

            VStack(spacing: 2) {
                Text(navigation.dayTitle(day))
                    .font(.title2.bold())
                Text(day, format: .dateTime.day().month(.wide).year())
                    .font(.subheadline)
                    .foregroundStyle(.subtle)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)

            NavigationArrow(symbol: "chevron.right", label: "Next day") { day = navigation.next(day) }
                .disabled(!navigation.canGoForward(from: day))
        }
        .sensoryFeedback(.selection, trigger: day)
    }
}

extension DayNavigation {
    /// "Today", "Yesterday", or the weekday name.
    func dayTitle(_ day: Date) -> String {
        switch relative(day) {
        case .today: String(localized: "Today")
        case .yesterday: String(localized: "Yesterday")
        case .earlier: day.formatted(.dateTime.weekday(.wide))
        }
    }

    /// "This month", or the month's name when looking back at an earlier month.
    func monthTitle(_ day: Date) -> String {
        isInCurrentMonth(day) ? String(localized: "This month") : day.formatted(.dateTime.month(.wide))
    }
}

#Preview {
    @Previewable @State var day = Calendar.current.startOfDay(for: .now)
    DayNavigator(day: $day, navigation: DayNavigation(today: .now))
        .padding()
}
