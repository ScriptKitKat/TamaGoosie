# Architecture Overview

TamaGoosie is a Tamagotchi-style iOS app where a virtual goose reflects the user's real health and productivity data. Both stats are computed directly from HealthKit and goal adherence — there is no decay, death, or gamified XP. There are three targets sharing a common `Shared/` layer.

---

## Targets

| Target | Platform | Role |
|--------|----------|------|
| `TamaGoosie` | iOS 26+ | Main app — source of truth for all data |
| `TamaGoosieWatch` | watchOS 10+ | Read-only mirror via WatchConnectivity |
| `TamaGoosieWidgets` | iOS | Home/lock screen widgets — read-only |
| `TamaGoosieTests` | iOS | XCTest unit tests |

**iPhone is the sole source of truth.** Watch and Widget are read-only consumers of `GooseSyncPayload`.

---

## Directory Structure

```
Shared/                        — compiled into all 3 targets (no SwiftData/UIKit)
  Constants.swift              — formula weights, streak/focus constants (GoosieConstants)
  GoosePhase.swift             — GooseMood, GoalCategory, GoalFrequency enums (no GoosePhase)
  GooseStats.swift             — GooseSyncPayload (cross-target sync struct)
  SyncPayload.swift            — GoalSummary (lightweight goal for Watch/Widget)

TamaGoosie/
  App/
    TamaGoosieApp.swift        — entry point, SwiftData container init with migration recovery
    ContentView.swift          — root view, onboarding gate, tab bar
  Core/
    Models/                    — SwiftData @Model classes
    Services/                  — GooseEngine, RewardEngine, HealthKit, Watch sync
  Features/
    Goose/                     — main character view, view model, animations, live activity
    Goals/                     — goal list, goal editor, goal view model
    Focus/                     — focus timer, distraction overlay
    Health/                    — HealthKit dashboard
    Settings/                  — settings view, notifications, distraction config
    Onboarding/                — 5-page onboarding flow
  Theme/
    GoosieTheme.swift          — colors, typography, layout constants
    GoosieComponents.swift     — shared UI primitives

TamaGoosieWatch/               — read-only Watch app
TamaGoosieWidgets/             — home/lock screen widgets
TamaGoosieTests/               — unit tests for engine + sync
```

---

## App Entry Flow

1. `TamaGoosieApp.init` — builds `ModelContainer` with the full schema. If migration fails (e.g. new model fields without defaults), it deletes the old SQLite + WAL/SHM files and recreates a fresh container.
2. `ContentView` — queries `UserProfile`. If `hasCompletedOnboarding` is false, shows `OnboardingView`. Otherwise shows `MainTabView` (4 tabs: Goose, Goals, Focus, Settings).
3. `GooseView.onAppear` — ensures a `GooseState` and `DailyLog` exist, starts the 60-second update timer.

---

## Core Data Flow

```
HealthKitManager ──────────────────────────────────────────────────────┐
                                                                        ↓
User actions (goal complete, distraction tracking) → GooseEngine → GooseState (SwiftData @Model)
                                                                        ↓
                                                            GooseSyncPayload (Codable)
                                                                        ↓
                                          ┌─────────────────────────────┤
                                          ↓                             ↓
                             UserDefaults (App Group)         WatchConnectivity
                             "group.com.tamagoosie"            WCSession
                                          ↓                             ↓
                                   GooseWidget               WatchSyncReceiver
                                   GooseComplication          GooseGlanceView
```

Every stat change ends with `GooseEngine.saveStatsToAppGroup()`, which:
1. Encodes `GooseSyncPayload` as JSON into `UserDefaults(suiteName: "group.com.tamagoosie")` under key `"gooseStats"`.
2. Calls `WatchSyncService.shared.sendPayload()` — updates ApplicationContext (persistent) and sends live message if Watch is reachable.

---

## Update Loop (60-second timer)

`GooseViewModel` runs a `Timer` every 60 seconds calling `GooseEngine.update(state:log:profile:goals:)`:

```
GooseEngine.update(state:log:profile:goals:)
  └── RewardEngine.computeHealthiness(log:profile:)  — recomputes from HealthKit data
  └── RewardEngine.computeHappiness(log:goals:)      — recomputes from goal adherence
  └── state.updateMood()                             — recaches mood string
  └── saveStatsToAppGroup()                          — broadcasts to Watch/Widget
```

Stats are **never mutated directly** and do not decay. Every update recomputes both values from scratch using the current `DailyLog`.

---

## Layer Responsibilities

| Layer | Responsibility |
|-------|----------------|
| `GooseEngine` | Orchestrates all stat computation. Only entry point for changing `GooseState`. Also runs `backfillHistory(daysBack:modelContext:profile:goals:)` on launch to populate historical `DailyLog` records from HealthKit. |
| `RewardEngine` | Two pure formula functions: `computeHealthiness` and `computeHappiness`. Returns `Double`; never mutates state. |
| `GooseViewModel` | Bridges `GooseState` to the UI. Holds the update timer and current context (log/profile/goals). |
| `GoalViewModel` | Delegates goal CRUD and DailyLog updates to GooseEngine. Handles goal CRUD. |
| `NotificationManager` | Schedules/cancels all `UNUserNotificationCenter` requests. |
| `HealthKitManager` | Fetches `HKStatistics` for today (`fetchTodayStats()`) and for any past calendar date (`fetchStats(for:)`); writes results to `DailyLog`; does not mutate `GooseState` directly. |
| `WatchSyncService` | Sends payloads to Watch; receives goal completion messages. |

---

## Shared/ Constraints

Code in `Shared/` is compiled into all three targets. It **must not**:
- Import `SwiftData`, `UIKit`, `AppKit`, or any iOS/watchOS-only framework
- Reference any `@Model` class

It **can** use: `Foundation`, `SwiftUI` (for `Color`), pure Swift types.

---

## SwiftData Notes

- **Boolean predicate bug (iOS 17)**: `#Predicate<Goal> { $0.isActive }` compiles but matches zero rows at runtime. All boolean filters are done in Swift after a plain `@Query`.
- **Migration recovery**: New stored properties need property-level defaults (e.g., `var foo: Double = 0.0`) or migration silently falls back to in-memory storage. `TamaGoosieApp.init` catches this and wipes the store.
- **One GooseState row**: The app always uses `gooseStates.first`. There is intentionally only one row.
- **DailyLog must exist**: Views call `ensureTodayLogExists()` on appear to guarantee a `DailyLog` row for today before any stat computation runs.
