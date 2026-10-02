import Foundation
import SwiftData
import SwiftUI

/// Adds a habit (`habit == nil`) or edits one: name, icon, and on/off.
struct HabitEditor: View {
    let habit: Habit?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]

    @State private var title: String
    @State private var symbol: String
    @State private var isActive: Bool
    @State private var saveFailed = false

    init(habit: Habit?) {
        self.habit = habit
        _title = State(initialValue: habit?.title ?? "")
        _symbol = State(initialValue: habit?.sfSymbol ?? Palettes.habitSymbols[0])
        _isActive = State(initialValue: habit?.isActive ?? true)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Piano practice", text: $title)
                        .accessibilityIdentifier("habitName")
                }
                Section("Icon") {
                    PalettePicker(options: Palettes.habitSymbols, selection: $symbol) { symbol in
                        Image(systemName: symbol)
                            .font(.title3)
                            .foregroundStyle(.tint)
                    }
                }
                if habit != nil {
                    Section {
                        Toggle("Active", isOn: $isActive)
                    } footer: {
                        Text("Turning it off hides it from new days. Its history stays.")
                    }
                }
            }
            .navigationTitle(habit == nil ? "New habit" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .alert("Couldn't save the habit", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func save() {
        if let habit {
            habit.title = trimmedTitle
            habit.sfSymbol = symbol
            habit.isActive = isActive
            habit.touch()
        } else {
            let nextSortOrder = (habits.map(\.sortOrder).max() ?? -1) + 1
            let new = Habit(title: trimmedTitle, sfSymbol: symbol, sortOrder: nextSortOrder)
            context.insert(new)
            new.touch()
        }
        do {
            try context.save()
            LocalChanges.post()
            dismiss()
        } catch {
            context.rollback()
            saveFailed = true
        }
    }
}

#Preview {
    HabitEditor(habit: nil)
        .modelContainer(.preview)
}
