import CloudKit
import SwiftUI
import UIKit

/// Apple's sheet for inviting the other parent (by Messages, Mail or a link) and managing who's in.
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        // Invite only: no public link, and whoever joins can tick and pay like the owner.
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func itemTitle(for csc: UICloudSharingController) -> String? {
            String(localized: "Habit Rewards family")
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {}

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            FamilySync.shared.ownerStoppedSharing()
        }
    }
}
