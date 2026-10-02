import CloudKit
import SwiftUI

enum FamilySharingRequest: Hashable {
    case share
    case stop
}

/// Sharing the family's data with the other parent's phone through iCloud.
struct FamilySharingSection: View {
    let request: (FamilySharingRequest) -> Void

    private var sync: FamilySync { .shared }

    var body: some View {
        Section {
            switch sync.role {
            case .off:
                Button("Share with the other parent", systemImage: "person.2.badge.plus") { request(.share) }
            case .owner:
                LabeledContent("Sharing", value: String(localized: "On"))
                Button("Invite or manage", systemImage: "person.crop.circle.badge.checkmark") { request(.share) }
                Button("Stop sharing", systemImage: "xmark.circle", role: .destructive) { request(.stop) }
            case .participant(_, let ownerName):
                LabeledContent("Joined", value: ownerName.map { String(localized: "\($0)'s family") } ?? String(localized: "A family"))
                Button("Leave family", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) { request(.stop) }
            }
            if sync.isSharing {
                LabeledContent("Last synced", value: statusText)
            }
        } header: {
            Text("Family sharing")
                .foregroundStyle(.subtle)
        } footer: {
            Text(sync.isSharing
                 ? "Both parents' phones see and change the same children, ticks and payments through iCloud."
                 : "Invite the other parent so both phones share the same children, ticks and payments through iCloud. Their phone takes on this phone's data.")
                .foregroundStyle(.subtle)
        }
    }

    private var statusText: String {
        switch sync.status {
        case .idle: String(localized: "Waiting")
        case .syncing: String(localized: "Syncing…")
        case .synced(let date): date.formatted(date: .omitted, time: .shortened)
        case .problem(let message): message
        }
    }
}

extension View {
    /// Starts sharing and shows the invite sheet, or confirms stopping/leaving.
    func familySharingFlow(_ request: Binding<FamilySharingRequest?>) -> some View {
        modifier(FamilySharingFlow(request: request))
    }
}

private struct FamilySharingFlow: ViewModifier {
    @Binding var request: FamilySharingRequest?

    @State private var share: CKShare?
    @State private var working = false
    @State private var confirmingStop = false
    @State private var problem: String?

    private var sync: FamilySync { .shared }

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _, newRequest in
                guard let newRequest else { return }
                request = nil
                switch newRequest {
                case .share: startSharing()
                case .stop: confirmingStop = true
                }
            }
            .overlay {
                if working { ProgressView().controlSize(.large) }
            }
            .sheet(isPresented: Binding(get: { share != nil }, set: { if !$0 { share = nil } })) {
                if let share {
                    CloudSharingView(share: share, container: sync.container)
                        .ignoresSafeArea()
                }
            }
            .confirmationDialog(
                sync.role == .owner ? "Stop sharing with the other parent?" : "Leave this family?",
                isPresented: $confirmingStop,
                titleVisibility: .visible
            ) {
                Button(sync.role == .owner ? "Stop sharing" : "Leave family", role: .destructive, action: stopSharing)
            } message: {
                Text("This phone keeps its own copy of everything, but the two phones stop updating each other.")
            }
            .alert("Family sharing", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(problem ?? "")
            }
    }

    private func startSharing() {
        working = true
        Task {
            defer { working = false }
            do {
                share = try await sync.startSharing()
            } catch {
                problem = error.localizedDescription
            }
        }
    }

    private func stopSharing() {
        working = true
        Task {
            defer { working = false }
            do {
                try await sync.stopSharing()
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}
