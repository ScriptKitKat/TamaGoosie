# Architecture Overview

TamaGoosie is a Tamagotchi-style iOS app where a virtual goose's stats decay over time and recover through real-world actions: completing goals, exercising, sleeping, and staying focused. There are three targets sharing a common `Shared/` layer.

---

## Targets

| Target | Platform | Role |
|--------|----------|------|
| `TamaGoosie` | iOS 17+ | Main app — source of truth for all data |
| `TamaGoosieWatch` | watchOS 10+ | Read-only mirror; can send goal completions back |
| `TamaGoosieWidgets` | iOS | Home/lock screen widgets — read-only |
| `TamaGoosieTests` | iOS | XCTest unit tests |

**iPhone is the sole source of truth.** Watch and Widget are read-only consumers of `GooseSyncPayload`.

---

## Directory Structure

```
Shared/                        — compiled into all 3 targets (no SwiftData/UIKit)
  Constants.swift              — all game constants (GoosieConstants)
  GoosePhase.swift             — GoosePhase, GooseMood, GoalCategory, GoalFrequency enums
  GooseStats.swift             — GooseSyncPayload (cross-target sync struct)
  SyncPayload.swift            — GoalSummary (lightweight goal for Watch/Widget)

TamaGoosie/
  App/
    TamaGoosieApp.swift        — entry point, SwiftData container init with migration recovery
    ContentView.swift          — root view, onboarding gate, tab bar
  Core/
    Models/                    — SwiftData @Model classes
    Services/                  — game engine, decay, rewards, HealthKit, Watch sync
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
3. `GooseView.onAppear` — ensures a `GooseState` exists, starts the 60-second update timer.

---

## Core Data Flow

```
HealthKitManager ──────────────────────────────────────────────────────┐
                                                                        ↓
User actions (goal complete, focus session, distraction) → GooseEngine → GooseState (SwiftData @Model)
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

## Game Loop (60-second timer)

`GooseViewModel` runs a `Timer` every 60 seconds calling `GooseEngine.update(state:)`:

```
GooseEngine.update()
  └── DecayEngine.applyDecay(to:)   — reduces stats based on elapsed time
  └── state.updateMood()            — recaches mood string
  └── saveStatsToAppGroup()         — broadcasts to Watch/Widget
```

If either stat hits a critical threshold, `DecayEngine` triggers death (`isDead = true`, `deathCause` set). `GooseViewModel` detects this and presents `DeathScreen`.

---

## Layer Responsibilities

| Layer | Responsibility |
|-------|----------------|
| `GooseEngine` | Orchestrates all stat mutations. Only entry point for changing `GooseState`. |
| `DecayEngine` | Pure time-based decay calculation. Called by GooseEngine. |
| `RewardEngine` | Pure stat delta calculations. Returns `StatDelta`; never mutates state directly. |
| `GooseViewModel` | Bridges `GooseState` to the UI. Holds the update timer. |
| `GoalViewModel` | Delegates all stat changes to `GooseEngine`. Handles goal CRUD. |
| `NotificationManager` | Schedules/cancels all `UNUserNotificationCenter` requests. |
| `HealthKitManager` | Fetches `HKStatistics`; does not mutate game state directly. |
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
