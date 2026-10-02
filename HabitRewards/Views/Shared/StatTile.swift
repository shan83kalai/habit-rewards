import SwiftUI

/// A small titled number, e.g. "Today £1.75" or "Perfect days 4".
struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.subtle)
            Text(value)
                .font(.title.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.tint.opacity(0.12), in: .rect(cornerRadius: 16))
        .animation(.snappy, value: value)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack {
        StatTile(title: "Month total", value: "£12.50")
        StatTile(title: "Perfect days", value: "4")
    }
    .padding()
}
