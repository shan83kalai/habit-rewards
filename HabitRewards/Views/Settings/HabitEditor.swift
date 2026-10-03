import Foundation
import SwiftData
import SwiftUI

/// Adds a habit (`habit == nil`) or edits one: name, icon, which children it's for, and on/off.
struct HabitEditor: View {
    let habit: Habit?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query(filter: #Predicate<Child> { !$0.isArchived }, sort: \Child.sortOrder) private var children: [Child]

    @State private var title: String
    @State private var symbol: String
    @State private var isActive: Bool
    @State private var audience: HabitAudience
    @State private var saveFailed = false

    init(habit: Habit?) {
        self.habit = habit
        _title = State(initialValue: habit?.title ?? "")
        _symbol = State(initialValue: habit?.sfSymbol ?? Palettes.habitSymbols[0])
        _isActive = State(initialValue: habit?.isActive ?? true)
        _audience = State(initialValue: HabitAudience(childIDs: habit?.childIDs ?? []))
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
                if !children.isEmpty {
                    Section {
                        ForEach(children) { child in
                            Button { audience.toggle(child.id, among: children.map(\.id)) } label: {
                                HStack {
                                    Circle()
                                        .fill(Color(hex: child.colourHex))
                                        .frame(width: 14, height: 14)
                                    Text(child.name)
                                    Spacer()
                                    if audience.includes(child.id) {
                                        // The row is tinted for its text, so name the accent colour.
                                        Image(systemName: "checkmark")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .tint(.primary)
                            .accessibilityAddTraits(audience.includes(child.id) ? .isSelected : [])
                        }
                    } header: {
                        Text("For")
                    } footer: {
                        Text("A child added later gets this habit only when every child is ticked.")
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
                        .disabled(trimmedTitle.isEmpty || !audience.isForAnyone(among: children.map(\.id)))
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
            habit.childIDs = audience.childIDs(among: children.map(\.id))
            habit.touch()
        } else {
            let nextSortOrder = (habits.map(\.sortOrder).max() ?? -1) + 1
            let new = Habit(title: trimmedTitle, sfSymbol: symbol, sortOrder: nextSortOrder)
            context.insert(new)
            new.childIDs = audience.childIDs(among: children.map(\.id))
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
