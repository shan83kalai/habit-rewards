import Foundation
import SwiftData
import SwiftUI
import UIKit

@main
struct HabitRewardsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer

    init() {
        // Unit tests run inside the app and UI tests launch it with -uiTesting; keep both off the real store.
        let process = ProcessInfo.processInfo
        let isRunningTests = process.environment["XCTestConfigurationFilePath"] != nil || process.arguments.contains("-uiTesting")
        do {
            container = try AppSchema.makeContainer(inMemory: isRunningTests)
            if !isRunningTests {
                FamilySync.shared.start(with: container)
            }
            // A phone in a family gets its children and habits from iCloud. Seeding here would make
            // duplicates if it restarted before they arrived.
            if !FamilySync.shared.isSharing {
                try SeedData.seedIfNeeded(container.mainContext)
            }
        } catch {
            fatalError("Could not open the habits store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
