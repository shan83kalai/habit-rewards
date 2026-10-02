import Foundation
import SwiftData
import SwiftUI

/// Every habit, active or not. Tap to edit, drag to reorder (Edit), or add one.
struct HabitsSection: View {
    /// Opens the editor for a habit, or for a new one when `nil`.
    let edit: (Habit?) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]

    var body: some View {
        Section {
            ForEach(habits) { habit in
                Button { edit(habit) } label: {
                    HStack {
                        Label(habit.title, systemImage: habit.sfSymbol)
                        Spacer()
                        if !habit.isActive {
                            Text("Off")
                        }
                    }
                }
                // Forms tint button text; use plain text colours so "off" habits look greyed out.
                .tint(habit.isActive ? .primary : .secondary)
            }
            .onMove(perform: move)

            Button("Add habit", systemImage: "plus") { edit(nil) }
        } header: {
            Text("Habits")
                .foregroundStyle(.subtle)
        } footer: {
            Text("Turning a habit off hides it from new days but keeps its history.")
                .foregroundStyle(.subtle)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = habits
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, habit) in ordered.enumerated() where habit.sortOrder != index {
            habit.sortOrder = index
            habit.touch()
        }
        try? context.save()
        LocalChanges.post()
    }
}
