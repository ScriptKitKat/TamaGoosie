# Lock Block & Shield System

This document explains the complete architecture of TamaGoosie's screen time blocking system, with particular focus on the **Lock** block type and the **Shield** UI that appears when a user tries to open a blocked app.

---

## Table of Contents

1. [Overview](#overview)
2. [Block Types](#block-types)
3. [System Architecture](#system-architecture)
4. [Data Model — ScreenBlock](#data-model--screenblock)
5. [Block Registration Flow](#block-registration-flow)
6. [Shield System](#shield-system)
   - [ManagedSettingsStore Strategy](#managedsettingsstore-strategy)
   - [ShieldConfigurationProvider](#shieldconfigurationprovider)
   - [ShieldActionHandler](#shieldactionhandler)
7. [Lock Block — Deep Dive](#lock-block--deep-dive)
   - [Lock Lifecycle](#lock-lifecycle)
   - [Unlock Flow (5-Second Countdown)](#unlock-flow-5-second-countdown)
   - [Relock Flow](#relock-flow)
   - [Daily Reset](#daily-reset)
   - [Time's Up Detection](#times-up-detection)
8. [LockShieldReconciler](#lockshieldreconciler)
9. [DeviceActivityMonitorExtension](#deviceactivitymonitorextension)
10. [Inter-Process Communication](#inter-process-communication)
11. [Safety Nets & Reconciliation](#safety-nets--reconciliation)
12. [Key Files Reference](#key-files-reference)

---

## Overview

TamaGoosie's blocking system prevents the user from opening selected apps during configured periods. When a blocked app is launched, iOS intercepts the launch and presents a **shield** — a full-screen overlay rendered by the app's Shield extension. The shield displays a themed message from the user's goose and optionally provides buttons to close the app or unlock it temporarily.

The system is built on Apple's **Screen Time API** (FamilyControls, ManagedSettings, DeviceActivity frameworks) and runs across **four separate processes**:

| Process | Bundle | Role |
|---------|--------|------|
| **Main App** | `com.tamagoosie.app` | User creates/edits/deletes blocks; orchestrates registration |
| **DeviceActivityMonitor Extension** | `com.tamagoosie.app.device-activity` | Responds to scheduled interval starts/ends and threshold events |
| **Shield Configuration Extension** | `com.tamagoosie.app.shield` | Renders the shield UI when a blocked app is opened |
| **Shield Action Extension** | `com.tamagoosie.app.shield-action` | Handles button taps on the shield (close, unlock, cancel) |

These four processes communicate exclusively through **App Group UserDefaults** (`group.com.tamagoosie`). There is no direct IPC or shared memory.

---

## Block Types

The app supports four block types, each with different activation mechanics:

| Type | Key | Behavior |
|------|-----|----------|
| **Block Now** | `"blockNow"` | One-time timed session. Blocks apps immediately for a set duration (e.g., 25 minutes). |
| **Schedule** | `"schedule"` | Recurring daily block during configured hours (e.g., 8:00–22:00) on selected days of the week. |
| **App Limit** | `"appLimit"` | Daily usage cap. Apps are only blocked after the user exceeds the time limit (e.g., 30 min/day). |
| **Lock** | `"lock"` | Always-on block. Apps are blocked 24/7 but the user can unlock them a limited number of times per day for a set duration per unlock. |

---

## System Architecture

```
User creates block in LockSheet / ScheduleSheet / etc.
        |
        v
  ScreenBlock (SwiftData @Model)
        |
        v
  ScreenTimeManager.registerBlock()
        |
        +---> Persists config to App Group UserDefaults
        +---> Registers DeviceActivitySchedule + Events
        +---> Applies immediate shield (if applicable)
        |
        v
  DeviceActivityCenter monitors the schedule
        |
    [System fires callbacks at scheduled times]
        |
        v
  DeviceActivityMonitorExtension
        |
        +---> intervalDidStart: apply shield / reset counters
        +---> intervalDidEnd: remove shield / cleanup
        +---> eventDidReachThreshold: apply shield (for limits)
        |
        v
  ManagedSettingsStore
  (per-block named store for non-lock blocks,
   default store for lock blocks via LockShieldReconciler)
        |
    [User opens blocked app]
        |
        v
  ShieldConfigurationProvider
        |
        +---> Reads UserDefaults to determine shield type
        +---> Returns ShieldConfiguration (title, subtitle, buttons, colors)
        |
        v
  ShieldActionHandler
        |
        +---> Primary button: close app
        +---> Secondary button: unlock (countdown flow)
```

---

## Data Model — ScreenBlock

**File:** `TamaGoosie/Core/Models/ScreenBlock.swift`

`ScreenBlock` is a SwiftData `@Model` class stored in the main app's database. It holds all configuration for a block.

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Unique identifier, used as the key for all UserDefaults entries |
| `name` | `String` | User-provided name (e.g., "Social Media Lock") |
| `type` | `String` | `"blockNow"`, `"schedule"`, `"appLimit"`, or `"lock"` |
| `isActive` | `Bool` | Whether the block is currently active |
| `selectionData` | `Data?` | Encoded `FamilyActivitySelection` (apps, categories, web domains) |
| `durationMinutes` | `Int` | Block Now: session duration |
| `startedAt` / `endedAt` | `Date?` | Block Now: session timestamps |
| `scheduleStartHour/Minute` | `Int` | Schedule: start time |
| `scheduleEndHour/Minute` | `Int` | Schedule: end time |
| `activeDays` | `String` | Comma-separated weekday numbers (1=Sunday through 7=Saturday) |
| `isVacationMode` | `Bool` | Schedule: temporarily disabled |
| `timeLimitMinutes` | `Int` | App Limit: daily cap in minutes |
| `opensAllowed` | `Int` | Lock: max unlocks per day (1–20) |
| `unlockDurationMinutes` | `Int` | Lock: minutes per unlock (1–60) |
| `opensUsedToday` | `Int` | Lock: local tracking (actual source of truth is in UserDefaults) |

### Computed Properties

- `selection: FamilyActivitySelection?` — Decodes `selectionData`
- `activeDaysSet: Set<Int>` — Parses `activeDays` string into a set
- `scheduleSummary: String` — Human-readable description (e.g., "3 opens/day, 5m each")
- `statusLabel: String` — Current status for card display (e.g., "Active", "Starting in 2h 30m")

---

## Block Registration Flow

**File:** `TamaGoosie/Core/Services/ScreenTimeManager.swift` — `registerBlock(_:)`

When the user saves a block, `ScreenTimeManager.registerBlock()` executes the following:

### Step 1: Persist configuration to App Group UserDefaults

```
blockShield-{blockID}          → Data (encoded FamilyActivitySelection)
blockType-{blockID}            → String ("lock" | "schedule" | "blockNow" | "appLimit")
```

For lock blocks, additional keys are written:
```
lockOpensAllowed-{blockID}     → Int
lockUnlockDuration-{blockID}   → Int (minutes)
activeLockBlockIDs             → [String] (appended with this block's ID)
```

### Step 2: Construct DeviceActivitySchedule

| Block Type | Interval | Repeats | Events |
|------------|----------|---------|--------|
| `blockNow` | 00:00–23:59 | No | `shield-{id}` at 1 min (includesPastActivity) |
| `schedule` | User's start–end time | Yes | `shield-{id}` at 1 min (includesPastActivity) |
| `appLimit` | 00:00–23:59 | Yes | `limit-{id}` at N minutes (the user's limit) |
| `lock` | 00:00–23:59 | Yes | `shield-{id}` at 1 min (includesPastActivity) |

Schedule blocks with intervals shorter than 15 minutes are skipped (DeviceActivity API limitation).

### Step 3: Register with DeviceActivityCenter

```swift
activityCenter.startMonitoring(
    DeviceActivityName("block-{blockID}"),
    during: schedule,
    events: events
)
```

`startMonitoring` replaces any existing monitor with the same name — no need to stop first.

### Step 4: Apply shield immediately (where applicable)

- **blockNow**: Applies shield via per-block `ManagedSettingsStore` immediately.
- **lock**: Calls `LockShieldReconciler.reconcile()` to compute and apply the union of all lock shields on the default store.
- **schedule**: Only if the current time falls within the schedule window. Otherwise, defers to the extension's `intervalDidStart` callback.
- **appLimit**: Never shields immediately. Waits for the threshold event.

---

## Shield System

### ManagedSettingsStore Strategy

The system uses two different shielding strategies depending on block type:

**Non-lock blocks (blockNow, schedule, appLimit)** use **per-block named stores**:
```swift
let store = ManagedSettingsStore(named: .init("block-{blockID}"))
store.shield.applications = selection.applicationTokens
store.shield.applicationCategories = .specific(selection.categoryTokens)
```

Each block gets its own isolated store. Removing a block only clears that block's store, leaving other blocks unaffected.

**Lock blocks** share the **default (unnamed) ManagedSettingsStore**:
```swift
let store = ManagedSettingsStore()  // default store
```

All active lock blocks are unioned together by `LockShieldReconciler`. This is necessary because lock blocks need coordinated unlock/relock behavior — temporarily unlocking one block's apps must not remove shielding for another block's apps.

### ShieldConfigurationProvider

**File:** `Extensions/Shield/ShieldConfigurationProvider.swift`

This extension runs in its own process. iOS calls it whenever a user opens a shielded app to get the UI configuration. It does **not** apply or remove shields — it only renders the visual overlay.

The provider checks the following conditions **in priority order**:

#### 1. Countdown Active?

```swift
func isCountdownActive(forApp token: ApplicationToken) -> Bool
```

Checks `unlockPendingBlockID` and `unlockPendingTimestamp` in UserDefaults. If a pending unlock exists and is less than 10 seconds old, returns the **countdown shield**:

- **Title:** "Unlocking in 5 seconds..."
- **Subtitle:** "{gooseName} is giving you a moment to reconsider..."
- **Primary button:** "Close App" (closes the app)
- **Secondary button:** "Cancel" (cancels the unlock)

#### 2. Time's Up?

```swift
func isTimesUp(forApp token: ApplicationToken) -> Bool
```

Checks `lockLastUnlockBlockID`, `lockLastUnlockTimestamp`, and `lockLastUnlockDurationSecs`. If the unlock duration has elapsed and it has been less than 60 seconds since expiry, returns the **time's up shield**:

- **Title:** "Time's up!"
- **Subtitle (unlocks remaining):** "Your {duration}-minute break is over. {gooseName} locked this app again."
- **Subtitle (no unlocks remaining):** "Your break is over and no unlocks are left today. See you tomorrow!"
- **Primary button:** "Close App"
- **Secondary button (if unlocks remain):** "Unlock ({remaining} left)"
- **No secondary button** if no unlocks remain

#### 3. Locked App?

```swift
func lockBlockInfo(forApp token: ApplicationToken) -> LockInfo?
```

Iterates `activeLockBlockIDs`, decodes each block's `FamilyActivitySelection`, and checks if the app token is in the selection. Returns the **lock shield**:

- **Title:** "{gooseName} locked this app"
- **Subtitle (unlocks remaining):** "This app is locked by {gooseName}. Tap unlock for a {duration}-minute break."
- **Subtitle (no unlocks remaining):** "This app is locked by {gooseName}. No unlocks remaining today. Come back tomorrow!"
- **Primary button:** "Close App"
- **Secondary button (if unlocks remain):** "Unlock ({remaining} left)"
- **No secondary button** if no unlocks remain

#### 4. Generic Block (fallback)

For non-lock blocks (schedule, blockNow, appLimit):

- **Title:** "Shhh... {gooseName} is napping!"
- **Subtitle:** "This app is blocked right now. {gooseName} wants you to take a break and do something fun offline!"
- **Primary button:** "Close App"
- **No secondary button** (no unlock option)

#### Visual Styling

All shields share a consistent TamaGoosie brand palette:
- Background: light gray (#F5F5F5)
- Title: warm brown (#5C4A3A)
- Primary button: amber (#E8963A) background, white text
- Secondary button (unlock): purple (#7D57C2) text
- Goose icon loaded from the extension bundle

The goose's name is read from the `gooseStats` JSON payload in UserDefaults (the same payload used by widgets and the watch app).

### ShieldActionHandler

**File:** `Extensions/ShieldAction/ShieldActionHandler.swift`

Handles button taps on the shield. Runs in the Shield Action extension process.

**Primary button** (all shields): Cancels any pending unlock and calls `completionHandler(.close)` to dismiss the app.

**Secondary button** (lock shields only): Triggers the unlock flow — see [Unlock Flow](#unlock-flow-5-second-countdown) below.

**Web domains**: Always close (no unlock option for web domains).

---

## Lock Block — Deep Dive

### Lock Lifecycle

```
[Block Created]
     |
     v
ScreenTimeManager.registerBlock()
     |
     +---> Writes config to UserDefaults
     +---> Registers 00:00–23:59 daily DeviceActivity
     +---> Calls LockShieldReconciler.reconcile()
     |         \---> Unions all locked apps onto default ManagedSettingsStore
     |
     v
[Apps are now shielded 24/7]
     |
[User opens blocked app]
     |
     v
ShieldConfigurationProvider renders lock shield
     |
     +---> "Close App" button
     +---> "Unlock (N left)" button (if unlocks remain)
     |
[User taps Unlock]
     |
     v
ShieldActionHandler.handleUnlockTap()
     |
     +---> 5-second countdown (shield re-renders as countdown)
     +---> After 5s: doUnlock() executes
     |         +---> Increments opensUsed counter
     |         +---> Sets unlock expiry timestamp
     |         +---> Stores unlock metadata for "time's up" detection
     |         +---> Calls LockShieldReconciler.reconcile()
     |         |         \---> Removes this block's apps from shield (expiry in future)
     |         +---> Schedules relock monitor
     |
     v
[Apps are temporarily unshielded for N minutes]
     |
[Unlock duration expires]
     |
     v
DeviceActivityMonitorExtension.intervalDidStart("unlock-{blockID}")
     |
     +---> Calls LockShieldReconciler.reconcile()
     |         \---> Expiry now in past → re-adds this block's apps to shield
     |
     v
[Apps are shielded again]
     |
[If user opens app within 60 seconds of expiry]
     |
     v
ShieldConfigurationProvider renders "Time's up!" shield
```

### Unlock Flow (5-Second Countdown)

The unlock flow is a multi-step process that spans the ShieldActionHandler and ShieldConfigurationProvider:

**Step 1 — User taps "Unlock" on the lock shield**

`ShieldActionHandler.handleUnlockTap()`:

1. Checks if a countdown is already active (if so, this tap is a "Cancel" — clears pending state, returns `.defer` to re-render)
2. Checks if unlocks are available (`opensUsed < opensAllowed`). If not, returns `.none` (no action)
3. Writes pending unlock state to UserDefaults:
   ```
   unlockPendingBlockID      → blockID
   unlockPendingTimestamp    → Date().timeIntervalSince1970
   ```
4. Returns `.defer` — this tells iOS to re-query `ShieldConfigurationProvider` for a new shield UI
5. Dispatches a 5-second delayed block on a background queue

**Step 2 — Shield re-renders as countdown**

`ShieldConfigurationProvider.isCountdownActive()` detects the pending state and returns the countdown shield UI. The shield now shows:
- "Unlocking in 5 seconds..."
- "Close App" button (primary)
- "Cancel" button (secondary)

If the user taps **Cancel**: `ShieldActionHandler` clears the pending state and returns `.defer` to re-render back to the normal lock shield.

If the user taps **Close App**: the app closes, but the 5-second timer continues running in the background.

**Step 3 — Timer fires after 5 seconds**

The `DispatchQueue.global().asyncAfter(deadline: .now() + 5.0)` block executes:

1. Re-reads `unlockPendingBlockID` — if it no longer matches (user cancelled), aborts
2. Clears the pending state
3. Calls `doUnlock(blockID:)`:
   - Increments `lockOpensUsed-{blockID}`
   - Sets `lockUnlockExpiry-{blockID}` to `now + (durationMinutes * 60)` as a Unix timestamp
   - Stores unlock metadata for "time's up" detection:
     ```
     lockLastUnlockBlockID       → blockID
     lockLastUnlockTimestamp     → Date().timeIntervalSince1970
     lockLastUnlockDurationSecs  → durationMinutes * 60
     ```
4. Calls `LockShieldReconciler.reconcile()` — this removes the block's apps from the shield because the expiry is in the future
5. Schedules a relock monitor via `startRelockMonitor()`

**Stale countdown protection:** The `isCountdownActive()` check in the ShieldConfigurationProvider has a 10-second TTL. If the pending timestamp is older than 10 seconds, it's treated as stale and ignored. This prevents the countdown shield from getting stuck if the timer fails to fire.

### Relock Flow

When the unlock duration expires, the apps must be re-shielded. Two mechanisms ensure this:

**Primary: Relock Monitor (DeviceActivity)**

`ShieldActionHandler.startRelockMonitor()` registers a temporary one-shot DeviceActivity:

```swift
DeviceActivityName("unlock-{blockID}")
Schedule: intervalStart = expiry time, intervalEnd = 23:59
Repeats: false
```

When the system clock reaches the expiry time, `DeviceActivityMonitorExtension.intervalDidStart()` fires for `unlock-{blockID}`:
- Calls `LockShieldReconciler.reconcile()`
- The reconciler sees that `lockUnlockExpiry-{blockID}` is now in the past
- Re-adds this block's apps to the default store's shield

**Secondary: Foreground Reconciliation**

When the user opens the TamaGoosie app, `ScreenTimeManager.reconcileBlocks()` runs as a safety net. It checks all lock blocks for expired unlocks and re-shields them if the extension callback was missed.

**Manual Relock**

The user can tap "Lock Now" on the `BlockCardView` to immediately relock:
- Calls `ScreenTimeManager.relockBlock()`
- Stops the unlock monitor
- Removes the expiry from UserDefaults
- Calls `LockShieldReconciler.reconcile()` to re-shield
- Re-registers the block's daily monitor

### Daily Reset

Lock blocks reset their unlock counter at the start of each new day. This happens in two places (defensive duplication):

**DeviceActivityMonitorExtension.intervalDidStart()** — When the daily `block-{blockID}` interval starts at midnight:
```swift
defaults.set(0, forKey: "lockOpensUsed-{blockID}")
defaults.set(Date(), forKey: "lockLastReset-{blockID}")
defaults.removeObject(forKey: "lockUnlockExpiry-{blockID}")
```

**lockOpensUsedToday()** — Both `ShieldActionHandler` and `ScreenTimeManager` check `lockLastReset-{blockID}` before reading the counter. If it's not today, they reset the counter inline:
```swift
if let lastReset = lastResetDate, !Calendar.current.isDateInToday(lastReset) {
    defaults.set(0, forKey: "lockOpensUsed-{blockID}")
    defaults.set(Date(), forKey: "lockLastReset-{blockID}")
    return 0
}
```

This ensures the counter resets correctly even if the extension callback is delayed.

### Time's Up Detection

When an unlock duration expires and the user tries to open the app again, the shield should show "Time's up!" instead of the normal lock shield. This is detected by `ShieldConfigurationProvider.isTimesUp()`:

1. Reads `lockLastUnlockBlockID`, `lockLastUnlockTimestamp`, and `lockLastUnlockDurationSecs` from UserDefaults
2. Calculates elapsed time since unlock: `elapsed = now - unlockTimestamp`
3. Checks: `elapsed >= durationSecs` (duration has passed) AND `elapsed - durationSecs < 60` (within 60 seconds of expiry)
4. Verifies the app is in the block's selection

The 60-second window ensures the "Time's up!" message is shown briefly after expiry before falling back to the normal lock shield.

---

## LockShieldReconciler

**File:** `Extensions/Shared/LockShieldReconciler.swift`

This is a stateless `enum` with a single static method `reconcile()`. It is the **single source of truth** for what apps are shielded by lock blocks.

### Algorithm

```
1. Read activeLockBlockIDs from UserDefaults
2. For each lock block ID:
   a. Read lockUnlockExpiry-{blockID}
   b. If expiry exists AND is in the future → skip (temporarily unlocked)
   c. Otherwise → decode FamilyActivitySelection from blockShield-{blockID}
   d. Union the apps, categories, and domains into accumulator sets
3. Write the union to the default ManagedSettingsStore:
   - store.shield.applications = allApps (or nil if empty)
   - store.shield.applicationCategories = .specific(allCats) (or nil if empty)
   - store.shield.webDomains = allWebs (or nil if empty)
```

### Callers

| Caller | When |
|--------|------|
| `ScreenTimeManager.registerBlock()` | Lock block registered |
| `ScreenTimeManager.reconcileBlocks()` | App returns to foreground |
| `ScreenTimeManager.unlockBlock()` | User unlocks from main app |
| `ScreenTimeManager.relockBlock()` | User relocks from main app |
| `ShieldActionHandler.doUnlock()` | User unlocks via shield button |
| `DeviceActivityMonitorExtension.intervalDidStart("unlock-{id}")` | Unlock monitor fires (relock) |
| `DeviceActivityMonitorExtension.intervalDidStart("block-{id}")` | Daily reset for lock block |
| `DeviceActivityMonitorExtension.intervalDidEnd()` | Global distraction monitor cleanup |
| `DeviceActivityMonitorExtension.eventDidReachThreshold("shield-{id}")` | 1-min backup threshold for lock |

### Why One Shared Store?

Lock blocks need coordinated behavior. If Block A unlocks Instagram and Block B also shields Instagram, unlocking Block A must **not** remove the shield if Block B still requires it. By unioning all locked (non-unlocked) blocks into a single store, the reconciler guarantees that an app is only unshielded when **all** lock blocks covering it are unlocked.

---

## DeviceActivityMonitorExtension

**File:** `TamaGoosieDeviceActivity/DeviceActivityMonitorExtension.swift`

This extension is launched by the system at scheduled times. It has no UI and no lifecycle beyond the callback.

### intervalDidStart(for activity)

| Activity Name | Behavior |
|---------------|----------|
| `unlock-{blockID}` | Relock: calls `LockShieldReconciler.reconcile()` to re-shield |
| `block-{blockID}` (lock) | Daily reset: clears `opensUsed` and `unlockExpiry`, calls `LockShieldReconciler.reconcile()` |
| `block-{blockID}` (appLimit) | No-op: waits for threshold event |
| `block-{blockID}` (schedule/blockNow) | Applies shield via per-block named `ManagedSettingsStore` |

### intervalDidEnd(for activity)

| Activity Name | Behavior |
|---------------|----------|
| `unlock-{blockID}` | Cleanup: removes `lockUnlockExpiry`, reconciles |
| `block-{blockID}` (lock) | No-op: lock blocks stay active (reconciler manages) |
| `block-{blockID}` (other) | Removes shield by clearing per-block named store |
| `daily-distraction` | Clears global shield and distraction counters, reconciles lock shields |

### eventDidReachThreshold(event, activity)

| Event Name | Behavior |
|------------|----------|
| `limit-{blockID}` | App limit reached: applies shield via per-block named store |
| `shield-{blockID}` | Backup shield event (1 min): for lock blocks calls reconciler, for others applies per-block shield |
| `distraction-{mins}` | Global distraction tracking: increments counters, sends notification, optionally shields |

### Breadcrumb Logging

All events are logged to `extensionBreadcrumbs` in UserDefaults (capped at 50 entries). The main app can read these for diagnostics. Each entry includes an ISO 8601 timestamp and the event description.

---

## Inter-Process Communication

All four processes communicate through **App Group UserDefaults** (`group.com.tamagoosie`). There is no shared database, no notifications between processes, and no direct IPC.

### UserDefaults Key Reference

#### Written by Main App (read by extensions)

| Key | Type | Description |
|-----|------|-------------|
| `blockShield-{blockID}` | `Data` | Encoded `FamilyActivitySelection` |
| `blockType-{blockID}` | `String` | Block type identifier |
| `lockOpensAllowed-{blockID}` | `Int` | Max unlocks per day |
| `lockUnlockDuration-{blockID}` | `Int` | Minutes per unlock |
| `activeLockBlockIDs` | `[String]` | All active lock block UUIDs |
| `gooseStats` | `Data` | JSON-encoded `GooseSyncPayload` (for goose name) |

#### Written by Extensions (read by main app and other extensions)

| Key | Type | Description |
|-----|------|-------------|
| `lockOpensUsed-{blockID}` | `Int` | Unlocks used today |
| `lockLastReset-{blockID}` | `Date` | Last daily reset timestamp |
| `lockUnlockExpiry-{blockID}` | `Double` | Unix timestamp when unlock expires |
| `unlockPendingBlockID` | `String` | Block ID being unlocked (countdown active) |
| `unlockPendingTimestamp` | `Double` | When the countdown started |
| `lockLastUnlockBlockID` | `String` | Last unlocked block (for "time's up") |
| `lockLastUnlockTimestamp` | `Double` | When the last unlock happened |
| `lockLastUnlockDurationSecs` | `Int` | Duration of the last unlock in seconds |
| `extensionBreadcrumbs` | `[String]` | Diagnostic log entries |
| `extensionLastCallback` | `Double` | Timestamp of last extension callback |

#### Synchronization

All processes call `defaults.synchronize()` before critical reads to ensure they see the latest writes from other processes. This is essential because each process has its own in-memory cache of UserDefaults.

---

## Safety Nets & Reconciliation

The system has multiple layers of redundancy to ensure shields are correctly applied even if individual callbacks fail:

### 1. Foreground Reconciliation

`ScreenTimeManager.reconcileBlocks()` runs every time the app returns to foreground (via `.onAppear` and `.onChange(scenePhase)`). It:

- Checks all registered monitors against `DeviceActivityCenter.activities`
- Re-registers any monitors the system dropped (e.g., after a reboot)
- Applies or removes shields based on current time for schedule blocks
- Cleans up expired unlock state for lock blocks
- Calls `LockShieldReconciler.reconcile()` as a final safety net

### 2. Background Task Reconciliation

For schedule blocks, `ScreenTimeManager.scheduleBackgroundReconcile()` submits a `BGAppRefreshTaskRequest` targeted at the next block start or end time. This serves as a backup if the DeviceActivity extension doesn't fire.

### 3. Backup Threshold Events

All non-appLimit blocks register a `shield-{blockID}` threshold event at 1 minute with `includesPastActivity: true`. This ensures shielding is applied even if `intervalDidStart` fails — as soon as the user accumulates 1 minute of usage on the selected apps, the threshold fires and the shield is applied.

### 4. Stale State Cleanup

- Countdown pending state older than 10 seconds is treated as stale and ignored
- "Time's up" detection has a 60-second window, after which it falls back to the normal lock shield
- Daily reset logic is implemented in both the extension and the helper functions, so it fires regardless of which process reads the counter first

### 5. Relock Monitor

The temporary `unlock-{blockID}` DeviceActivity ensures relocking happens at the system level, independent of the app being open. Even if the user never returns to TamaGoosie, the extension fires and re-shields the apps.

---

## Key Files Reference

| File | Location | Purpose |
|------|----------|---------|
| `ScreenBlock.swift` | `TamaGoosie/Core/Models/` | SwiftData model for all block types |
| `ScreenTimeManager.swift` | `TamaGoosie/Core/Services/` | Main orchestrator: registration, shield management, unlock/relock, diagnostics |
| `LockSheet.swift` | `TamaGoosie/Features/ScreenTime/` | UI for creating/editing lock blocks |
| `BlockCardView.swift` | `TamaGoosie/Features/ScreenTime/` | Card widget showing block status with lock controls |
| `ScreenTimeBlocksTab.swift` | `TamaGoosie/Features/ScreenTime/` | Tab view listing all blocks |
| `ScreenTimePageView.swift` | `TamaGoosie/Features/ScreenTime/` | Top-level screen time page |
| `ShieldConfigurationProvider.swift` | `Extensions/Shield/` | Renders shield UI; detects lock/countdown/time's up states |
| `ShieldActionHandler.swift` | `Extensions/ShieldAction/` | Handles shield button taps; implements 5-second countdown unlock |
| `DeviceActivityMonitorExtension.swift` | `TamaGoosieDeviceActivity/` | Responds to DeviceActivity events; applies/removes shields at interval boundaries |
| `LockShieldReconciler.swift` | `Extensions/Shared/` | Single source of truth for lock block shields; unions all locked apps onto default store |
| `Constants.swift` | `Shared/` | App group ID, UserDefaults keys, threshold constants |
