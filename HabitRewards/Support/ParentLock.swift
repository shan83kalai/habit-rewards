import Foundation
import LocalAuthentication
import Observation

/// Gate for parent-only actions: settings, changing earlier months, and recording payments.
/// Unlocks with Face ID (or the device passcode) and stays unlocked until `lock()`, which the
/// app calls when it goes to the background.
@Observable
final class ParentLock {
    private(set) var isUnlocked = false

    @ObservationIgnored private let check: (String) async -> Bool
    @ObservationIgnored private var checkInProgress: Task<Bool, Never>?

    /// - Parameter check: Asks the parent to prove it's them, given the reason to show.
    init(check: @escaping (String) async -> Bool = ParentLock.deviceOwnerCheck) {
        self.check = check
    }

    /// `true` straight away if unlocked; otherwise asks for Face ID or the passcode.
    /// Taps made while the prompt is showing wait for the same answer instead of asking again.
    @discardableResult
    func authorize(reason: String) async -> Bool {
        if isUnlocked { return true }
        if let checkInProgress { return await checkInProgress.value }

        let task = Task { await check(reason) }
        checkInProgress = task
        let allowed = await task.value
        checkInProgress = nil
        isUnlocked = allowed
        return allowed
    }

    func lock() {
        isUnlocked = false
    }

    /// Face ID, Touch ID or the device passcode. A device with no passcode has nothing to
    /// check against, so the parent is let through (Settings says so).
    static func deviceOwnerCheck(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return error?.code == LAError.passcodeNotSet.rawValue
        }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }

    static var deviceHasPasscode: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// UI tests can't use Face ID: `-uiTesting` approves every check, unless `-denyParentUnlock` is also passed.
    static func forCurrentProcess() -> ParentLock {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-uiTesting") else { return ParentLock() }
        let allowed = !arguments.contains("-denyParentUnlock")
        return ParentLock { _ in allowed }
    }

    /// Approves every check, for SwiftUI previews.
    static var preview: ParentLock {
        ParentLock { _ in true }
    }
}

extension ParentLock {
    /// What the Face ID / passcode prompt says.
    enum Reason {
        static var earlierMonth: String { String(localized: "Unlock to change an earlier month.") }
        static var payment: String { String(localized: "Unlock to record a payment.") }
        static var settings: String { String(localized: "Unlock parent settings.") }
    }

    /// Runs `change` straight away for days in this month; for an earlier month, only once a parent has unlocked.
    func allowChange(to day: Date, navigation: DayNavigation, _ change: @escaping () -> Void) {
        guard navigation.isInEarlierMonth(day) else {
            change()
            return
        }
        Task {
            if await authorize(reason: Reason.earlierMonth) { change() }
        }
    }
}
