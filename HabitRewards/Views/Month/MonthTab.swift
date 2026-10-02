import SwiftData
import SwiftUI

/// The month as a spreadsheet for one child.
struct MonthTab: View {
    @Binding var month: CalendarMonth
    let navigation: DayNavigation

    @Query(filter: #Predicate<Child> { !$0.isArchived }, sort: \Child.sortOrder)
    private var children: [Child]

    /// Shared with the Today tab, so both show the same child.
    @AppStorage("selectedChildID") private var selectedChildID = ""

    var body: some View {
        NavigationStack {
            Group {
                if let child = children.selected(id: selectedChildID) {
                    ScrollView {
                        VStack(spacing: 20) {
                            ChildSwitcher(children: children, selectedID: child.id) { selectedChildID = $0.id.uuidString }
                            MonthNavigator(month: $month, current: navigation.currentMonth)
                            MonthGridView(child: child, month: month, navigation: navigation)
                        }
                        .padding()
                    }
                    .familySyncRefreshable()
                    .tint(Color(hex: child.colourHex))
                } else {
                    NoChildrenView()
                }
            }
            .navigationTitle("Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if month != navigation.currentMonth {
                    Button("This month") { month = navigation.currentMonth }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var month = DayNavigation(today: .now).currentMonth
    MonthTab(month: $month, navigation: DayNavigation(today: .now))
        .modelContainer(.preview)
        .environment(ParentLock.preview)
}
