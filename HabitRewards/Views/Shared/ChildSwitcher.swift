import SwiftData
import SwiftUI

/// One button per child, each in that child's colour.
struct ChildSwitcher: View {
    let children: [Child]
    let selectedID: UUID?
    let select: (Child) -> Void

    var body: some View {
        TileRow {
            ForEach(children) { child in
                ChildChip(name: child.name, colour: Color(hex: child.colourHex), isSelected: child.id == selectedID) {
                    select(child)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedID)
    }
}

extension Array where Element == Child {
    /// The child with that ID (as stored in `@AppStorage`), or the first child if none matches.
    func selected(id: String) -> Child? {
        first { $0.id.uuidString == id } ?? first
    }
}

private struct ChildChip: View {
    let name: String
    let colour: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Selection shows as fill, border and bold; the text stays full contrast either way.
            Text(name)
                .font(isSelected ? .headline : .body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(isSelected ? colour.opacity(0.22) : .gray.opacity(0.12), in: .capsule)
                .overlay {
                    Capsule().strokeBorder(colour, lineWidth: isSelected ? 2 : 0)
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var selected: UUID?
    let children = [
        Child(name: "Child 1", colourHex: "#7B61FF", sortOrder: 0),
        Child(name: "Child 2", colourHex: "#FF8A3D", sortOrder: 1),
    ]
    ChildSwitcher(children: children, selectedID: selected ?? children[0].id) { selected = $0.id }
        .padding()
        .modelContainer(.preview)
}
