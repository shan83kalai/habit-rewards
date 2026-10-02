import Foundation
import UserNotifications

/// A time of day for the reminder, stored as minutes since midnight.
nonisolated struct ReminderTime: Hashable, Sendable {
    let hour: Int
    let minute: Int

    static let standard = ReminderTime(hour: 19, minute: 30)

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// Wraps into 00:00–23:59.
    init(minutesSinceMidnight minutes: Int) {
        let wrapped = ((minutes % 1_440) + 1_440) % 1_440
        self.init(hour: wrapped / 60, minute: wrapped % 60)
    }

    init(date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    var minutesSinceMidnight: Int {
        hour * 60 + minute
    }

    /// This time of day on `day`, for a time picker.
    func date(on day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}

/// The local "Have you ticked today's habits?" notification. It repeats every day, on this phone only.
nonisolated enum DailyReminder {
    static let identifier = "daily-habit-reminder"
    /// `@AppStorage` keys.
    static let enabledKey = "reminderEnabled"
    static let timeKey = "reminderMinutes"

    static func request(at time: ReminderTime) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.body = String(localized: "Have you ticked today's habits?")
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: time.hour, minute: time.minute), repeats: true)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    /// Asks for permission if needed, then schedules the reminder (replacing any earlier one).
    /// Returns `false` if notifications are turned off for the app.
    static func schedule(at time: ReminderTime) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return false }
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        do {
            try await center.add(request(at: time))
            return true
        } catch {
            return false
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
