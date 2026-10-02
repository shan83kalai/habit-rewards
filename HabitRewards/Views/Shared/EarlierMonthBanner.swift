import SwiftUI

/// Shown above an earlier month while the parent lock is on.
struct EarlierMonthBanner: View {
    @Environment(ParentLock.self) private var parentLock

    var body: some View {
        if !parentLock.isUnlocked {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.orange)
                Text("Earlier months are locked. A parent can unlock them to make changes.")
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Unlock") {
                    Task { await parentLock.authorize(reason: ParentLock.Reason.earlierMonth) }
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(.orange.opacity(0.12), in: .rect(cornerRadius: 12))
        }
    }
}

#Preview {
    EarlierMonthBanner()
        .padding()
        .environment(ParentLock { _ in false })
}
