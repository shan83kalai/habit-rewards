import SwiftUI
import WidgetKit

/// The widget's content for each size. Lives in `Shared/` so the app's tests can render it.
struct TodayWidgetView: View {
    let entry: TodayEntry
    let family: WidgetFamily

    var body: some View {
        Group {
            if entry.summary.children.isEmpty {
                Text("Open Habit Rewards to get started.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            } else {
                switch family {
                case .accessoryRectangular: rectangular
                case .systemMedium: medium
                default: small
                }
            }
        }
        .containerBackground(for: .widget) {
            if family != .accessoryRectangular {
                LinearGradient(colors: [Color(hex: "#6C4DFF").opacity(0.16), Color(hex: "#FF8A3D").opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    /// Today's amount for each child.
    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.subtle)
            ForEach(entry.summary.children.prefix(3)) { child in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: child.colourHex)).frame(width: 8, height: 8)
                        Text(child.name).font(.subheadline).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(Money.format(child.todayPence)).font(.subheadline.bold()).monospacedDigit()
                    }
                    Text("\(Money.format(child.monthPence)) this month")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.subtle)
                        .padding(.leading, 14)
                }
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Today, ticks done and the month, side by side for each child.
    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(entry.summary.children.prefix(2)) { child in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: child.colourHex)).frame(width: 10, height: 10)
                        Text(child.name).font(.headline).lineLimit(1)
                    }
                    Text(Money.format(child.todayPence))
                        .font(.title.bold())
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                    Text("\(child.done) of \(child.habitCount) done today")
                        .font(.caption)
                        .foregroundStyle(.subtle)
                    Spacer(minLength: 0)
                    Text("This month \(Money.format(child.monthPence))")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// Lock screen: one line per child.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entry.summary.children.prefix(3)) { child in
                HStack {
                    Text(child.name).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(Money.format(child.todayPence)).monospacedDigit().bold()
                }
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview(as: .systemSmall) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, summary: .sample)
}

#Preview(as: .systemMedium) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, summary: .sample)
}
