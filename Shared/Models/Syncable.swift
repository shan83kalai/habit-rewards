import Foundation

/// Bookkeeping every model carries for family sharing through iCloud.
///
/// - `modifiedAt`: when this phone last changed the record. When two phones disagree, the newer change wins.
/// - `syncedAt`: the `modifiedAt` of the version last sent to or received from iCloud. A record is
///   waiting to upload while `modifiedAt > syncedAt`.
/// - `cloudSystemFields`: CloudKit's own bookkeeping (e.g. its change tag), so this phone's next
///   upload replaces the latest version instead of tripping over it.
protocol Syncable: AnyObject {
    /// Unique across all record types, e.g. `child-<uuid>` or `rules-2026-10`.
    var cloudRecordName: String { get }
    var modifiedAt: Date { get set }
    var syncedAt: Date { get set }
    var cloudSystemFields: Data? { get set }
}

extension Syncable {
    /// Marks a change made on this phone, to be uploaded if sharing is on.
    func touch(_ now: Date = .now) {
        modifiedAt = now
    }

    var hasUnsyncedChanges: Bool {
        modifiedAt > syncedAt
    }
}

/// Posted after local data is saved, so the sync layer (when sharing is on) uploads the changes.
nonisolated enum LocalChanges {
    static let didSave = Notification.Name("HabitRewards.LocalChanges.didSave")
    /// `[String]` of `cloudRecordName`s that were deleted.
    static let deletedKey = "deleted"

    static func post(deleted: [String] = []) {
        NotificationCenter.default.post(name: didSave, object: nil, userInfo: [deletedKey: deleted])
    }
}
