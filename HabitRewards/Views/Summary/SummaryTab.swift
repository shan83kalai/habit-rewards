import SwiftData
import SwiftUI

/// Each child's month at a glance, and recording what they've been paid.
struct SummaryTab: View {
    @Binding var month: CalendarMonth
    let navigation: DayNavigation

    @Query(filter: #Predicate<Child> { !$0.isArchived }, sort: \Child.sortOrder)
    private var children: [Child]

    var body: some View {
        NavigationStack {
            Group {
                if children.isEmpty {
                    NoChildrenView()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            MonthNavigator(month: $month, current: navigation.currentMonth)
                            SummaryList(children: children, month: month, navigation: navigation)
                        }
                        .padding()
                    }
                    .familySyncRefreshable()
                }
            }
            .navigationTitle("Summary")
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
    SummaryTab(month: $month, navigation: DayNavigation(today: .now))
        .modelContainer(.preview)
        .environment(ParentLock.preview)
}
