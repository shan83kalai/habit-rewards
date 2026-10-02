import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum BackupRequest: Hashable {
    case backUp
    case restore
}

/// The "Back up" and "Restore" buttons. The Files pickers and dialogs live in `BackupFlow`,
/// attached to the Form, because presentations attached to a `Section` never show.
struct BackupSection: View {
    let request: (BackupRequest) -> Void

    var body: some View {
        Section {
            Button("Back up to Files", systemImage: "square.and.arrow.up") { request(.backUp) }
            Button("Restore from a backup", systemImage: "arrow.counterclockwise") { request(.restore) }
        } header: {
            Text("Backup")
                .foregroundStyle(.subtle)
        } footer: {
            Text("A backup is one file with every child, habit, tick and payment. Keep it somewhere safe, like iCloud Drive or your Mac.")
                .foregroundStyle(.subtle)
        }
    }
}

extension View {
    /// Handles a `BackupRequest`: saving a backup file, or picking one and restoring it.
    func backupFlow(_ request: Binding<BackupRequest?>) -> some View {
        modifier(BackupFlow(request: request))
    }
}

private struct BackupFlow: ViewModifier {
    @Binding var request: BackupRequest?

    @Environment(\.modelContext) private var context
    @State private var document: BackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var pending: Backup?
    @State private var problem: String?

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _, newRequest in
                guard let newRequest else { return }
                request = nil
                switch newRequest {
                case .backUp: prepareBackup()
                case .restore:
                    // Restoring replaces everything, which would also overwrite the other parent's phone.
                    if FamilySync.shared.isSharing {
                        problem = String(localized: "Stop family sharing before restoring a backup, so the other phone isn't overwritten.")
                    } else {
                        importing = true
                    }
                }
            }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: fileName) { result in
                if case .failure = result { problem = String(localized: "Couldn't save the backup. Please try again.") }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                load(result)
            }
            .confirmationDialog(
                "Replace everything with this backup?",
                isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                titleVisibility: .visible,
                presenting: pending
            ) { backup in
                Button("Replace with backup", role: .destructive) { restore(backup) }
            } message: { backup in
                Text("It has \(backup.children.count) children, \(backup.habits.count) habits and \(backup.tickCount) ticks, saved on \(backup.exportedAt.formatted(date: .abbreviated, time: .shortened)). Everything on this phone now will be replaced.")
            }
            .alert("Backup", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(problem ?? "")
            }
    }

    private var fileName: String {
        "Habit Rewards backup \(Date.now.formatted(.iso8601.year().month().day()))"
    }

    private func prepareBackup() {
        do {
            document = BackupDocument(data: try Backup.make(from: context).encoded())
            exporting = true
        } catch {
            problem = String(localized: "Couldn't make the backup. Please try again.")
        }
    }

    private func load(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let canRead = url.startAccessingSecurityScopedResource()
            defer { if canRead { url.stopAccessingSecurityScopedResource() } }
            pending = try Backup.decode(Data(contentsOf: url))
        } catch {
            problem = Self.message(for: error)
        }
    }

    private func restore(_ backup: Backup) {
        do {
            try backup.restore(into: context)
            problem = String(localized: "Restored. Everything now matches the backup.")
        } catch {
            problem = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        switch error as? Backup.RestoreError {
        case .unreadable: String(localized: "That file isn't a Habit Rewards backup.")
        case .newerVersion: String(localized: "That backup was made by a newer version of Habit Rewards. Update the app, then try again.")
        case .brokenReference, .badDay: String(localized: "That backup is damaged, so nothing was changed.")
        case nil: String(localized: "Couldn't restore that backup, so nothing was changed.")
        }
    }
}

/// The backup as a JSON file for the Files app.
nonisolated struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
