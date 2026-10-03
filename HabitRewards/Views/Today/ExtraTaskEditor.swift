import Foundation
import SwiftData
import SwiftUI

/// Sets an extra task for one or more children on a day (`task == nil`), or changes or removes one.
struct ExtraTaskEditor: View {
    let task: ExtraTask?
    /// The child on screen: the one a new task is for unless others are ticked too.
    let child: Child
    let day: Date
    /// The day's month rules, for the quick-pick amounts.
    let rules: ScoringRules
    let calendar: Calendar

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Child> { !$0.isArchived }, sort: \Child.sortOrder) private var children: [Child]

    @State private var title: String
    /// One of the quick picks, or `nil` for a typed amount.
    @State private var pickedPence: Int?
    @State private var typedAmount: String
    @State private var chosen: Set<UUID>
    @State private var saveFailed = false
    @FocusState private var typingAmount: Bool

    init(task: ExtraTask?, child: Child, day: Date, rules: ScoringRules, calendar: Calendar) {
        self.task = task
        self.child = child
        self.day = day
        self.rules = rules
        self.calendar = calendar
        let picks = Self.quickPicks(for: rules)
        let reward = task?.rewardPence ?? picks[1]
        _title = State(initialValue: task?.title ?? "")
        _pickedPence = State(initialValue: picks.contains(reward) ? reward : nil)
        _typedAmount = State(initialValue: picks.contains(reward) ? "" : Money.editable(reward))
        _chosen = State(initialValue: [child.id])
    }

    /// 1×, 2× and 4× the month's reward per habit: 50p, £1 and £2 with the standard rules.
    static func quickPicks(for rules: ScoringRules) -> [Int] {
        let base = rules.rewardPence > 0 ? rules.rewardPence : ScoringRules.standard.rewardPence
        return [base, base * 2, base * 4]
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var rewardPence: Int? {
        let pence = pickedPence ?? Money.pence(fromTyped: typedAmount)
        return pence.flatMap { $0 > 0 ? $0 : nil }
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && rewardPence != nil && (task != nil || !chosen.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Wash the car", text: $title)
                        .accessibilityIdentifier("extraTaskName")
                } header: {
                    Text("Task")
                } footer: {
                    Text("For \(day.formatted(.dateTime.weekday(.wide).day().month(.wide))) only.")
                }
                Section {
                    Picker("Reward", selection: $pickedPence) {
                        ForEach(Self.quickPicks(for: rules), id: \.self) { pence in
                            Text(Money.format(pence)).tag(Optional(pence))
                        }
                        Text("Other").tag(Int?.none)
                    }
                    .pickerStyle(.segmented)
                    if pickedPence == nil {
                        TextField("Amount", text: $typedAmount, prompt: Text(Money.format(0)))
                            .keyboardType(.decimalPad)
                            .focused($typingAmount)
                            .accessibilityIdentifier("extraTaskAmount")
                    }
                } header: {
                    Text("Reward")
                } footer: {
                    Text("Added to the day once it's done. Nothing is taken off if it isn't.")
                }
                if task == nil && children.count > 1 {
                    Section("For") {
                        ForEach(children) { option in
                            Button { toggle(option) } label: {
                                HStack {
                                    Circle()
                                        .fill(Color(hex: option.colourHex))
                                        .frame(width: 14, height: 14)
                                    Text(option.name)
                                    Spacer()
                                    if chosen.contains(option.id) {
                                        Image(systemName: "checkmark")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .tint(.primary)
                            .accessibilityAddTraits(chosen.contains(option.id) ? .isSelected : [])
                        }
                    }
                }
                if task != nil {
                    Section {
                        Button("Remove task", systemImage: "trash", role: .destructive, action: remove)
                    }
                }
            }
            .navigationTitle(task == nil ? "New extra task" : "Extra task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
                if typingAmount {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { typingAmount = false }
                    }
                }
            }
            .alert("Couldn't save the task", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func toggle(_ option: Child) {
        if chosen.contains(option.id) {
            chosen.remove(option.id)
        } else {
            chosen.insert(option.id)
        }
    }

    private func save() {
        guard let rewardPence else { return }
        if let task {
            task.title = trimmedTitle
            task.rewardPence = rewardPence
            task.touch()
        } else {
            for option in children where chosen.contains(option.id) {
                ExtraTask.add(trimmedTitle, rewardPence: rewardPence, for: option, on: day, calendar: calendar, in: context)
            }
        }
        commit()
    }

    private func remove() {
        guard let task else { return }
        let name = task.cloudRecordName
        context.delete(task)
        commit(deleted: [name])
    }

    private func commit(deleted: [String] = []) {
        do {
            try context.save()
            LocalChanges.post(deleted: deleted)
            dismiss()
        } catch {
            context.rollback()
            saveFailed = true
        }
    }
}
