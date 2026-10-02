# Family sharing: setup and testing

Family sharing keeps both parents' phones in step through iCloud, even when the parents use different Apple IDs. The parent who starts sharing invites the other parent. Once they accept, both phones see and change the same children, ticks, rules and payments.

## How it works

- Each phone keeps its own SwiftData store. That store is the working copy, so the app works offline.
- The sharing parent's phone (the owner) creates a "Family" zone in their **private** iCloud database and shares the whole zone. The invited parent sees it in their **shared** database.
- Each phone runs a `CKSyncEngine` on its side. Code: `HabitRewards/Sync/FamilySync.swift`.
- Every record has a fixed name, so two phones always write to the same record and never create duplicates:
  - children, habits and payouts use their IDs;
  - rules are named by month (`rules-2026-10`);
  - ticks are named by child + day + habit.
- When both phones change the same record, the newer change wins. The merge logic is in `HabitRewards/Sync/SyncApplier.swift` and is unit-tested in `SyncTests`.
- Joining **replaces** the joining phone's own data with the family's, after a confirmation. The data isn't merged.
- Restoring a backup is blocked while sharing is on, because it would overwrite the other phone too.

## One-time setup (needs your paid developer account)

1. **Xcode → Settings → Accounts:** sign in with the Apple ID of your paid developer account.
2. **Set the Team:** open `HabitRewards.xcodeproj`, then for both the **HabitRewards** and **HabitRewardsWidgetExtension** targets open **Signing & Capabilities** and choose your **Team**. Keep "Automatically manage signing" on.
3. **Let Xcode register the identifiers.** Xcode registers these for your team from the entitlement files:
   - App ID `ltd.kalai.HabitRewards`
   - Widget `ltd.kalai.HabitRewards.Widget`
   - App Group `group.ltd.kalai.HabitRewards`
   - iCloud container `iCloud.ltd.kalai.HabitRewards`

   If the iCloud container shows in red under the iCloud capability, click the refresh button, or tick the container, so Xcode creates it.
4. **Build and run once on a device** to confirm signing works.

Tell Claude your Team ID (10 characters, shown in the developer account) to have it saved in the project for everyone, rather than chosen in Xcode on each Mac.

## Testing with two phones

You need two devices, or two simulators, each signed into a **different** iCloud account: Settings app → sign in. Simulators work, but pushes can be slow on them, so pull to the foreground to sync.

1. **Phone A, the owner:** Settings tab → unlock → **Share with the other parent**. Apple's share sheet opens.
   - Tap **Add Access** and enter the other parent's Apple ID email. The share is "Only invited people", so a link opened by anyone not on that list says *Item Unavailable*.
   - Then tap **Copy Link**, or send it by Messages or Mail.
   - **Invite or manage** reopens the list of participants. The invited person shows as "Invited".
   - To test on a simulator, paste the link into the simulator's Safari, or run `xcrun simctl openurl <device> <link>`.
2. **Phone B:** open the invite link. Habit Rewards opens and asks *"Join … family?"*. Unlock, then **Join**. Phone B's own data is replaced by Phone A's.
3. **Check both directions.** Changes arrive through iCloud's pushes, usually within seconds on real phones. **Pull down** on any tab to fetch straight away. The app also checks every minute while it's open. Simulators often miss pushes.
   - tick a habit on A, and it shows on B;
   - tick on B, and it shows on A;
   - rename a habit, change next month's reward, mark a payment as paid: each should appear on the other phone.
4. **Conflict:** put both phones in Airplane Mode and tick the same habit differently on each. Turn networking back on. Both should settle on the later change.
5. **Widget:** add the "Today's rewards" widget on both phones. It updates after the app goes to the background or a sync arrives.
6. **Leave or stop:**
   - On B, **Leave family**: B keeps a copy and stops updating.
   - Or on A, **Stop sharing**: B is told sharing stopped and keeps its copy.

## Before TestFlight or the App Store

CloudKit creates record types automatically in the **Development** environment the first time each one is saved. Before a TestFlight or App Store build, open the [CloudKit Console](https://icloud.developer.apple.com/), select `iCloud.ltd.kalai.HabitRewards`, and choose **Deploy Schema Changes** to Production. Otherwise the release build can't save records.

## Known limits

- One owner phone. A second device on the owner's own Apple ID doesn't join automatically.
- Clocks: "newer change wins" uses each phone's clock, so a phone with a badly wrong clock could win when it shouldn't.
