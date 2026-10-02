import SwiftUI

/// The month as a PDF: one A4 landscape page per child, laid out like the spreadsheet.
enum MonthReportPDF {
    /// A4 landscape, in points.
    static let pageSize = CGSize(width: 842, height: 595)

    static func data(for report: MonthReport) -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return Data() }

        for child in report.children {
            let page = ReportPage(report: report, child: child)
                .frame(width: pageSize.width, height: pageSize.height)
            let renderer = ImageRenderer(content: page)
            pdf.beginPDFPage(nil)
            renderer.render { _, draw in draw(pdf) }
            pdf.endPDFPage()
        }
        pdf.closePDF()
        return data as Data
    }
}

private struct ReportPage: View {
    let report: MonthReport
    let child: MonthReport.ChildPage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(child.name).font(.system(size: 26, weight: .bold))
                Spacer()
                Text(report.title).font(.system(size: 18, weight: .semibold))
            }
            HStack(spacing: 32) {
                stat("Month total", Money.format(child.totalPence, currencyCode: report.currencyCode))
                stat("Perfect days", "\(child.perfectDays)")
                stat("Best streak", "\(child.bestStreak)")
            }
            table
            Spacer(minLength: 0)
            Text("Habit Rewards · \(report.title)")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .background(.white)
        .environment(\.colorScheme, .light)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 18, weight: .bold)).monospacedDigit()
        }
    }

    private var table: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                cell("Habit", alignment: .leading).bold()
                ForEach(report.dayNumbers, id: \.self) { cell("\($0)").bold() }
            }
            ForEach(child.habits, id: \.title) { habit in
                GridRow {
                    cell(habit.title, alignment: .leading)
                    ForEach(habit.statuses.indices, id: \.self) { index in
                        statusCell(habit.statuses[index])
                    }
                }
            }
            GridRow {
                cell("Day score (\(report.currencySymbol))", alignment: .leading).bold()
                ForEach(child.dayScores.indices, id: \.self) { cell(child.dayScores[$0].map(report.csvMoney) ?? "") }
            }
            GridRow {
                cell("Running total (\(report.currencySymbol))", alignment: .leading)
                ForEach(child.runningTotals.indices, id: \.self) { cell(child.runningTotals[$0].map(report.csvMoney) ?? "") }
            }
        }
        .font(.system(size: 8))
        .overlay { Rectangle().strokeBorder(.gray.opacity(0.5), lineWidth: 0.5) }
    }

    private func cell(_ text: String, alignment: Alignment = .center) -> some View {
        Text(text)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, alignment == .leading ? 4 : 0)
            .frame(width: alignment == .leading ? 150 : 20, height: 22, alignment: alignment)
            .border(.gray.opacity(0.3), width: 0.5)
    }

    private func statusCell(_ status: HabitStatus) -> some View {
        Text(status == .done ? "✓" : status == .missed ? "✗" : "")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(status == .done ? .green : .red)
            .frame(width: 20, height: 22)
            .background(status == .done ? Color.green.opacity(0.12) : status == .missed ? Color.red.opacity(0.10) : .clear)
            .border(.gray.opacity(0.3), width: 0.5)
    }
}
