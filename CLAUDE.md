# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## watchOS Target Rules

**Bundle ID must be prefixed by the iOS app's bundle ID:**
- iOS app: `com.tamagoosie.app`
- Watch app: `com.tamagoosie.app.watch` ✅ — never `com.tamagoosie.watch` ❌

**Watch `Info.plist` must contain:**
```xml
<key>WKCompanionAppBundleIdentifier</key>
<string>com.tamagoosie.app</string>
```

**`project.yml` iOS target must embed the Watch target:**
```yaml
TamaGoosie:
  dependencies:
    - target: TamaGoosieWatch
      embed: true
```

**Run the iOS scheme** (`TamaGoosie`), not the Watch scheme, to install both apps on the simulator together.

**`@main` can only appear once per module.** `WatchApp.swift` owns `@main`. Any `Widget` or `WKExtension` entry points must live in a separate extension target — never in the main Watch app target.

---

## Build & Test Commands

The project uses **XcodeGen** to regenerate `TamaGoosie.xcodeproj` from `project.yml`. Always regenerate after modifying `project.yml` or adding new source files via the Python approach below.

```bash
# Regenerate Xcode project (required after project.yml changes)
xcodegen generate

# Build iOS app target
xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

# Run all unit tests
xcodebuild test -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Build watchOS target
xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosieWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  build

# Check available simulators
xcrun simctl list devices available
```

**Important**: When adding new `.swift` files, you have two options:
1. **Preferred**: Add the file path to the relevant `sources:` entry in `project.yml` and run `xcodegen generate`. XcodeGen recursively includes all `.swift` files in source directories.
2. **Manual**: Use a Python script to insert PBXBuildFile, PBXFileReference, group children, and Sources build phase entries into `project.pbxproj`.

## Documentation

Detailed documentation lives in `docs/`:
- `docs/architecture.md` — targets, directory layout, data flow, layer responsibilities
- `docs/stat-system.md` — healthiness/happiness formulas, mood derivation, streak, constants
- `docs/models.md` — all SwiftData `@Model` classes and their fields
- `docs/goose.md` — GooseCharacterView, GooseViewModel, GooseView, Live Activity, Onboarding
- `docs/goals.md` — goal types, GoalListView, GoalViewModel, notifications, categories

## Architecture Overview

TamaGoosie is a **Tamagotchi-style virtual goose** app with three targets:

| Target | Platform | Role |
|--------|----------|------|
| `TamaGoosie` | iOS 26+ | Main app (source of truth) |
| `TamaGoosieWatch` | watchOS 10+ | Read-only mirror via WatchConnectivity |
| `TamaGoosieWidgets` | iOS | Home screen widgets via WidgetKit |
| `TamaGoosieTests` | iOS | XCTest unit tests |

### Stat System

The app uses **exactly 2 stats on a 0.0–1.0 scale** (not 4 stats, not 0-100):

- `healthiness` — weighted composite of HealthKit data (sleep 30%, exercise 30%, steps 25%, sitting 15%; with Watch: adds outside 15%)
- `happiness` — goal completion ratio (65%) + distraction penalty (30%) + base (5%) + streak bonus

Stats are stored as `Double` in `GooseState` and displayed as `Int(stat * 100)` percent in views. The `StatBar` component takes values 0–100.

### Core Data Flow

```
HealthKitManager → GooseEngine → GooseState (SwiftData @Model)
                                      ↓
                               GooseSyncPayload (Codable struct)
                                      ↓
                    ┌─────────────────┼──────────────────┐
               AppGroup           WatchConnectivity    AppGroup
            UserDefaults            WCSession         UserDefaults
                  ↓                     ↓                 ↓
           GooseWidget          WatchSyncReceiver    GooseWidget
```

**iPhone is the sole source of truth.** Watch and Widget are read-only consumers of `GooseSyncPayload`.

### Key Files

**Shared/** — compiled into all three targets:
- `GoosePhase.swift` — `GooseMood` (derivation logic), `GoalCategory`, `GoalFrequency` (no GoosePhase — phases removed)
- `GooseStats.swift` — `GooseSyncPayload` (the cross-target sync struct)
- `SyncPayload.swift` — `GoalSummary` (lightweight goal for Watch/Widget)
- `Constants.swift` — `GoosieConstants` (formula weights, streak constants, focus timer constants, app group ID; no XP or decay constants)

**TamaGoosie/Core/Models/** — SwiftData `@Model` classes:
- `GooseState` — the single goose instance (one row in DB); fields: `healthiness`, `happiness`, `mood`, `streakDays`, `longestStreak`, `lastStreakDate`, `name`, `spriteID`, `hatID`, `colorID`, `lastUpdated`, `createdAt`
- `Goal` — user goals; `type` is `"recurring" | "deadline" | "builtin"`
- `DailyLog` — one row per calendar day, accumulates HealthKit + distraction data; fields: steps, exerciseMinutes, sleepHours, standHours, sittingHours, outsideMinutes, distractionOpens, distractionMinutes, goalsCompleted, goalsTotal, endOfDayHealthiness, endOfDayHappiness (0.0–1.0 snapshots written by `snapshotEndOfDay` or backfilled by `backfillHistory`)
- `DistractionApp` — user-configured distraction apps
- `UserProfile` — user baselines (auto-updated after 7 days of logs) and settings

**TamaGoosie/Core/Services/**:
- `GooseEngine` — singleton orchestrator. Entry point: `GooseEngine.shared.update(state:log:profile:goals:)`, `completeGoal(_:state:log:goals:)`, `uncompleteGoal(_:state:log:goals:)`, `resetGoose(state:)`, `backfillHistory(daysBack:modelContext:profile:goals:)` (populates historical DailyLogs from HealthKit on launch)
- `RewardEngine` — two pure formula functions: `computeHealthiness(log:profile:)` and `computeHappiness(log:goals:)`. No delta mutations.
- `DecayEngine` — **deleted**. Stats do not decay; they are recomputed from real data on every update.

### Sync Architecture

`GooseEngine.saveStatsToAppGroup()` is called after every stat change. It:
1. Writes JSON-encoded `GooseSyncPayload` to `UserDefaults(suiteName: "group.com.tamagoosie")` under key `"gooseStats"` (consumed by Widget)
2. Calls `WatchSyncService.shared.sendPayload()` which updates ApplicationContext and sends a live message if Watch is reachable

The Watch receives payloads via `WatchSyncReceiver` and stores `currentPayload: GooseSyncPayload`.

### Mood Derivation

`GooseMood.deriveMood(healthiness:happiness:)` maps `avg = (healthiness + happiness) / 2`:
- `>= 0.60` → happy, `0.30–0.60` → content
- `0.15–0.30` → sad, `< 0.15` → sick

There is no `dead` mood and no phase system. The goose's mood is the sole visual feedback signal.

### Design System

`GoosieTheme` (enum in `Theme/GoosieTheme.swift`) provides all colors, typography, and spacing constants. `GoosieComponents.swift` contains shared UI primitives: `StatBar`, `PillButton`, `CircleActionButton`, `GoosieCard`, `StreakFlame` (only renders when `days > 0`).

`GooseCharacterView` (in `GooseAnimations.swift`) renders the animated goose. It takes `mood: GooseMood` — do not add additional parameters without updating all call sites across all three targets.

### Notifications

`NotificationManager` respects quiet hours (10pm–7am) and a max of 5 notifications/day. Harold speaks in first person. Notification identifiers: `morning_reminder`, `state_alert_<uuid>`, `goal_<goalID>`, `streak_<days>`, `decay_warning`.

### Important Constraints

- **All stat values are stored 0.0–1.0 in models**, displayed as 0–100 in UI only. Never store percent values in `GooseState`.
- Stats are **computed from formulas, never mutated directly**. Always call `GooseEngine.shared.update(state:log:profile:goals:)` to recompute both stats from the current `DailyLog`.
- **`DailyLog` must exist before stat computation.** Views use `ensureTodayLogExists()` to eagerly create a `DailyLog` for today if one doesn't exist yet (e.g., first launch, new day).
- `GoalSummary.progress` (on sync struct) is 0.0–1.0. `Goal.currentCount`/`targetCount`/`isCompleted` (on SwiftData model) still exist and drive `Goal.progress` computed property.
- The `Shared/` directory is compiled into all three targets. Code there must avoid importing `SwiftData` or any iOS-only frameworks.
- App group ID: `group.com.tamagoosie`. Sync key: `"gooseStats"`.
- Built-in goals have `type == "builtin"`. `GoalViewModel.seedBuiltinGoalsIfNeeded()` checks for their presence before inserting.
- There is no death, revival, XP, levels, or phase progression. `GooseState` has no `isDead`, `level`, `xp`, or `phase` fields.

<!-- convex-ai-start -->
This project uses [Convex](https://convex.dev) as its backend.

When working on Convex code, **always read `convex/_generated/ai/guidelines.md` first** for important guidelines on how to correctly use Convex APIs and patterns. The file contains rules that override what you may have learned about Convex from training data.

Convex agent skills for common tasks can be installed by running `npx convex ai-files install`.
<!-- convex-ai-end -->
