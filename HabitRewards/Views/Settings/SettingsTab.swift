import SwiftData
import SwiftUI

/// Parent-only settings. Asks for Face ID or the passcode when opened while locked.
struct SettingsTab: View {
    let navigation: DayNavigation

    @Environment(ParentLock.self) private var parentLock

    var body: some View {
        NavigationStack {
            Group {
                if parentLock.isUnlocked {
                    SettingsForm(navigation: navigation)
                } else {
                    LockedSettingsView()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Which editor sheet is open. `nil` inside means adding a new one.
enum SettingsEditor: Identifiable {
    case habit(Habit?)
    case child(Child?)

    var id: String {
        switch self {
        case .habit(let habit): "habit-\(habit?.id.uuidString ?? "new")"
        case .child(let child): "child-\(child?.id.uuidString ?? "new")"
        }
    }
}

/// Alerts raised by the Settings sections.
enum SettingsNotice: Identifiable {
    case saveFailed
    case notificationsOff

    var id: Self { self }

    var title: String {
        switch self {
        case .saveFailed: String(localized: "Couldn't save that change")
        case .notificationsOff: String(localized: "Notifications are off")
        }
    }

    var message: String {
        switch self {
        case .saveFailed: String(localized: "Please try again.")
        case .notificationsOff: String(localized: "Turn on notifications for Habit Rewards in the Settings app, then try again.")
        }
    }
}

private struct SettingsForm: View {
    let navigation: DayNavigation

    @Environment(ParentLock.self) private var parentLock
    // Sheets, alerts and file pickers are all presented from the Form itself: any
    // presentation attached to a `Section` inside a `Form` never shows.
    @State private var editor: SettingsEditor?
    @State private var notice: SettingsNotice?
    @State private var backupRequest: BackupRequest?
    @State private var familyRequest: FamilySharingRequest?

    var body: some View {
        Form {
            RulesSection(navigation: navigation) { notice = .saveFailed }
            HabitsSection { editor = .habit($0) }
            ChildrenSection { editor = .child($0) }
            FamilySharingSection { familyRequest = $0 }
            ReminderSection { notice = .notificationsOff }
            BackupSection { backupRequest = $0 }
            Section {
                Button("Lock parent settings", systemImage: "lock.fill") { parentLock.lock() }
            } footer: {
                if ParentLock.deviceHasPasscode {
                    Text("Settings, payments and earlier months lock again whenever the app is closed.")
                        .foregroundStyle(.subtle)
                } else {
                    Text("This phone has no passcode, so anyone can open parent settings. Set one in the Settings app to lock them.")
                        .foregroundStyle(.subtle)
                }
            }
        }
        .familySyncRefreshable()
        .toolbar { EditButton() }
        .sheet(item: $editor) { editor in
            switch editor {
            case .habit(let habit): HabitEditor(habit: habit)
            case .child(let child): ChildEditor(child: child)
            }
        }
        .alert(
            notice?.title ?? "",
            isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } }),
            presenting: notice
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { notice in
            Text(notice.message)
        }
        .backupFlow($backupRequest)
        .familySharingFlow($familyRequest)
    }
}

private struct LockedSettingsView: View {
    @Environment(ParentLock.self) private var parentLock

    var body: some View {
        ContentUnavailableView {
            Label("Parents only", systemImage: "lock.fill")
        } description: {
            Text("Unlock with Face ID or your passcode to change rewards, habits and children.")
        } actions: {
            Button("Unlock") {
                Task { await parentLock.authorize(reason: ParentLock.Reason.settings) }
            }
            .buttonStyle(.borderedProminent)
        }
        .task { await parentLock.authorize(reason: ParentLock.Reason.settings) }
    }
}

#Preview {
    SettingsTab(navigation: DayNavigation(today: .now))
        .modelContainer(.preview)
        .environment(ParentLock.preview)
}
