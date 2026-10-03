import SwiftUI

/// An extra task on the Today screen: tap to mark it done (or not). Touch and hold to change or
/// remove it.
struct ExtraTaskRow: View {
    let task: ExtraTask
    let toggle: () -> Void
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 16) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.title3.weight(.medium))
                        .multilineTextAlignment(.leading)
                    Text(Money.format(task.rewardPence))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.subtle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: task.isDone ? HabitStatus.done.symbolName : HabitStatus.unset.symbolName)
                    .font(.largeTitle)
                    .foregroundStyle(task.isDone ? HabitStatus.done.colour : HabitStatus.unset.colour)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 72)
            .background(task.isDone ? HabitStatus.done.rowBackground : HabitStatus.unset.rowBackground, in: .rect(cornerRadius: 16))
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Change", systemImage: "pencil", action: edit)
            Button("Remove", systemImage: "trash", role: .destructive, action: delete)
        }
        .accessibilityLabel("\(task.title), extra task, \(Money.format(task.rewardPence))")
        .accessibilityValue(task.isDone ? String(localized: "Done") : String(localized: "Not done"))
        .accessibilityHint(task.isDone ? String(localized: "Double-tap if it wasn't done.") : String(localized: "Double-tap when it's done."))
        .accessibilityAction(named: "Change", edit)
        .accessibilityAction(named: "Remove", delete)
    }
}
