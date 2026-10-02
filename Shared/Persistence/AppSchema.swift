import Foundation
import SwiftData

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Child.self,
        Habit.self,
        MonthRules.self,
        DayEntry.self,
        Payout.self,
    ]

    /// The app's store, in the App Group folder shared with the widget. CloudKit is off: syncing
    /// between parents goes through the app's own sharing code, not SwiftData's iCloud mirroring.
    /// - Parameter readOnly: For the widget, which only ever reads.
    static func makeContainer(inMemory: Bool = false, readOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration: ModelConfiguration
        if inMemory {
            // Unique names keep in-memory stores (tests, previews) isolated from each other.
            configuration = ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            if !readOnly {
                // Earlier versions kept the store in the app's own folder; bring it across once.
                _ = try? StoreLocation.moveStore(from: StoreLocation.legacyStoreURL, to: StoreLocation.storeURL)
            }
            configuration = ModelConfiguration(schema: schema, url: StoreLocation.storeURL, allowsSave: !readOnly, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
