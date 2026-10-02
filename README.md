# Habit Rewards Family

An iPhone app for parents. Tick each child's daily habits, and the app turns them into pocket money.

- Each habit done earns a reward, and each habit missed takes off a penalty. A day never goes below zero, and the month adds up.
- Month grid, payments, CSV and PDF export, a home-screen widget, and daily reminders.
- Optional sharing between both parents' iPhones through their own iCloud (CloudKit), even with different Apple IDs.
- No accounts, ads, analytics or tracking.

Built with SwiftUI and SwiftData, for iOS 17 and later.

- [Privacy policy](https://shan83kalai.github.io/habit-rewards/privacy.html)
- [Support](https://shan83kalai.github.io/habit-rewards/support.html)

## Building

Open `HabitRewards.xcodeproj` in Xcode. To run on a device, set your own team and identifiers, because the iCloud container and App Group are tied to the publisher's team. `CLAUDE.md` describes the layout and conventions, `PLAN.md` the original spec, and `FAMILY_SHARING.md` how sharing works and how to test it.

```bash
xcodebuild -project HabitRewards.xcodeproj -scheme HabitRewards -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' test
```
