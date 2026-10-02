import Foundation

/// Where the store lives: the App Group folder, so the widget can read the same data as the app.
nonisolated enum StoreLocation {
    static let appGroup = "group.ltd.kalai.HabitRewards"

    /// `<App Group>/Library/Application Support/default.store`, or the app's own folder when there's
    /// no App Group entitlement (e.g. SwiftUI previews).
    static var storeURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
        return (base ?? URL.applicationSupportDirectory).appending(path: "default.store")
    }

    /// Where the store was before the widget existed (phases 1–5).
    static var legacyStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "default.store")
    }

    /// Moves the store and its `-wal`/`-shm` journal files from `source` to `destination`, unless
    /// `destination` already has a store or there's nothing to move. Returns whether it moved.
    @discardableResult
    static func moveStore(from source: URL, to destination: URL, fileManager: FileManager = .default) throws -> Bool {
        guard source != destination,
              fileManager.fileExists(atPath: source.path),
              !fileManager.fileExists(atPath: destination.path)
        else { return false }
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] {
            let from = URL(filePath: source.path + suffix)
            guard fileManager.fileExists(atPath: from.path) else { continue }
            try fileManager.moveItem(at: from, to: URL(filePath: destination.path + suffix))
        }
        return true
    }
}
