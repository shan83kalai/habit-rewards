import SwiftUI

/// Lays its views side by side, or one above the other at the largest (accessibility) text sizes.
struct TileRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder var content: Content

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        layout { content }
    }
}

#Preview {
    TileRow {
        StatTile(title: "Today", value: "£1.75")
        StatTile(title: "This month", value: "£12.50")
    }
    .padding()
    .dynamicTypeSize(.accessibility2)
}
