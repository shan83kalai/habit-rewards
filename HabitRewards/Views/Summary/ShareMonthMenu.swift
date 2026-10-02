import SwiftUI

/// Share the month as a spreadsheet (CSV) or a printable PDF.
struct ShareMonthMenu: View {
    let report: MonthReport

    var body: some View {
        Menu {
            ShareLink(item: CSVExport(report: report), preview: SharePreview("\(report.title) (spreadsheet)")) {
                Label("Spreadsheet (CSV)", systemImage: "tablecells")
            }
            ShareLink(item: PDFExport(report: report), preview: SharePreview("\(report.title) (PDF)")) {
                Label("PDF", systemImage: "doc.richtext")
            }
        } label: {
            Label("Share \(report.title)", systemImage: "square.and.arrow.up")
        }
    }
}
