import SwiftUI

/// The live "Today" and "This month" totals.
struct TotalsHeader: View {
    let dayTitle: String
    let dayPence: Int
    let monthTitle: String
    let monthPence: Int

    var body: some View {
        TileRow {
            StatTile(title: dayTitle, value: Money.format(dayPence))
            StatTile(title: monthTitle, value: Money.format(monthPence))
        }
    }
}

#Preview {
    TotalsHeader(dayTitle: "Today", dayPence: 175, monthTitle: "This month", monthPence: 1_250)
        .padding()
}
