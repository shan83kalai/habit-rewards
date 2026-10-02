import SwiftData
import XCTest
@testable import HabitRewards

/// Base class for tests that need a store. Each test gets a fresh in-memory container.
@MainActor
class SwiftDataTestCase: XCTestCase {
    /// Held for the whole test: a `ModelContext` stops working once its container is freed.
    /// A test can open several (e.g. backing up one "phone" and restoring into another).
    private var containers: [ModelContainer] = []

    func makeContext() throws -> ModelContext {
        let container = try AppSchema.makeContainer(inMemory: true)
        containers.append(container)
        return container.mainContext
    }
}
