import SwiftUI

/// The icons and colours offered when adding or editing habits and children.
enum Palettes {
    static let habitSymbols = [
        "x.squareroot", "figure.yoga", "mouth", "bed.double", "alarm", "figure.walk",
        "book.closed", "pencil", "music.note", "paintbrush", "brain.head.profile", "backpack",
        "fork.knife", "carrot", "cup.and.saucer", "drop", "shower", "hands.sparkles",
        "figure.run", "bicycle", "soccerball", "sun.max", "moon.stars", "leaf",
        "heart", "star", "sparkles", "tshirt", "trash", "pawprint",
    ]

    /// Mid-tone colours that read well on light and dark backgrounds.
    static let childColours = [
        "#7B61FF", "#FF8A3D", "#14B8A6", "#EC4899", "#3B82F6", "#22C55E", "#EF4444", "#F59E0B",
    ]

    /// What VoiceOver calls each colour.
    static func colourName(_ hex: String) -> String {
        switch hex.uppercased() {
        case "#7B61FF": String(localized: "Purple")
        case "#FF8A3D": String(localized: "Orange")
        case "#14B8A6": String(localized: "Teal")
        case "#EC4899": String(localized: "Pink")
        case "#3B82F6": String(localized: "Blue")
        case "#22C55E": String(localized: "Green")
        case "#EF4444": String(localized: "Red")
        case "#F59E0B": String(localized: "Amber")
        default: String(localized: "Custom colour")
        }
    }
}

/// A grid of choices with the selected one ringed.
struct PalettePicker<Content: View>: View {
    let options: [String]
    @Binding var selection: String
    let label: (String) -> Content

    var body: some View {
        // Keep a custom value (e.g. from a restore) selectable even if it isn't in the palette.
        let choices = options.contains(selection) ? options : [selection] + options
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 12) {
            ForEach(choices, id: \.self) { option in
                let isSelected = option == selection
                Button { selection = option } label: {
                    label(option)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Circle().strokeBorder(.tint, lineWidth: isSelected ? 3 : 0)
                        }
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
