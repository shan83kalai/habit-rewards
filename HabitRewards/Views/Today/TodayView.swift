import Foundation
import SwiftData
import SwiftUI

/// Home screen: pick a child and a day, then tick off habits.
struct TodayView: View {
    let navigation: DayNavigation

    @Query(filter: #Predicate<Child> { !$0.isArchived }, sort: \Child.sortOrder)
    private var children: [Child]

    /// Remembers the last child picked on this phone. Shared with the Month tab.
    @AppStorage("selectedChildID") private var selectedChildID = ""
    @State private var day: Date

    init(navigation: DayNavigation) {
        self.navigation = navigation
        _day = State(initialValue: navigation.today)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let child = children.selected(id: selectedChildID) {
                    ScrollView {
                        VStack(spacing: 20) {
                            ChildSwitcher(children: children, selectedID: child.id) { selectedChildID = $0.id.uuidString }
                            DayNavigator(day: $day, navigation: navigation)
                            DayBoardView(child: child, day: day, navigation: navigation)
                        }
                        .padding()
                    }
                    .familySyncRefreshable()
                    .tint(Color(hex: child.colourHex))
                } else {
                    NoChildrenView()
                }
            }
            .navigationTitle("Habit Rewards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if navigation.relative(day) != .today {
                    Button("Today") { day = navigation.today }
                }
            }
        }
        .onChange(of: navigation.today) { oldToday, newToday in
            // Stay on "Today" across midnight; otherwise keep the chosen day.
            day = day == oldToday ? newToday : navigation.clamped(day)
        }
    }
}

#Preview {
    TodayView(navigation: DayNavigation(today: .now))
        .modelContainer(.preview)
        .environment(ParentLock.preview)
}
