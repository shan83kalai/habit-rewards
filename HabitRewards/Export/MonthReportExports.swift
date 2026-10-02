import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// The month as a CSV file for the share sheet.
nonisolated struct CSVExport: Transferable {
    let report: MonthReport

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            SentTransferredFile(try writeTemporaryFile(export.report.csvData, name: "Habit Rewards \(export.report.title).csv"))
        }
    }
}

/// The month as a PDF for the share sheet. The PDF is only drawn when it's actually shared.
nonisolated struct PDFExport: Transferable {
    let report: MonthReport

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { export in
            let data = await MainActor.run { MonthReportPDF.data(for: export.report) }
            return SentTransferredFile(try writeTemporaryFile(data, name: "Habit Rewards \(export.report.title).pdf"))
        }
    }
}

/// Writes to a fresh temporary folder so the shared file gets a readable name.
nonisolated private func writeTemporaryFile(_ data: Data, name: String) throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appending(path: name)
    try data.write(to: url)
    return url
}
