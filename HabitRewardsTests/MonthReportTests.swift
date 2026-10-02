import PDFKit
import SwiftData
import XCTest
@testable import HabitRewards

/// The month as CSV and PDF, built from real (in-memory) SwiftData entries.
final class MonthReportTests: SwiftDataTestCase {
    private let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private let october = CalendarMonth(year: 2026, month: 10)

    private func day(_ day: Int) -> Date {
        london.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12))!
    }

    /// Child 1: 1 Oct all done (£3.00), 2 Oct five done + exercise missed (£1.75). Today is 3 Oct.
    private func makeReport(currencyCode: String = "GBP") throws -> MonthReport {
        let context = try makeContext()
        try SeedData.seedIfNeeded(context)
        let children = try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
        let habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
        for habit in habits {
            try DayEntry.upsert(child: children[0], habit: habit, date: day(1), status: .done, in: context, calendar: london)
            try DayEntry.upsert(child: children[0], habit: habit, date: day(2), status: habit.sortOrder == 5 ? .missed : .done, in: context, calendar: london)
        }
        let entries = try context.fetch(FetchDescriptor<DayEntry>())
        let sheets = children.map { child in
            (name: child.name, sheet: MonthSheet(child: child, month: october, today: day(3), habits: habits, entries: entries, rules: .standard, calendar: london))
        }
        return MonthReport(title: "October 2026", sheets: sheets, currencyCode: currencyCode)
    }

    // MARK: - Snapshot

    func testReportHasAPagePerChildWithEveryDay() throws {
        let report = try makeReport()
        XCTAssertEqual(report.dayNumbers, Array(1...31))
        XCTAssertEqual(report.children.map(\.name), ["Child 1", "Child 2"])
        XCTAssertEqual(report.children[0].totalPence, 475)
        XCTAssertEqual(report.children[0].perfectDays, 1)
        XCTAssertEqual(report.children[0].habits.map(\.title).first, "Homework")
    }

    // MARK: - CSV

    func testCSVLooksLikeTheSpreadsheet() throws {
        let lines = try makeReport().csv.components(separatedBy: "\r\n")

        XCTAssertEqual(lines[0], "Habit Rewards,October 2026")
        XCTAssertEqual(lines[2], "Child 1")
        XCTAssertEqual(lines[3], "Habit," + (1...31).map(String.init).joined(separator: ","))
        XCTAssertTrue(lines[4].hasPrefix("Homework,✓,✓,,"))
        XCTAssertTrue(lines[9].hasPrefix("Exercise,✓,✗,,"))
        XCTAssertTrue(lines[10].hasPrefix("Day score (£),3.00,1.75,0.00,"))
        XCTAssertTrue(lines[11].hasPrefix("Running total (£),3.00,4.75,4.75,"))
        XCTAssertTrue(lines.contains("Month total (£),4.75"))
        XCTAssertTrue(lines.contains("Perfect days,1"))
        XCTAssertTrue(lines.contains("Child 2"))
    }

    func testCSVLeavesDaysAfterTodayBlank() throws {
        let dayScoreRow = try XCTUnwrap(makeReport().csv.components(separatedBy: "\r\n").first { $0.hasPrefix("Day score") })
        let cells = dayScoreRow.components(separatedBy: ",")
        XCTAssertEqual(cells.count, 32)
        XCTAssertEqual(cells[3], "0.00") // 3 October, today
        XCTAssertEqual(cells[4], "")     // 4 October, still to come
    }

    func testCSVQuotesFieldsWithCommasAndQuotes() {
        XCTAssertEqual(MonthReport.csvField("Yoga"), "Yoga")
        XCTAssertEqual(MonthReport.csvField("Read, then sleep"), "\"Read, then sleep\"")
        XCTAssertEqual(MonthReport.csvField("The \"big\" walk"), "\"The \"\"big\"\" walk\"")
        XCTAssertEqual(MonthReport.csvField("Two\nlines"), "\"Two\nlines\"")
    }

    func testCSVMoneyIsInTheReportsCurrency() throws {
        // The same stored numbers are whole yen: 6 habits × 50 = ¥300.
        let dayScoreRow = try XCTUnwrap(makeReport(currencyCode: "JPY").csv.components(separatedBy: "\r\n").first { $0.hasPrefix("Day score") })
        XCTAssertEqual(Array(dayScoreRow.components(separatedBy: ",")[1...4]), ["300", "175", "0", ""])
    }

    func testCSVFileStartsWithAByteOrderMarkForExcel() throws {
        let data = try makeReport().csvData
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])
    }

    // MARK: - PDF

    func testPDFHasOneLandscapeA4PagePerChild() throws {
        let data = MonthReportPDF.data(for: try makeReport())
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "October 2026.pdf"
        attachment.lifetime = .keepAlways
        add(attachment)
        let document = try XCTUnwrap(PDFDocument(data: data))

        XCTAssertEqual(document.pageCount, 2)
        let bounds = try XCTUnwrap(document.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertEqual(bounds.width, 842, accuracy: 1)
        XCTAssertEqual(bounds.height, 595, accuracy: 1)
        XCTAssertTrue(try XCTUnwrap(document.page(at: 0)?.string).contains("Child 1"))
        XCTAssertTrue(try XCTUnwrap(document.page(at: 1)?.string).contains("Child 2"))
    }
}
