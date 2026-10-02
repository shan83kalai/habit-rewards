import CloudKit
import UIKit

/// Registers for the silent pushes iCloud sync relies on, and routes family-sharing invitations
/// (which iOS delivers to the scene delegate) to `FamilySync`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// iCloud tells the sync engine about the other phone's changes with silent pushes, which
    /// need a device token. No permission prompt: these never show anything.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    /// The app was launched by tapping an invitation.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            FamilySync.shared.receivedInvite(metadata)
        }
    }

    /// An invitation was tapped while the app was already running.
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        FamilySync.shared.receivedInvite(cloudKitShareMetadata)
    }
}
