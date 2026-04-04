# Data Models

All persistent data uses SwiftData (`@Model`). Models live in `TamaGoosie/Core/Models/`.

---

## GooseState

**File**: `GooseState.swift`  
**Purpose**: The single goose instance. There is always exactly one row.

| Property | Type | Notes |
|----------|------|-------|
| `id` | UUID | Primary key |
| `name` | String | User-given name, default "Harold" |
| `spriteID` | String | Goose sprite variant |
| `hatID` | String? | Optional cosmetic hat |
| `colorID` | String | Goose color variant |
| `healthiness` | Double | 0.0–1.0. Computed from HealthKit formula |
| `happiness` | Double | 0.0–1.0. Computed from goal adherence formula |
| `mood` | String | Cached: `GooseMood.rawValue` |
| `streakDays` | Int | Consecutive days with ≥80% goals done |
| `longestStreak` | Int | All-time best streak |
| `lastStreakDate` | Date? | Last day streak was incremented |
| `lastUpdated` | Date | Timestamp of last `GooseEngine.update` call |
| `createdAt` | Date | Birth date |

**Key computed properties**:
- `currentMood: GooseMood` — parses `mood` string; falls back to `.content`
- `updateMood()` — recaches `mood` via `GooseMood.deriveMood(healthiness:happiness:)`
- `toSyncPayload(topGoals:)` — creates `GooseSyncPayload` for Watch/widget

There are no `xp`, `level`, `phase`, `isDead`, `deathDate`, `deathCause`, `reviveCount`, or `isVacationMode` fields.

---

## Goal

**File**: `Goal.swift`  
**Purpose**: User-defined and built-in goals. Has three `type` variants.

### Goal Types

| `type` value | Description |
|-------------|-------------|
| `"recurring"` | Repeats daily/weekly; counted by `currentCount`/`targetCount` |
| `"deadline"` | One-off project tracked by `percentageProgress` (0–1) |
| `"builtin"` | System-seeded defaults (same mechanics as recurring) |

### Properties

| Property | Type | Notes |
|----------|------|-------|
| `id` | UUID | |
| `title` | String | Display name |
| `type` | String | `"recurring"` / `"deadline"` / `"builtin"` |
| `category` | String | `GoalCategory.rawValue` |
| `frequency` | String | `GoalFrequency.rawValue` |
| `targetCount` | Int | Reps needed for recurring goals |
| `currentCount` | Int | Current reps completed |
| `percentageProgress` | Double | `= 0.0` — deadline progress (0–1). **Must have property-level default** |
| `happinessWeight` | Double | Multiplier on happiness reward (typically 1.0 or 1.2) |
| `isCompleted` | Bool | True when goal is done for the current period |
| `completedAt` | Date? | When it was completed |
| `currentStreak` | Int | Consecutive days completed |
| `lastCompletedDate` | Date? | Used for streak tracking |
| `isActive` | Bool | Soft-delete flag |
| `sortOrder` | Int | Display order |
| `dueDate` | Date? | Deadline goals only |
| `preferredTime` | Date? | Used for notification scheduling |
| `customDays` | String | `= ""` — comma-separated weekday ints (1=Sun). **Must have property-level default** |
| `createdAt` | Date | |

**Key computed properties**:
- `progress: Double` — returns `percentageProgress` for deadline; `Double(currentCount) / Double(targetCount)` for recurring
- `customDaysSet: Set<Int>` — bidirectional get/set converting the CSV string
- `goalCategory: GoalCategory` — parsed from `category` string
- `goalFrequency: GoalFrequency` — parsed from `frequency` string

**Key methods**:
- `complete()` — sets `isCompleted = true`, `completedAt = .now`, `lastCompletedDate = .now`
- `incrementProgress()` — increments `currentCount`; sets `isCompleted` if `currentCount >= targetCount`
- `incrementPercentage(by:)` — adds amount (default 0.01) to `percentageProgress`; clamps at 1.0; marks completed at 1.0
- `setPercentage(_:)` — directly sets `percentageProgress`
- `resetForNewDay()` — resets `currentCount`, `isCompleted`, `completedAt` for a new day
- `toSummary()` — returns `GoalSummary` for Watch/widget sync

### Built-in Goals

`GoalViewModel.seedBuiltinGoalsIfNeeded` inserts 4 built-in goals if none of `type == "builtin"` exist:
1. Daily walk (10,000 steps) — health, daily, weight 1.2
2. 8 hours of sleep — health, daily, weight 1.2
3. Drink 8 glasses of water — health, daily, weight 1.0
4. No screens after 9pm — mindfulness, daily, weight 1.0

---

## UserProfile

**File**: `UserProfile.swift`  
**Purpose**: User settings and auto-calibrated health baselines.

| Property | Type | Notes |
|----------|------|-------|
| `id` | UUID | |
| `displayName` | String | |
| `joinDate` | Date | |
| `hasCompletedOnboarding` | Bool | Controls first-launch gate in ContentView |
| `wantsNotifications` | Bool | |
| `wantsWatchSync` | Bool | |
| `avgSleepHours` | Double | Auto-calibrated from last 7 DailyLogs |
| `avgSteps` | Int | Auto-calibrated |
| `avgExerciseMinutes` | Int | Auto-calibrated |
| `avgSittingHours` | Double | Auto-calibrated |

**Auto-calibration**: `GooseEngine.updateBaselinesIfNeeded` runs after 7+ `DailyLog` records. It only updates a baseline if the new value differs by >10% from the current.

---

## DailyLog

**File**: `DailyLog.swift`  
**Purpose**: One row per calendar day. Feeds both stat formulas. Created eagerly by `ensureTodayLogExists()` in views.

| Property | Type | Notes |
|----------|------|-------|
| `id` | UUID | |
| `date` | Date | Normalized to start of day |
| `steps` | Int | HealthKit step count |
| `exerciseMinutes` | Double | HealthKit active minutes |
| `sleepHours` | Double | HealthKit sleep duration |
| `standHours` | Int | HealthKit stand hours |
| `sittingHours` | Double | Estimated sedentary time |
| `outsideMinutes` | Double | Time outdoors (Watch only) |
| `distractionOpens` | Int | Count of distraction overlay opens |
| `distractionMinutes` | Double | Minutes in distraction mode |
| `goalsCompleted` | Int | Count of completed active goals (updated by GooseEngine) |
| `goalsTotal` | Int | Count of total active goals (updated by GooseEngine) |

There are no `healthinessDelta`, `happinessDelta`, or `xpEarned` fields — stats are recomputed from the raw data above, not accumulated as deltas.

---

## FocusSession

**File**: `FocusSession.swift`  
**Purpose**: Records each focus timer run.

| Property | Type | Notes |
|----------|------|-------|
| `id` | UUID | |
| `startedAt` | Date | |
| `endedAt` | Date? | |
| `targetMinutes` | Int | User-selected duration (5–120) |
| `actualMinutes` | Int | How long they actually focused |
| `wasCompleted` | Bool | True if ran to 0 without aborting |

`finish(completed:)` — calculates elapsed time and sets `endedAt`. Focus sessions do not directly affect stats; distraction minutes are tracked separately via `DailyLog`.

---

## DistractionApp

**File**: `DistractionApp.swift`  
**Purpose**: User-configured apps to track as distractions.

| Property | Type | Notes |
|----------|------|-------|
| `id` | UUID | |
| `bundleID` | String | App bundle ID |
| `displayName` | String | Human-readable name |
| `iconName` | String | SF Symbol or asset name |
| `dailyLimitMinutes` | Int | Minutes before full penalty |

---

## Relationships & Query Patterns

There are no explicit SwiftData relationships between models. Goals are queried independently from GooseState.

### SwiftData iOS 17 Boolean Predicate Bug

`#Predicate<Goal> { $0.isActive }` compiles but matches zero rows on iOS 17. **Always filter booleans in Swift**:

```swift
// WRONG — matches nothing
@Query(filter: #Predicate<Goal> { $0.isActive }) var goals: [Goal]

// CORRECT — filter in Swift after plain @Query
@Query(sort: \Goal.sortOrder) private var allGoals: [Goal]
private var goals: [Goal] { allGoals.filter { $0.isActive } }
```

### Migration Safety

When adding new stored properties to any `@Model`, **always provide a property-level default**:

```swift
var percentageProgress: Double = 0.0   // ✓ safe
var customDays: String = ""             // ✓ safe
var newField: Double                    // ✗ will corrupt the store on existing installs
```

If migration fails, `TamaGoosieApp.init` catches the error, deletes the `.sqlite`, `.sqlite-shm`, and `.sqlite-wal` files, and recreates the container.
