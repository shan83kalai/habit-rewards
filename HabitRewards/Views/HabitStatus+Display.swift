import SwiftUI

/// How each status looks, sounds and reads to VoiceOver. Kept out of `Scoring/` so that stays UI-free.
extension HabitStatus {
    var symbolName: String {
        switch self {
        case .unset: "circle"
        case .done: "checkmark.circle.fill"
        case .missed: "xmark.circle.fill"
        }
    }

    /// Month grid cells leave unset days blank, like the spreadsheet.
    var gridSymbol: String? {
        switch self {
        case .unset: nil
        case .done: "checkmark"
        case .missed: "xmark"
        }
    }

    var colour: Color {
        switch self {
        case .unset: .secondary
        case .done: .green
        case .missed: .red
        }
    }

    var rowBackground: Color {
        switch self {
        case .unset: .gray.opacity(0.12)
        case .done: .green.opacity(0.18)
        case .missed: .red.opacity(0.15)
        }
    }

    var accessibilityName: String {
        switch self {
        case .unset: String(localized: "Not ticked")
        case .done: String(localized: "Done")
        case .missed: String(localized: "Missed")
        }
    }

    /// What tapping a habit in this state does.
    var tapHint: String {
        switch self {
        case .unset: String(localized: "Marks it done")
        case .done: String(localized: "Marks it missed")
        case .missed: String(localized: "Clears it")
        }
    }

    /// Haptic played when a habit changes to this state.
    var feedback: SensoryFeedback {
        switch self {
        case .unset: .selection
        case .done: .success
        case .missed: .warning
        }
    }
}
