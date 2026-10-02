import CloudKit
import SwiftUI

extension View {
    /// Asks before joining a family from an invitation, since joining replaces this phone's data,
    /// and shows a note if sharing ends from the other side.
    func familyInvitePrompt(parentLock: ParentLock) -> some View {
        modifier(FamilyInvitePrompt(parentLock: parentLock))
    }
}

private struct FamilyInvitePrompt: ViewModifier {
    let parentLock: ParentLock

    @State private var problem: String?
    private var sync: FamilySync { .shared }

    func body(content: Content) -> some View {
        @Bindable var sync = sync
        content
            .alert(
                "Join \(ownerName)'s family?",
                isPresented: Binding(get: { sync.pendingInvite != nil }, set: { if !$0 { sync.pendingInvite = nil } }),
                presenting: sync.pendingInvite
            ) { invite in
                Button("Join") { join(invite) }
                Button("Not now", role: .cancel) {}
            } message: { _ in
                Text("This phone's own children, ticks and payments will be replaced by the family's. Make a backup first in Settings if you want to keep them.")
            }
            .alert("Family sharing", isPresented: Binding(get: { sync.notice != nil || problem != nil }, set: { if !$0 { sync.notice = nil; problem = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(sync.notice ?? problem ?? "")
            }
    }

    private var ownerName: String {
        sync.pendingInvite?.ownerIdentity.nameComponents.map { PersonNameComponentsFormatter.localizedString(from: $0, style: .short) }
            ?? String(localized: "the other parent")
    }

    private func join(_ invite: CKShare.Metadata) {
        Task {
            // Joining replaces everything on this phone, so it's a parent's decision.
            guard await parentLock.authorize(reason: String(localized: "Unlock to join the family.")) else { return }
            do {
                try await sync.join(invite)
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}
