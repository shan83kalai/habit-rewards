import SwiftUI

extension View {
    /// Pull down to fetch the other phone's changes (and send this phone's) straight away.
    /// Only while family sharing is on; otherwise there's nothing to refresh.
    func familySyncRefreshable() -> some View {
        modifier(FamilySyncRefreshable())
    }
}

private struct FamilySyncRefreshable: ViewModifier {
    func body(content: Content) -> some View {
        if FamilySync.shared.isSharing {
            content.refreshable { await FamilySync.shared.syncNow() }
        } else {
            content
        }
    }
}
