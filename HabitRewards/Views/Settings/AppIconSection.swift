import SwiftUI
import UIKit

/// The home-screen icon: the star coin, or a coin in the family's own currency.
struct AppIconSection: View {
    @State private var selected = AppIconChoice(iconName: UIApplication.shared.alternateIconName)

    var body: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 12)], spacing: 12) {
                ForEach(AppIconChoice.allCases) { choice in
                    Button { choose(choice) } label: {
                        Image(choice.previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .padding(4)
                            .overlay {
                                if choice == selected {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(.tint, lineWidth: 3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.name)
                    .accessibilityAddTraits(choice == selected ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("App icon")
                .foregroundStyle(.subtle)
        } footer: {
            if let suggested = AppIconChoice.matching(currencyCode: Money.currencyCode), suggested != selected {
                Text("The coin on your home-screen icon. The \(suggested.name.lowercased()) matches this phone's currency.")
                    .foregroundStyle(.subtle)
            } else {
                Text("The coin on your home-screen icon.")
                    .foregroundStyle(.subtle)
            }
        }
    }

    private func choose(_ choice: AppIconChoice) {
        guard choice != selected, UIApplication.shared.supportsAlternateIcons else { return }
        selected = choice
        Task {
            // iOS confirms the change with its own short alert. It can report an error even when the
            // icon did change, so show whatever icon is now set rather than trusting the result.
            try? await UIApplication.shared.setAlternateIconName(choice.iconName)
            selected = AppIconChoice(iconName: UIApplication.shared.alternateIconName)
        }
    }
}
