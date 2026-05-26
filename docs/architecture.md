# Architecture Overview

TamaGoosie is a Tamagotchi-style iOS app where a virtual goose reflects the user's real health and productivity data. Both stats are computed directly from HealthKit and goal adherence — there is no decay, death, or gamified XP. The app syncs goose state, goals, and daily logs to a Convex backend for the social/friends system, and mirrors read-only data to a watchOS companion and home screen widgets.

---

## Targets

| Target | Platform | Type | Role |
|--------|----------|------|------|
| `TamaGoosie` | iOS 26+ | Application | Main app — source of truth for all data |
| `TamaGoosieWatch` | watchOS 10+ | Application | Read-only companion via WatchConnectivity |
| `TamaGoosieWidgets` | iOS | WidgetKit Extension | Home/lock screen widgets — read-only |
| `TamaGoosieDeviceActivity` | iOS | DeviceActivity Extension | Screen time monitoring (interval/threshold callbacks) |
| `TamaGoosieShield` | iOS | ManagedSettingsUI Extension | Renders shield overlay when a blocked app is opened |
| `TamaGoosieShieldAction` | iOS | ManagedSettingsUI Extension | Handles shield button taps (close, unlock, cancel) |
| `TamaGoosieReport` | iOS | ExtensionKit Extension | DeviceActivityReport scenes for weekly usage summaries |
| `TamaGoosieTests` | iOS | XCTest Bundle | Unit tests |

**iPhone is the sole source of truth.** Watch, Widget, and extensions are read-only consumers of `GooseSyncPayload` or app group `UserDefaults`.

---

## Directory Structure

```
Shared/                            — compiled into all targets (no SwiftData/UIKit)
  Constants.swift                  — GoosieConstants (formula weights, app group ID, UserDefaults keys)
  GoosePhase.swift                 — GooseMood, GoalCategory, GoalFrequency enums
  GooseStats.swift                 — GooseSyncPayload (cross-target sync struct)
  SyncPayload.swift                — GoalSummary (lightweight goal for Watch/Widget)

TamaGoosie/
  App/
    TamaGoosieApp.swift            — entry point, SwiftData container, BGTask registration
    ContentView.swift              — root view, onboarding gate, tab bar (6 tabs + more popup)
  Core/
    Models/                        — SwiftData @Model classes (10 models)
    Services/                      — GooseEngine, RewardEngine, HealthKit, Auth, Convex, etc.
  Features/
    Goose/                         — main character view, animations, live activity, 3D view
    Goals/                         — goal list, editor, create flow, weekly heatmap
    ScreenTime/                    — block management (blockNow, schedule, appLimit, lock)
    Store/                         — cosmetics shop (hats, colors, sprites for coins)
    Challenges/                    — community challenges (stub)
    Friends/                       — friend list, requests, friend cards (Convex-backed)
    Stats/                         — historical stats, daily goose history cards
    Settings/                      — user preferences, profile editor, distraction config
    Health/                        — HealthKit dashboard
    Focus/                         — distraction overlay tracking
    Account/                       — sign-in/sign-up views
    Onboarding/                    — multi-page onboarding flow with auth
    Notifications/                 — goose notification system, escalation, negotiation, AI speech
  Theme/
    GoosieTheme.swift              — colors, typography, layout constants
    GoosieComponents.swift         — shared UI primitives (StatBar, PillButton, GoosieCard, etc.)

Extensions/
  Shared/
    LockShieldReconciler.swift     — single source of truth for lock block shields
  Shield/
    ShieldConfigurationProvider.swift — renders shield UI (lock, countdown, time's up, generic)
  ShieldAction/
    ShieldActionHandler.swift      — handles shield button taps (close, 5s countdown unlock)
  Report/
    WeeklyReportScenes.swift       — DeviceActivityReport weekly summary
    DistractionReportScene.swift   — distraction app report view

TamaGoosieDeviceActivity/
  DeviceActivityMonitorExtension.swift — interval/threshold event handler

TamaGoosieWatch/                   — read-only Watch app
  WatchApp.swift, WatchSyncReceiver.swift, GooseGlanceView.swift,
  QuickLogView.swift, WatchStatsView.swift, DuckFaceView.swift,
  WatchTheme.swift, Complications/GooseComplication.swift

TamaGoosieWidgets/
  GooseWidget.swift                — home/lock screen widget

convex/                            — Convex backend (TypeScript)
  schema.ts, users.ts, friends.ts, geese.ts, goals.ts, dailyLogs.ts
```

---

## App Entry Flow

1. `TamaGoosieApp.init` — builds `ModelContainer` with 10-model schema. If migration fails, deletes SQLite store and recreates. Registers BGTask for shield reconciliation. Activates WatchConnectivity.
2. `ContentView.onAppear` — queries `UserProfile`. If `hasCompletedOnboarding` is false or user is not signed in, shows `OnboardingContainerView` (full-screen cover). Otherwise starts HealthKit background delivery and notification scheduling.
3. `ContentView.task` — restores Convex identity from Keychain, syncs HealthKit data, backfills historical `DailyLog` records, syncs daily logs to Convex.
4. `ContentView` — renders custom tab bar with 6 tabs + a "More" popup for secondary pages.

### Navigation Structure

**Tab Bar (5 primary tabs + More):**

| Tab | Icon | View | Description |
|-----|------|------|-------------|
| 0 | `house.fill` | `GooseView` | Main goose character, stats, mood |
| 1 | `checklist` | `GoalListView` | Today/Habits/Quests goal tabs |
| 2 | `hourglass` | `ScreenTimePageView` | Screen time blocks and usage stats |
| 3 | `storefront.fill` | `StoreView` | Cosmetics shop (hats, colors, sprites) |
| 4 | `trophy.fill` | `ChallengesView` | Community challenges (stub) |
| 5 | `ellipsis` | More popup | Opens popup with Friends, Stats, Settings |

**More Popup (3 secondary pages):**

| Page | Icon | View | Description |
|------|------|------|-------------|
| Friends | `person.2.fill` | `FriendsView` | Friend list, add/accept requests |
| Stats | `chart.line.uptrend.xyaxis` | `StatsView` | Historical health & goose data |
| Settings | `gearshape.fill` | `SettingsView` | Preferences, notifications, profile |

---

## Core Data Flow

```
HealthKitManager ──────────────────────────────────────────────────────┐
                                                                       ↓
User actions (goal complete, distraction) → GooseEngine → GooseState (SwiftData @Model)
                                                                       ↓
                                                           GooseSyncPayload (Codable)
                                                                       ↓
                                        ┌──────────────────────────────┼──────────────────┐
                                        ↓                              ↓                  ↓
                           UserDefaults (App Group)         WatchConnectivity        Convex Backend
                           "group.com.tamagoosie"            WCSession               ConvexManager
                                        ↓                              ↓                  ↓
                                 GooseWidget               WatchSyncReceiver        Friends/Social
                                 Shield Extensions         GooseGlanceView          Goal Sync
                                                                                   DailyLog Sync
```

Every stat change ends with `GooseEngine.saveStatsToAppGroup()`, which:
1. Encodes `GooseSyncPayload` as JSON into `UserDefaults(suiteName: "group.com.tamagoosie")` under key `"gooseStats"`.
2. Calls `WatchSyncService.shared.sendPayload()` — updates ApplicationContext (persistent) and sends live message if Watch is reachable.
3. `GooseSyncService.shared.syncToConvex()` — pushes happiness, healthiness, mood, goose name, sprite, and streak to the Convex `geese` table.

---

## Update Loop (60-second timer)

`GooseViewModel` runs a `Timer` every 60 seconds calling `GooseEngine.update(state:log:profile:goals:)`:

```
GooseEngine.update(state:log:profile:goals:)
  └── RewardEngine.computeHealthiness(log:profile:)  — recomputes from HealthKit data
  └── RewardEngine.computeHappiness(log:goals:)      — recomputes from goal adherence
  └── state.updateMood()                             — recaches mood string
  └── saveStatsToAppGroup()                          — broadcasts to Watch/Widget/Convex
```

Stats are **never mutated directly** and do not decay. Every update recomputes both values from scratch using the current `DailyLog`.

---

## SwiftData Models

| Model | Key Fields | Purpose |
|-------|------------|---------|
| `GooseState` | healthiness, happiness, mood, coins, streakDays, longestStreak, name, spriteID, hatID, colorID | Single goose instance (one row) |
| `Goal` | title, type, category, frequency, targetCount, currentCount, isCompleted, happinessWeight, sortOrder | User goals (recurring/deadline/builtin) |
| `GoalProgress` | goalID, date, completed | Per-day goal tracking |
| `GoalCompletionEvent` | goalID, date | Goal completion history |
| `DailyLog` | date, steps, exerciseMinutes, sleepHours, standHours, sittingHours, outsideMinutes, distractionOpens, distractionMinutes, goalsCompleted, goalsTotal, endOfDayHealthiness, endOfDayHappiness | One row per calendar day |
| `UserProfile` | hasCompletedOnboarding, watchPaired, health baselines | User settings and state |
| `ScreenBlock` | name, type, selectionData, opensAllowed, unlockDurationMinutes, schedule times, activeDays, timeLimitMinutes, isVacationMode | Screen time block configuration |
| `FocusSession` | start, end, duration | Focus timer sessions |
| `HealthSnapshot` | date, steps, exercise, sleep, etc. | Individual HealthKit data points |
| `DistractionApp` | bundleID, name | User-configured distraction apps |

---

## Layer Responsibilities

| Layer | Responsibility |
|-------|----------------|
| `GooseEngine` | Orchestrates all stat computation. Only entry point for changing `GooseState`. Runs `backfillHistory()` on launch to populate historical `DailyLog` records from HealthKit. Handles goal completion/uncompletion. |
| `RewardEngine` | Two pure formula functions: `computeHealthiness` and `computeHappiness`. Returns `Double`; never mutates state. |
| `GooseViewModel` | Bridges `GooseState` to the UI. Holds the 60-second update timer and current context. |
| `GoalViewModel` | Goal CRUD, completion tracking, category management. Delegates stat updates to `GooseEngine`. |
| `ScreenTimeManager` | Family Controls authorization, per-block `DeviceActivitySchedule` registration, shield application/removal, lock unlock/relock management, foreground reconciliation. See [lock-block-and-shield.md](lock-block-and-shield.md). |
| `AuthService` | Apple Sign-In, Google Sign-In, and email auth. Persists credentials to Keychain. Verifies credential validity on launch. |
| `ConvexManager` | Convex client singleton. Identity management (load/create/restore). Goal sync, DailyLog sync. Username availability checks. Returning user data restoration. |
| `GooseSyncService` | Pushes goose state (happiness, healthiness, mood, name, sprite, streak) to the Convex `geese` table after every stat update. |
| `HealthKitManager` | Fetches `HKStatistics` for today and historical dates. Background delivery setup. Does not mutate `GooseState` directly. |
| `WatchSyncService` | Sends `GooseSyncPayload` to Watch via WCSession. Receives goal completion messages from Watch. |
| `NotificationScheduler` | Schedules/cancels `UNNotification` requests. Snooze handling. |
| `GooseNotificationSystem` | Notification content generation, category/action registration, goal-aware scheduling with quiet hours (10pm–7am) and 5/day cap. |
| `GooseSpeechGenerator` | Generates goose personality dialogue via Gemini API. |
| `EscalationTracker` | Tracks notification failures and escalates retry intensity. |
| `KeychainService` | Keychain read/write/delete for auth credentials and Convex user ID. |
| `GeminiAPIClient` | HTTP client for Gemini API calls (AI speech generation). |
| `DailyLogHistoryProvider` | Provides historical DailyLog data for stats views. |
| `LockShieldReconciler` | Unions all active (non-unlocked) lock block apps onto the default `ManagedSettingsStore`. Called by main app, ShieldAction, and DeviceActivityMonitor. |

---

## Convex Backend

The Convex backend powers the social/friends system, user identity, and cross-device data sync.

### Schema (convex/schema.ts)

| Table | Key Fields | Purpose |
|-------|------------|---------|
| `users` | authProvider, appleUserID/googleUserID/emailUserID, username, displayName, email, avatarURL | User identity (Apple/Google/Email auth) |
| `friendRequests` | fromUserId, toUserId, status (pending/accepted/declined) | Friend graph management |
| `geese` | userId, happiness, healthiness, mood, gooseName, spriteID, streakDays | Per-user goose state (synced from device) |
| `goals` | userId, title, type, category, frequency, targetCount, happinessWeight, isActive | Synced user goals |
| `dailyLogs` | userId, date, steps, exerciseMinutes, sleepHours, ..., endOfDayHealthiness/Happiness | Historical daily snapshots |

### Key Endpoints

| File | Functions | Purpose |
|------|-----------|---------|
| `users.ts` | `createUser`, `getUserByAuthID`, `getGooseByUserId`, `searchUsers`, `checkUsernameAvailable` | Auth, identity, user search |
| `friends.ts` | `sendFriendRequest`, `acceptFriendRequest`, `declineFriendRequest`, `cancelFriendRequest`, `removeFriend`, `getFriends`, `getPendingRequests`, `getOutgoingRequests` | Full friend lifecycle |
| `geese.ts` | Sync goose state from device | Goose data for friend cards |
| `goals.ts` | `syncGoals`, `getGoals` | Bidirectional goal sync |
| `dailyLogs.ts` | `syncDailyLogs`, `getDailyLogs` | Historical data sync |

### Sync Flow

```
Device (SwiftData) ──→ ConvexManager ──→ Convex Cloud
                                              ↓
                    ←── ConvexManager ←── Convex Queries
                                              ↓
                                        FriendsViewModel (live subscriptions)
```

- **Goose state**: pushed after every stat update via `GooseSyncService`
- **Goals**: pushed after goal CRUD via `ConvexManager.syncGoals()`
- **DailyLogs**: pushed on app launch and after backfill via `ConvexManager.syncDailyLogs()`
- **Friends**: read in real-time via Convex subscriptions in `FriendsViewModel` and `FriendRequestViewModel`
- **Returning users**: on sign-in, `ConvexManager.checkReturningUser()` fetches existing goose, goals, and daily logs to restore local state

---

## Authentication

`AuthService` supports three auth providers:

| Provider | Implementation | ID Persistence |
|----------|----------------|----------------|
| Apple Sign-In | `ASAuthorization` | Keychain (`authUserID`, `authProvider`) |
| Google Sign-In | `GIDSignIn` SDK | Keychain + Google token restore |
| Email | Stable identifier from email | Keychain |

On launch, `AuthService.init()` restores credentials from Keychain and verifies validity (Apple credential state check, Google session restore). `ConvexManager.loadIdentity()` then validates the Convex user record exists.

### Onboarding Flow

`OnboardingContainerView` manages a state machine (`OnboardingState`) with two entry paths:

- **Fresh install**: Welcome → Sign In → Create Account (username) → Name Goose → HealthKit Permissions → Hatch Animation → Notifications → Tutorial → Complete
- **Logged-out return**: Return Welcome → Sign In → (checks for existing Convex account) → restores data or continues to account creation

---

## Screen Time & Shield System

The screen time blocking system uses Apple's Family Controls, ManagedSettings, and DeviceActivity frameworks across four extension processes. Detailed documentation is in [lock-block-and-shield.md](lock-block-and-shield.md).

### Block Types

| Type | Behavior |
|------|----------|
| `blockNow` | One-time timed session (e.g., 25 min Pomodoro) |
| `schedule` | Recurring daily block during configured hours on selected days |
| `appLimit` | Daily usage cap; blocks only after exceeding the limit |
| `lock` | Always-on block with limited unlocks per day (N opens, M minutes each) |

### Extension Architecture

- **DeviceActivityMonitor** (`TamaGoosieDeviceActivity`) — responds to `intervalDidStart`, `intervalDidEnd`, `eventDidReachThreshold` to apply/remove shields at scheduled times
- **ShieldConfigurationProvider** (`TamaGoosieShield`) — renders 4 shield variants: countdown, time's up, lock, generic
- **ShieldActionHandler** (`TamaGoosieShieldAction`) — implements 5-second countdown unlock flow for lock blocks
- **LockShieldReconciler** (`Extensions/Shared/`) — unions all locked apps onto the default `ManagedSettingsStore`

All extensions communicate via app group UserDefaults (`group.com.tamagoosie`).

---

## Notification System

The app has a multi-layered notification system:

| Component | Role |
|-----------|------|
| `GooseNotificationSystem` | Master scheduler. Registers notification categories with actions (ACK, BUSY, COMPLETE, SNOOZE, UPDATE, HARDER). Schedules goal reminders respecting quiet hours (10pm–7am) and 5/day cap. |
| `NotificationScheduler` | Low-level `UNNotification` request management. Snooze handling. |
| `EscalationTracker` | Tracks when goals are repeatedly ignored. Escalates notification tone. |
| `GooseSpeechGenerator` | Generates personality-driven goose dialogue via Gemini API for notification text. |
| `NegotiationView` | Interactive sheet where the user "negotiates" with the goose about skipping a goal (triggered by the BUSY notification action). |
| `AppNotificationDelegate` | `UNUserNotificationCenterDelegate` in `TamaGoosieApp`. Routes notification actions to the correct handler. |

---

## Coins & Store

`GooseState.coins` tracks the user's currency. Coins are earned on goal completion (awarded by `GooseEngine`). The `StoreView` lets users spend coins on cosmetic items:

- **Sprites** — goose character variants (`spriteID`)
- **Hats** — headwear accessories (`hatID`)
- **Colors** — color themes (`colorID`)

Purchased items update `GooseState` fields and are reflected in `GooseCharacterView` across all targets.

---

## Live Activity

`GooseLiveActivity` and `GooseLiveActivityManager` use ActivityKit to show the goose's current mood and stats on the Dynamic Island and lock screen. The activity updates on every stat change.

---

## Shared/ Constraints

Code in `Shared/` is compiled into all targets (iOS app, watchOS, widgets, extensions). It **must not**:
- Import `SwiftData`, `UIKit`, `AppKit`, or any iOS/watchOS-only framework
- Reference any `@Model` class

It **can** use: `Foundation`, `SwiftUI` (for `Color`), pure Swift types.

---

## SwiftData Notes

- **Boolean predicate bug (iOS 17)**: `#Predicate<Goal> { $0.isActive }` compiles but matches zero rows at runtime. All boolean filters are done in Swift after a plain `@Query`.
- **Migration recovery**: New stored properties need property-level defaults (e.g., `var foo: Double = 0.0`) or migration silently falls back to in-memory storage. `TamaGoosieApp.init` catches this and wipes the store.
- **One GooseState row**: The app always uses `gooseStates.first`. There is intentionally only one row.
- **DailyLog must exist**: Views call `ensureTodayLogExists()` / `fetchOrCreateTodayLog()` on appear to guarantee a `DailyLog` row for today before any stat computation runs.

---

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `ConvexMobile` | Convex backend client (queries, mutations, subscriptions) |
| `GoogleSignIn` | Google authentication |
| `FamilyControls` | Screen Time authorization |
| `DeviceActivity` | Schedule monitoring for screen time blocks |
| `ManagedSettings` | App shielding (ManagedSettingsStore) |
| `HealthKit` | Health data (steps, exercise, sleep, stand, sitting, outside time) |
| `ActivityKit` | Live Activities on Dynamic Island / lock screen |
| `WatchConnectivity` | Watch companion sync |
| `WidgetKit` | Home/lock screen widgets |
| `BackgroundTasks` | BGAppRefreshTask for shield reconciliation |

---

## Related Documentation

- [lock-block-and-shield.md](lock-block-and-shield.md) — detailed Shield and Lock Block system architecture
- [stat-system.md](stat-system.md) — healthiness/happiness formulas, mood derivation, streak, constants
- [models.md](models.md) — all SwiftData `@Model` classes and their fields
- [goose.md](goose.md) — GooseCharacterView, GooseViewModel, GooseView, Live Activity, Onboarding
- [goals.md](goals.md) — goal types, GoalListView, GoalViewModel, notifications, categories
