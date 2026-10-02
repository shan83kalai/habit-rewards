import SwiftUI
import WidgetKit

/// "Today's rewards": what each child has earned today, on the home or lock screen.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetCenter.todayKind, provider: TodayProvider()) { entry in
            TodayWidgetFamilyView(entry: entry)
        }
        .configurationDisplayName("Today's rewards")
        .description("What each child has earned today and this month.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

/// Passes the widget's actual size to `TodayWidgetView`.
private struct TodayWidgetFamilyView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        TodayWidgetView(entry: entry, family: family)
    }
}

/// Reads the store now, then again just after midnight. The app also asks for a reload whenever
/// it goes to the background, so ticks show up straight away.
nonisolated struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, summary: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        let isPreview = context.isPreview
        Task { @MainActor in
            completion(TodayEntry(date: .now, summary: isPreview ? .sample : .load()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        Task { @MainActor in
            let now = Date.now
            let calendar = Calendar.current
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
            let entry = TodayEntry(date: now, summary: .load(now: now))
            completion(Timeline(entries: [entry], policy: .after(tomorrow.addingTimeInterval(60))))
        }
    }
}
