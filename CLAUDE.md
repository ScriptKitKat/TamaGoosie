# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

## Architecture Overview

TamaGoosie is a **Tamagotchi-style virtual goose** app with three targets:

| Target | Platform | Role |
|--------|----------|------|
| `TamaGoosie` | iOS 17+ | Main app (source of truth) |
| `TamaGoosieWatch` | watchOS 10+ | Read-only mirror via WatchConnectivity |
| `TamaGoosieWidgets` | iOS | Home screen widgets via WidgetKit |
| `TamaGoosieTests` | iOS | XCTest unit tests |

### Stat System

The app uses **exactly 2 stats on a 0.0–1.0 scale** (not 4 stats, not 0-100):

- `healthiness` — weighted composite of HealthKit data (sleep 30%, exercise 30%, steps 25%, sitting 15%; with Watch: adds outside 15%)
- `happiness` — goal completion ratio (50%) + distraction penalty (30%) + base (20%) + streak bonus

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
- `GoosePhase.swift` — `GoosePhase`, `GooseMood` (derivation logic), `GoalCategory`, `GoalFrequency`
- `GooseStats.swift` — `GooseSyncPayload` (the cross-target sync struct)
- `SyncPayload.swift` — `GoalSummary` (lightweight goal for Watch/Widget)
- `Constants.swift` — `GoosieConstants` (all magic numbers: decay rates, formula weights, XP curves, app group ID)

**TamaGoosie/Core/Models/** — SwiftData `@Model` classes:
- `GooseState` — the single goose instance (one row in DB)
- `Goal` — user goals; `type` is `"recurring" | "deadline" | "builtin"`
- `DailyLog` — one row per calendar day, accumulates HealthKit + distraction data
- `DistractionApp` — user-configured distraction apps
- `UserProfile` — user baselines (auto-updated after 7 days of logs) and settings

**TamaGoosie/Core/Services/**:
- `GooseEngine` — singleton orchestrator; entry point for all stat mutations. Call `GooseEngine.shared.update/completeGoal/processHealthData/revive/hatchNewEgg`
- `DecayEngine` — pure time-based decay; grace period (first 2h of 8+ hour absence free), compound penalty (extra 0.004/hr when either stat < 0.2), death when healthiness ≤ 0
- `RewardEngine` — pure stat delta calculations; also contains `computeHealthiness(log:profile:)` and `computeHappiness(log:goals:)` formula implementations

### Sync Architecture

`GooseEngine.saveStatsToAppGroup()` is called after every stat change. It:
1. Writes JSON-encoded `GooseSyncPayload` to `UserDefaults(suiteName: "group.com.tamagoosie")` under key `"gooseStats"` (consumed by Widget)
2. Calls `WatchSyncService.shared.sendPayload()` which updates ApplicationContext and sends a live message if Watch is reachable

The Watch receives payloads via `WatchSyncReceiver` and stores `currentPayload: GooseSyncPayload`.

### Mood & Phase Derivation

`GooseMood.deriveMood(healthiness:happiness:)` maps `avg = (h + hap) / 2`:
- `>= 0.80` → ecstatic, `0.60–0.80` → happy, `0.40–0.60` → content
- `0.25–0.40` → bored, `0.10–0.25` → sad, `< 0.10` → sick, `healthiness == 0` → dead

`GoosePhase.phase(forLevel:)`: level 0 → egg, 1–5 → baby, 6–15 → teen, 16+ → adult.

### Design System

`GoosieTheme` (enum in `Theme/GoosieTheme.swift`) provides all colors, typography, and spacing constants. `GoosieComponents.swift` contains shared UI primitives: `StatBar`, `PillButton`, `CircleActionButton`, `GoosieCard`, `LevelBadge`, `StreakFlame`.

`GooseCharacterView` (in `GooseAnimations.swift`) renders the animated goose. It takes `mood: GooseMood` and `phase: GoosePhase` — do not add additional parameters without updating all call sites across all three targets.

### Notifications

`NotificationManager` respects quiet hours (10pm–7am) and a max of 5 notifications/day. Harold speaks in first person. Notification identifiers: `morning_reminder`, `state_alert_<uuid>`, `goal_<goalID>`, `streak_<days>`, `decay_warning`.

### Important Constraints

- **All stat values are stored 0.0–1.0 in models**, displayed as 0–100 in UI only. Never store percent values in `GooseState`.
- `GoalSummary.progress` (on sync struct) is 0.0–1.0. `Goal.currentCount`/`targetCount`/`isCompleted` (on SwiftData model) still exist and drive `Goal.progress` computed property.
- The `Shared/` directory is compiled into all three targets. Code there must avoid importing `SwiftData` or any iOS-only frameworks.
- App group ID: `group.com.tamagoosie`. Sync key: `"gooseStats"`.
- Built-in goals have `type == "builtin"`. `GoalViewModel.seedBuiltinGoalsIfNeeded()` checks for their presence before inserting.
