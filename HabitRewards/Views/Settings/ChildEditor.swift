import Foundation
import SwiftData
import SwiftUI

/// Adds a child (`child == nil`) or edits one: name, colour, and archived.
struct ChildEditor: View {
    let child: Child?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Child.sortOrder) private var children: [Child]

    @State private var name: String
    @State private var colourHex: String
    @State private var isArchived: Bool
    @State private var saveFailed = false

    init(child: Child?) {
        self.child = child
        _name = State(initialValue: child?.name ?? "")
        _colourHex = State(initialValue: child?.colourHex ?? Palettes.childColours[2])
        _isArchived = State(initialValue: child?.isArchived ?? false)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                        .textContentType(.givenName)
                        .accessibilityIdentifier("childName")
                }
                Section("Colour") {
                    PalettePicker(options: Palettes.childColours, selection: $colourHex) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .padding(6)
                            .accessibilityLabel(Palettes.colourName(hex))
                    }
                    .tint(.primary)
                }
                if child != nil {
                    Section {
                        Toggle("Archived", isOn: $isArchived)
                    } footer: {
                        Text("Archiving hides them from the day-to-day screens. Their history stays.")
                    }
                }
            }
            .navigationTitle(child == nil ? "New child" : "Edit child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .alert("Couldn't save", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func save() {
        if let child {
            child.name = trimmedName
            child.colourHex = colourHex
            child.isArchived = isArchived
            child.touch()
        } else {
            let nextSortOrder = (children.map(\.sortOrder).max() ?? -1) + 1
            let new = Child(name: trimmedName, colourHex: colourHex, sortOrder: nextSortOrder)
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
    ChildEditor(child: nil)
        .modelContainer(.preview)
}
