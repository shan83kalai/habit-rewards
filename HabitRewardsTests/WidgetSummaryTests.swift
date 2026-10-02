import SwiftData
import SwiftUI
import WidgetKit
import XCTest
@testable import HabitRewards

/// What the home-screen widget shows, read from the same store as the app.
final class WidgetSummaryTests: SwiftDataTestCase {
    private let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private func day(_ day: Int, hour: Int = 12) -> Date {
        london.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func makeStore() throws -> ModelContext {
        let context = try makeContext()
        try SeedData.seedIfNeeded(context)
        let children = try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
        let habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
        // Child 1: yesterday perfect (£3.00), today 4 done + 1 missed (£1.25).
        for (index, habit) in habits.enumerated() {
            try DayEntry.upsert(child: children[0], habit: habit, date: day(1), status: .done, in: context, calendar: london)
            let today: HabitStatus = index < 4 ? .done : index == 4 ? .missed : .unset
            try DayEntry.upsert(child: children[0], habit: habit, date: day(2), status: today, in: context, calendar: london)
        }
        try context.save()
        return context
    }

    func testShowsEachChildsTodayAndMonth() throws {
        let summary = try WidgetSummary(context: try makeStore(), now: day(2, hour: 18), calendar: london)

        XCTAssertEqual(summary.children.map(\.name), ["Child 1", "Child 2"])
        let firstChild = summary.children[0]
        XCTAssertEqual(firstChild.todayPence, 125)
        XCTAssertEqual(firstChild.monthPence, 425)
        XCTAssertEqual(firstChild.done, 4)
        XCTAssertEqual(firstChild.habitCount, 6)
        XCTAssertEqual(summary.children[1].todayPence, 0)
    }

    func testMatchesTheTodayScreen() throws {
        let context = try makeStore()
        let summary = try WidgetSummary(context: context, now: day(2), calendar: london)
        let child = try XCTUnwrap(context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)])).first)
        let board = DayBoard(
            child: child, day: day(2), habits: try context.fetch(FetchDescriptor<Habit>()),
            entries: try context.fetch(FetchDescriptor<DayEntry>()), rules: .standard, calendar: london
        )
        XCTAssertEqual(summary.children[0].todayPence, board.dayPence)
        XCTAssertEqual(summary.children[0].monthPence, board.monthPence)
    }

    func testArchivedChildrenAreLeftOut() throws {
        let context = try makeStore()
        try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))[1].isArchived = true
        XCTAssertEqual(try WidgetSummary(context: context, now: day(2), calendar: london).children.map(\.name), ["Child 1"])
    }

    func testUsesThatMonthsRules() throws {
        let context = try makeStore()
        try MonthRules.set(ScoringRules(rewardPence: 100, penaltyPence: 50), for: CalendarMonth(year: 2026, month: 10), in: context)
        // Today: 4 × 100 − 1 × 50
        XCTAssertEqual(try WidgetSummary(context: context, now: day(2), calendar: london).children[0].todayPence, 350)
    }

    // MARK: - Rendering

    /// Renders each widget size to an image (attached to the test results) so the layout can be checked by eye.
    func testWidgetRendersInEverySize() throws {
        let summary = try WidgetSummary(context: try makeStore(), now: day(2), calendar: london)
        let entry = TodayEntry(date: day(2), summary: summary)
        let sizes: [(WidgetFamily, CGSize)] = [(.systemSmall, CGSize(width: 170, height: 170)), (.systemMedium, CGSize(width: 364, height: 170)), (.accessoryRectangular, CGSize(width: 172, height: 76))]
        for (family, size) in sizes {
            let view = TodayWidgetView(entry: entry, family: family)
                .frame(width: size.width, height: size.height)
                .background(Color(.systemBackground))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage, "\(family) didn't render")
            let attachment = XCTAttachment(image: image)
            attachment.name = "Widget \(family)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        // An empty store shows the "open the app" message rather than nothing.
        XCTAssertNotNil(ImageRenderer(content: TodayWidgetView(entry: TodayEntry(date: .now, summary: WidgetSummary(children: [])), family: .systemSmall)).uiImage)
    }
}
