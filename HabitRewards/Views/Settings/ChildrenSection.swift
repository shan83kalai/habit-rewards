import Foundation
import SwiftData
import SwiftUI

/// Every child, archived or not. Tap to edit, drag to reorder (Edit), or add one.
struct ChildrenSection: View {
    /// Opens the editor for a child, or for a new one when `nil`.
    let edit: (Child?) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Child.sortOrder) private var children: [Child]

    var body: some View {
        Section {
            ForEach(children) { child in
                Button { edit(child) } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: child.colourHex))
                            .frame(width: 14, height: 14)
                        Text(child.name)
                        Spacer()
                        if child.isArchived {
                            Text("Archived")
                        }
                    }
                }
                // Forms tint button text; use plain text colours so archived children look greyed out.
                .tint(child.isArchived ? .secondary : .primary)
            }
            .onMove(perform: move)

            Button("Add child", systemImage: "plus") { edit(nil) }
        } header: {
            Text("Children")
                .foregroundStyle(.subtle)
        } footer: {
            Text("Archived children are hidden from the day-to-day screens. Their history stays.")
                .foregroundStyle(.subtle)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = children
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, child) in ordered.enumerated() where child.sortOrder != index {
            child.sortOrder = index
            child.touch()
        }
        try? context.save()
        LocalChanges.post()
    }
}
