import SwiftUI

struct NoChildrenView: View {
    var body: some View {
        ContentUnavailableView("No children", systemImage: "person.2", description: Text("There's no one to track habits for yet."))
    }
}

#Preview {
    NoChildrenView()
}
