import Foundation
import SwiftData

/// The children and habits inserted on first launch. Parents rename the children in Settings.
enum SeedData {
    static let children: [(name: String, colourHex: String)] = [
        ("Child 1", "#7B61FF"),
        ("Child 2", "#FF8A3D"),
    ]

    static let habits: [(title: String, sfSymbol: String)] = [
        ("Homework", "pencil"),
        ("Reading", "book.closed"),
        ("Brush teeth", "mouth"),
        ("Bed on time", "bed.double"),
        ("Tidy room", "sparkles"),
        ("Exercise", "figure.run"),
    ]

    /// Inserts the default children and habits if the store has none. Safe to call on every launch.
    static func seedIfNeeded(_ context: ModelContext) throws {
        if try context.fetchCount(FetchDescriptor<Child>()) == 0 {
            for (index, child) in children.enumerated() {
                let new = Child(name: child.name, colourHex: child.colourHex, sortOrder: index)
                context.insert(new)
                new.touch()
            }
        }
        if try context.fetchCount(FetchDescriptor<Habit>()) == 0 {
            for (index, habit) in habits.enumerated() {
                let new = Habit(title: habit.title, sfSymbol: habit.sfSymbol, sortOrder: index)
                context.insert(new)
                new.touch()
            }
        }
        if context.hasChanges {
            try context.save()
        }
    }
}
