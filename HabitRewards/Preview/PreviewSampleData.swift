import Foundation
import SwiftData

extension ModelContainer {
    /// In-memory store with the seed data plus a few days of entries, for SwiftUI previews.
    static let preview: ModelContainer = {
        do {
            let container = try AppSchema.makeContainer(inMemory: true)
            let context = container.mainContext
            try SeedData.seedIfNeeded(context)

            let children = try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
            let habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)

            // The last five days, cycling through done / done / missed / unset patterns.
            let pattern: [HabitStatus] = [.done, .done, .done, .missed, .done, .unset, .done]
            for (childIndex, child) in children.enumerated() {
                for dayOffset in 0..<5 {
                    guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                    for (habitIndex, habit) in habits.enumerated() {
                        let status = pattern[(habitIndex + dayOffset + childIndex) % pattern.count]
                        try DayEntry.upsert(child: child, habit: habit, date: date, status: status, in: context)
                    }
                }
            }
            try context.save()
            return container
        } catch {
            fatalError("Could not build preview data: \(error)")
        }
    }()
}
