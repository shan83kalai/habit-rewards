import Foundation
import SwiftUI

/// A fresh value per tap, so the haptic fires on taps but not when switching child, day or month.
struct HabitTap: Equatable {
    let id = UUID()
    let status: HabitStatus
}

extension View {
    /// Plays the tap haptic, and shows an alert if a tick couldn't be saved.
    func habitTapFeedback(_ tap: HabitTap?, saveFailed: Binding<Bool>) -> some View {
        sensoryFeedback(trigger: tap) { _, tap in tap?.status.feedback }
            .alert("Couldn't save that tick", isPresented: saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try again.")
            }
    }
}
