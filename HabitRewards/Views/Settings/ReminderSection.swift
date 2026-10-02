import Foundation
import SwiftUI

/// The daily "Have you ticked today's habits?" notification on this phone.
struct ReminderSection: View {
    let notificationsOff: () -> Void

    @AppStorage(DailyReminder.enabledKey) private var isEnabled = false
    @AppStorage(DailyReminder.timeKey) private var minutes = ReminderTime.standard.minutesSinceMidnight

    private var time: ReminderTime {
        ReminderTime(minutesSinceMidnight: minutes)
    }

    var body: some View {
        Section {
            Toggle("Daily reminder", isOn: Binding(get: { isEnabled }, set: setEnabled))
            if isEnabled {
                DatePicker("Time", selection: timeOfDay, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Reminder")
                .foregroundStyle(.subtle)
        } footer: {
            if isEnabled {
                Text("“Have you ticked today's habits?” every day at \(time.date(on: .now, calendar: .current).formatted(date: .omitted, time: .shortened)) on this phone.")
                    .foregroundStyle(.subtle)
            } else {
                Text("A daily nudge on this phone to tick off the day's habits.")
                    .foregroundStyle(.subtle)
            }
        }
    }

    private var timeOfDay: Binding<Date> {
        Binding {
            time.date(on: .now, calendar: .current)
        } set: { date in
            minutes = ReminderTime(date: date, calendar: .current).minutesSinceMidnight
            schedule()
        }
    }

    private func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            schedule()
        } else {
            DailyReminder.cancel()
        }
    }

    private func schedule() {
        let time = time
        Task {
            guard await DailyReminder.schedule(at: time) else {
                isEnabled = false
                notificationsOff()
                return
            }
        }
    }
}
