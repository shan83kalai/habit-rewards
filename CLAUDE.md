# Habit Rewards

Family iPhone app replacing the habits spreadsheet. The full spec is in [PLAN.md](PLAN.md); read it first and build one phase at a time, stopping for review after each. Commit each phase before starting the next.

## Status

- Phases 1–5 done 2026-10-02:
  1. foundation;
  2. Today screen;
  3. month grid, summary and payouts;
  4. settings, parent lock and rules snapshot;
  5. polish: reminders, CSV/PDF export, JSON backup and restore, Dynamic Type, accessibility audit, app icon.
- Phase 6 done 2026-10-02:
  - The "Today's rewards" widget (small, medium, lock screen).
  - Family sharing between the parents' phones, on CloudKit with `CKSyncEngine` and a zone-wide share.
  - Tested for real: the owner was Shan's iPhone and the participant was a simulator on a different Apple ID. Ticks synced both ways.
  - Pull-to-refresh, and a check every 60 seconds while the app is open.
  - See [FAMILY_SHARING.md](FAMILY_SHARING.md).
- Public release prep, 2026-10-02:
  - New installs start with "Child 1", "Child 2" and six general habits. Existing phones keep their own data.
  - Money shows in the phone's own currency.
  - `docs/` holds the privacy, support and home pages, served by GitHub Pages.
- Version 1.1, 2026-10-03:
  - Phase 1: habits for some children only.
  - Phase 2: extra tasks, one-off rewarded tasks for a child on a day.
- `RootView` holds the Today / Month / Summary / Settings tabs. It owns "today" and the `ParentLock`.

## Layout and identifiers

- `HabitRewards/` is app-only.
- `Shared/` is compiled into both the app and the widget: models, scoring, money and dates, `AppSchema`, `StoreLocation`, `DayBoard`, and the widget's views.
- `HabitRewardsWidget/` holds the widget extension's entry point.
- Identifiers:
  - Bundle ID `ltd.kalai.HabitRewards`, widget `ltd.kalai.HabitRewards.Widget`
  - App Group `group.ltd.kalai.HabitRewards`
  - iCloud container `iCloud.ltd.kalai.HabitRewards`
- Team `QNT3QDV7BA` (Shan Nagarajan, paid, Individual) is set on every target. The App IDs, App Group and iCloud container are registered, along with Shan's iPhone 16 Pro.

## Build and test

`xcode-select` points at Xcode, so plain `xcodebuild` works:

```bash
xcodebuild -project HabitRewards.xcodeproj -scheme HabitRewards -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' test
```

The iOS 26.5 and 27.0 simulator runtimes are installed. Include `OS=` in the destination, because some device names (e.g. "iPhone 17") exist under both runtimes. Simulator UDIDs change when devices are recreated, so select by name. Use `-only-testing:HabitRewardsTests` for the fast unit tests only. If `xcodebuild` hangs after the tests have finished, it's stuck collecting simulator diagnostics (`collectSimulatorDiagnostics`); add `-collect-test-diagnostics never`.

`HabitRewardsUITests` taps through every tab, runs Apple's accessibility audit, and attaches screenshots. It launches the app with `-uiTesting`, which gives it an in-memory store. To view the screenshots, run `xcrun xcresulttool export attachments --path <result.xcresult> --output-path <dir>`. This checks the UI without access to the simulator panel. `testScreensInDarkMode` switches to dark with `XCUIDevice.shared.appearance`. That only reaches the real simulator, not the parallel test clones, so run it with `-parallel-testing-enabled NO` to get dark screenshots. The accessibility audit ignores issues it can't attribute to any element, which come from system-drawn Form parts and glass bars. It also ignores elements scrolled under the tab bar. Everything else must pass.

The project uses file-system-synchronised groups: new files in `HabitRewards/`, `Shared/`, `HabitRewardsWidget/`, `HabitRewardsTests/` or `HabitRewardsUITests/` join their target automatically, with no `project.pbxproj` edits. `Shared/` belongs to both the app and the widget targets. Each target's `Info.plist` is excluded from its folder's membership.

The app icon is drawn by `Tools/make_icon.swift`: the gradient, the tick, and a gold coin with a star (the main icon) or a currency symbol. Compile it with `xcrun swiftc -o /tmp/make_icon Tools/make_icon.swift`; the `swift` script runner crashes on it. Then run `/tmp/make_icon <out.png> [symbol]`; the symbol defaults to ★.
- The main icon is `AppIcon` (★). Parents can switch to `AppIcon-GBP`, `-USD`, `-EUR`, `-INR` or `-JPY` in Settings → App icon (`AppIconSection`, `AppIconChoice`).
- To add a coin: add its `AppIcon-<code>.appiconset`, plus an `IconPreview-<code>.imageset` at 180 px (the picker can't load app icon sets as images). Add the name to `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in both app configurations, and add a case to `AppIconChoice`.
- `docs/icon.png` is the star icon at 180 px.

## Release (TestFlight)

App Store Connect app: "Habit Rewards Family". Build 1.0 (1) was uploaded 2026-10-02, 1.0 (2) on 2026-10-03 (generic starter data, any currency), 1.0 (3) on 2026-10-03 (star icon with currency coins to choose, Settings label fix), 1.1 (4) on 2026-10-03 (habits for some children only; the Habit.childIDs field was deployed to Production first), and 1.1 (5) on 2026-10-03 (extra tasks; the ExtraTask record type was created in Development by hand and deployed first). For each new upload, raise `CURRENT_PROJECT_VERSION` in all 8 configurations first; App Store Connect refuses a repeated build number. Then:

```bash
xcodebuild archive -project HabitRewards.xcodeproj -scheme HabitRewards -configuration Release -destination 'generic/platform=iOS' -archivePath /tmp/HabitRewards.xcarchive -allowProvisioningUpdates
xcodebuild -exportArchive -archivePath /tmp/HabitRewards.xcarchive -exportOptionsPlist Tools/ExportOptions.plist -exportPath /tmp/HabitRewardsExport -allowProvisioningUpdates
```

App Store screenshots: `AppStore/Screenshots/`, made by `AppStoreScreenshots` (UI tests) from a demo family (`DemoData`, loaded only with `-uiTesting -demoData`). It's skipped unless `TEST_RUNNER_SCREENSHOTS=1`. Run it alone on the iPhone 18 Pro Max simulator (1320 × 2868, the 6.9-inch size) with `-parallel-testing-enabled NO`, after `xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100`, then export the attachments.

`Tools/ExportOptions.plist` uploads straight to App Store Connect, using Apple-managed distribution signing through the Xcode account. On export, Xcode switches `aps-environment` and the iCloud environment to production. **Before any upload that adds or changes a synced field or record type,** deploy the CloudKit schema from Development to Production in the CloudKit Console; otherwise release builds can't save the new fields. TestFlight builds expire after 90 days.

## Where data lives

- Everything is in one SwiftData store in the App Group folder: `<group>/Library/Application Support/default.store`, so the widget can read it (`StoreLocation`). Earlier versions kept it in the app's own folder, and `AppSchema.makeContainer` moves it across once. SwiftData's own CloudKit mirroring stays off (`cloudKitDatabase: .none`). Family sharing is the app's own `FamilySync`.
- Family sharing state (role, engine state, and the change token for the direct zone fetch) is in `FamilySync.json`, in the app's own Application Support folder.
- A few per-phone preferences are in `UserDefaults`: the selected child, and the reminder on/off and time.
- Nothing leaves the phone except a backup or export file the parent saves or shares.

## Conventions

- Money is always `Int` in the currency's smallest unit, called "pence" in the code: 175 is £1.75, $1.75 or ¥175.
  - `Money` formats amounts in the phone's currency (`Locale.current`). Only views and exports call it.
  - Exports use the report's `currencyCode`: CSV and PDF numbers via `MonthReport.csvMoney` ("1.75"), headings via `currencySymbol`.
  - Rules are typed or stepped by 5 units in `MoneyStepper`.
  - Unit tests pass a currency and locale explicitly. UI tests launch with `-AppleLocale en_GB`, so they always see pounds.
- `Scoring/` is pure Swift with no imports, marked `nonisolated` (the app target defaults to MainActor isolation). All scoring maths lives in `ScoringEngine` and has unit tests.
- Write and change `DayEntry` only through `DayEntry.upsert(...)`. It keeps the (child, day, habit) key unique and inserts before setting relationships. Day strings ("2026-10-02") come from `DayEntry.dayString` and `DayEntry.date(fromDayString:)`; the key and the backup both use them.
- SwiftData status is stored as `statusRaw: String` so it works in `#Predicate`.
- Sync bookkeeping: every model is `Syncable`, with `modifiedAt`, `syncedAt` and `cloudSystemFields`. **Every local write must call `model.touch()` and then `LocalChanges.post()` after saving.** Deletions pass their `cloudRecordName`s to `LocalChanges.post(deleted:)`. Records arriving from iCloud go through `SyncApplier.apply`, which never touches or posts, so they aren't sent back out.
- Record names are fixed (`child-<id>`, `habit-<id>`, `rules-YYYY-MM`, `entry_<child>_<day>_<habit>`, `payout-<id>`, `extra-<id>`), so both phones write the same record and never duplicate. The `DayEntry.key` unique constraint stays: sync goes through our own code, not SwiftData's CloudKit mirroring.
- `CKSyncEngine` only fetches at launch, on return to the foreground, or on a push. Simulators never get pushes, and a phone that stays open can miss them. So `FamilySync.syncNow()` (pull to refresh, `.active`, and every 60 seconds while open) also reads the Family zone directly with `recordZoneChanges`, keeping its own `pollToken`.
- `UIBackgroundModes` (remote-notification) and `CKSharingSupported` must be in `HabitRewards/Info.plist`. The `INFOPLIST_KEY_UIBackgroundModes` build setting is ignored, and without the key CloudKit pushes never arrive.
- Release: `PrivacyInfo.xcprivacy` declares no tracking and no collected data, plus `UserDefaults` (reason CA92.1). `ITSAppUsesNonExemptEncryption = NO` is set, so uploads skip the export-compliance question.
- While sharing is on, first-launch seeding is skipped (the family's data arrives from iCloud) and backup restore is blocked.
- Tests that touch SwiftData subclass `SwiftDataTestCase`. It keeps every container it opens alive for the whole test.
- Each screen's derived numbers live in a plain struct next to its views (e.g. `Views/Today/DayBoard.swift`), so they can be unit-tested without SwiftUI.
- Haptics fire on a per-tap `HabitTap` value, not on status changes, so switching child, day or month stays silent. Save taps with `ModelContext.saveStatus(...)` and attach `.habitTapFeedback(...)`.
- Extra tasks (`ExtraTask`) are one-off tasks for one child on one day, with their own reward fixed when set.
  - A task stores `day` ("2026-10-03") for sync and backups, and `date` (the start of that day) for fetching a month.
  - Done adds the reward to that day; not done costs nothing.
  - A day's score is the habits' score floored at £0, then the done extras on top (`ScoringEngine.dayScore(_:extrasPence:)`). Perfect days and streaks count habits only.
  - `DayBoard` and `MonthSheet` take `extraTasks`, so the Today screen, month grid, summary, widget and exports all agree.
  - Setting, changing or removing a task needs `ParentLock.authorize(reason: .extraTask)`. Ticking one works like a habit (`allowChange`).
  - Tasks are added for the day shown on the Today screen, so only today or earlier.
  - Synced as record type `ExtraTask`, linked to the child by `childID` like `Payout`. Backups are version 3.
- A month can have several `Payout`s, so a top-up after late ticks doesn't overwrite the first payment. `PayoutStatus` works out paid, still owed and overpaid.
- Rules: a month uses its own `MonthRules` row, otherwise the latest earlier one, otherwise `.standard` (see `MonthRules.rules(for:from:)`). `RootView` calls `ensureSnapshot` at launch and whenever a new month starts. Settings can edit only this month and next.
- Parent lock: Settings, any change to an earlier month (`ParentLock.allowChange`), and Mark as paid / Undo all go through `ParentLock.authorize`. It locks on `.background`, not `.inactive`, because the Face ID prompt itself makes the app inactive. In UI tests, `-uiTesting` approves every check and adding `-denyParentUnlock` refuses them.
- In Settings, every sheet, alert, file picker and dialog is presented from the `Form`. A presentation attached to a `Section` inside a `Form` never shows, so sections take closures (`edit`, `saveFailed`, `request`) instead.
- Habits can be for some children only: `Habit.childIDs`, where empty means everyone, including children added later. It's edited in the habit editor's "For" section through `HabitAudience`.
  - Whether a habit counts for a child on a day is decided only by `Habit.counts(for:withStatus:)`. It counts if it's active and one of theirs; otherwise only on days it was ticked.
  - Turning a habit off, or taking it away from a child, never changes history. The Today screen and the month grid both use this rule, so their totals agree.
  - In iCloud, an empty `childIDs` is sent as no value, and no value reads back as everyone. CloudKit returns empty lists as nil, and older versions never set the field.
- Export: `MonthReport` is a `Sendable` snapshot of the month built from `MonthSheet`s. The `CSVExport` and `PDFExport` transferables build their files only when the user shares. The PDF has one A4 landscape page per child.
- Backup (`Persistence/Backup.swift`) is versioned JSON. Restore checks the whole file before deleting anything, then replaces everything in one save, rolling back on failure.
- Small text uses `.subtle` (`Views/Shared/SubtleText.swift`) rather than `.secondary`, because the system grey fails the contrast audit at caption sizes. Stat tiles and child buttons sit in `TileRow`, which stacks them at accessibility text sizes.
