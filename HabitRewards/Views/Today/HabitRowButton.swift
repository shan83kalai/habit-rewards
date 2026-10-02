import SwiftData
import SwiftUI

/// A large tappable row: habit icon and title, with its status on the right.
struct HabitRowButton: View {
    let habit: Habit
    let status: HabitStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: habit.sfSymbol)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 36)
                Text(habit.title)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: status.symbolName)
                    .font(.largeTitle)
                    .foregroundStyle(status.colour)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 72)
            .background(status.rowBackground, in: .rect(cornerRadius: 16))
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(habit.title)
        .accessibilityValue(status.accessibilityName)
        .accessibilityHint(status.tapHint)
    }
}

#Preview {
    @Previewable @State var status = HabitStatus.unset
    VStack(spacing: 12) {
        HabitRowButton(habit: Habit(title: "Yoga", sfSymbol: "figure.yoga", sortOrder: 0), status: status) {
            status = status.next
        }
        HabitRowButton(habit: Habit(title: "Bed on time", sfSymbol: "bed.double", sortOrder: 1), status: .done) {}
        HabitRowButton(habit: Habit(title: "Evening walk (1 km+)", sfSymbol: "figure.walk", sortOrder: 2), status: .missed) {}
    }
    .padding()
    .modelContainer(.preview)
}
