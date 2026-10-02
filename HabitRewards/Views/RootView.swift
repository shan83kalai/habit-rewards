import Foundation
import SwiftData
import SwiftUI
import WidgetKit

/// The four tabs. Owns "today" so every tab moves on together at midnight, and the parent lock
/// so it locks again whenever the app goes to the background.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigation = DayNavigation(today: .now)
    /// Shared by the Month and Summary tabs.
    @State private var month = DayNavigation(today: .now).currentMonth
    @State private var parentLock = ParentLock.forCurrentProcess()

    var body: some View {
        TabView {
            TodayView(navigation: navigation)
                .tabItem { Label("Today", systemImage: "checkmark.circle") }
            MonthTab(month: $month, navigation: navigation)
                .tabItem { Label("Month", systemImage: "tablecells") }
            SummaryTab(month: $month, navigation: navigation)
                .tabItem { Label("Summary", systemImage: Money.systemImage()) }
            SettingsTab(navigation: navigation)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .environment(parentLock)
        .familyInvitePrompt(parentLock: parentLock)
        .onAppear(perform: snapshotRules)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                refreshToday()
                Task { await FamilySync.shared.syncNow() }
            // Not on .inactive: the Face ID prompt itself makes the app inactive.
            case .background:
                parentLock.lock()
                // Ticks made in the app show on the home-screen widget once you leave it.
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetCenter.todayKind)
            default: break
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
                refreshToday()
            }
        }
        .task(id: scenePhase == .active && FamilySync.shared.isSharing) {
            // iCloud's pushes normally bring the other phone's changes; this catches any that are
            // late or missed while the app is open (simulators often miss them).
            guard scenePhase == .active, FamilySync.shared.isSharing else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await FamilySync.shared.syncNow()
            }
        }
    }

    /// Moves "today" on after midnight, or when the app comes back from the background on a new day.
    private func refreshToday() {
        let latest = DayNavigation(today: .now)
        guard latest.today != navigation.today else { return }
        if month == navigation.currentMonth { month = latest.currentMonth }
        navigation = latest
        snapshotRules()
    }

    /// Fixes this month's reward and penalty as it starts. If it fails, scoring still uses the
    /// same carried-forward rules, so it's safe to retry next launch.
    private func snapshotRules() {
        try? MonthRules.ensureSnapshot(for: navigation.currentMonth, in: context)
    }
}

#Preview {
    RootView()
        .modelContainer(.preview)
}
