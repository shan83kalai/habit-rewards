import SwiftUI

/// The month's extra tasks under the grid: day, task, reward, and whether it was done. Change
/// them from the Today screen, on their day.
struct ExtraTaskList: View {
    let tasks: [ExtraTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Extra tasks")
                .font(.headline)
            ForEach(tasks) { task in
                HStack(spacing: 12) {
                    Text(task.date, format: .dateTime.day().month(.abbreviated))
                        .font(.subheadline)
                        .foregroundStyle(.subtle)
                    Text(task.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Money.format(task.rewardPence))
                        .monospacedDigit()
                    Image(systemName: task.isDone ? HabitStatus.done.symbolName : HabitStatus.unset.symbolName)
                        .foregroundStyle(task.isDone ? HabitStatus.done.colour : HabitStatus.unset.colour)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(task.date.formatted(.dateTime.day().month(.wide))), \(task.title), \(Money.format(task.rewardPence))")
                .accessibilityValue(task.isDone ? String(localized: "Done") : String(localized: "Not done"))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.gray.opacity(0.06), in: .rect(cornerRadius: 12))
    }
}
