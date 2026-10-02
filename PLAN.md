# Daily Habits Reward Tracker — iPhone App Plan

## 1. Goal

A private family iPhone app that tracks six daily habits for each child, scores each day (+50p per habit done, −75p per habit missed, floored at £0), and totals the month for payout. It replaces the October 2026 spreadsheet.

## 2. Tech stack

- Language/UI: Swift 5.9+, SwiftUI
- Minimum iOS: 17.0 (needed for SwiftData and the Observation framework)
- Storage: SwiftData, on device only. No accounts, no backend, no analytics.
- Auth: LocalAuthentication (Face ID / passcode) for the parent area
- Notifications: UserNotifications for local reminders
- Tests: XCTest for unit tests; an optional UI test target
- Architecture: MVVM-light. Put the scoring logic in a pure `ScoringEngine` struct with no SwiftUI or SwiftData imports, so it is fully unit-testable.

## 3. Core rules (must be exact)

- Each habit on each day has one of three states: `done`, `missed`, `unset`.
- Day score = max(0, done × reward − missed × penalty).
- `unset` counts as nothing (same as a blank cell in the spreadsheet).
- Month total = sum of that month's day scores.
- Defaults: reward = 50p, penalty = 75p, six habits, so the best day is £3.00.
- Store all money as integer pence (`Int`), never `Double`. Format as currency only in the UI, in the phone's own currency.
- Reward and penalty are saved per month (snapshot when the month starts), so changing them later doesn't rewrite past months' payouts.

## 4. Data model (SwiftData)

```
Child        id, name, colourHex, sortOrder, isArchived
Habit        id, title, sfSymbol, sortOrder, isActive
MonthRules   id, year, month, rewardPence, penaltyPence
DayEntry     id, child, date (normalised to start of day), habit, status (enum: done/missed/unset)
Payout       id, child, year, month, amountPence, paidOn (Date?)
```

- Make `DayEntry` unique on (child, date, habit).
- Deactivating a habit hides it from new days but keeps its history.
- Seed data on first launch: children "Child 1" and "Child 2" (parents rename them in Settings), plus six starter habits: Homework, Reading, Brush teeth, Bed on time, Tidy room, Exercise.

## 5. Screens

1. **Today (home screen)**
   - A child switcher at the top (segmented control or avatars).
   - Six large habit rows. Tap once for done (green tick), twice for missed (red cross), three times to clear.
   - Live "Today: £x.xx" and "This month: £x.xx" shown at the top.
   - Arrows to move to previous days for catch-up entry. Future days are locked.
2. **Month grid**
   - A copy of the spreadsheet: habits as rows, days as columns, scrollable horizontally.
   - Day-score row, running total, month total, and a count of perfect days.
   - Tap a cell to edit (changes to past months need parent unlock).
3. **Summary / payout**
   - Per child: month total, perfect days, a streak, and the best habit and the most-missed habit.
   - A "Mark as paid" button that records a `Payout`.
   - A share sheet that exports the month as CSV or PDF.
4. **Settings (parent-locked)**
   - Edit the reward and penalty for the current or next month.
   - Add, rename, reorder or deactivate habits and children.
   - Reminder time (default 19:30): "Have you ticked today's habits?"
   - Backup and restore as a JSON export through the Files app.

## 6. Build phases (one Claude Code session each)

**Phase 1 — Foundation**
- Xcode project, folder structure, SwiftData models, seed data.
- `ScoringEngine` with unit tests: 6 done = 300p; 5 done + 1 missed = 175p; 2 done + 4 missed = 0 (floor); all unset = 0; month sum; custom reward and penalty.

**Phase 2 — Today screen**
- Habit toggling, live totals, day navigation, haptics on tap.

**Phase 3 — Month grid + summary**
- Grid view, running totals, the payout record.

**Phase 4 — Settings + parent lock**
- Face ID gate, editing habits, children and rules, the per-month rules snapshot.

**Phase 5 — Polish**
- Local reminders, CSV/PDF export, JSON backup and restore, dark mode, Dynamic Type, accessibility labels, app icon.

**Phase 6 (optional)**
- A home-screen widget (WidgetKit) showing today's score.
- iCloud sync (SwiftData + CloudKit) so both parents' phones share the data.

## 7. Acceptance checks

- The scoring results match the October spreadsheet exactly for the same inputs.
- A day can never show a negative value.
- Changing the penalty in November doesn't change October's total.
- The app works fully offline and nothing leaves the device (unless iCloud sync is added).
- Every scoring function is covered by unit tests, and all tests pass.

## 8. Instructions for Claude Code

- Read this file first. Build one phase at a time and stop for review at the end of each phase.
- Write the unit tests for `ScoringEngine` before writing the UI.
- No third-party packages unless they are justified.
- Keep views small. Previews should use an in-memory SwiftData container with sample data.
