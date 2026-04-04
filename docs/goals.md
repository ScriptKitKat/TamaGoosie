# Goal System

Goals are the primary way users improve the goose's happiness stat. They live in `TamaGoosie/Features/Goals/` with supporting logic in `GooseEngine` and `NotificationManager`.

---

## Goal Types

### Recurring (`type == "recurring"` or `"builtin"`)

The standard goal type. Tracked by `currentCount` and `targetCount`.

- `targetCount == 1`: single check-off (most goals)
- `targetCount > 1`: tap multiple times to increment (e.g., "drink 8 glasses of water")
- `resetForNewDay()` is called on app open if `completedAt` is not today

Completion flow:
1. User taps checkmark / progress ring
2. `GoalViewModel.completeGoal` or `incrementGoal` calls `ensureTodayLogExists()`, then `GooseEngine.completeGoal(_:state:log:goals:)`
3. `goal.complete()` sets `isCompleted = true`, timestamps set
4. `log.goalsCompleted` and `log.goalsTotal` updated to reflect current counts
5. `RewardEngine.computeHappiness(log:goals:)` recomputes happiness immediately
6. `GooseEngine.saveStatsToAppGroup()` broadcasts updated state

**Uncomplete flow** (recurring only, not deadline):
1. User taps completed checkmark
2. `GooseEngine.uncompleteGoal(_:state:log:goals:)`:
   - Resets `currentCount = 0`, `isCompleted = false`, `completedAt = nil`
   - Updates `log.goalsCompleted`
   - Recomputes happiness via `computeHappiness`

### Deadline (`type == "deadline"`)

One-off project goals tracked by `percentageProgress` (0.0–1.0).

- Progress shown as a percentage ring and bar on the card
- **Tap** increments by 1% (`incrementPercentage(by: 0.01)`)
- **5 rapid taps** triggers a celebration: confetti burst from card center + card bounce + glow
- **Long-press** reveals an inline `Slider` to set progress directly
- **Cannot be uncompleted** — once marked complete, it stays complete
- Has an optional `dueDate` shown on the card

Completion fires when `percentageProgress >= 1.0`. Same `GooseEngine.completeGoal` path as recurring.

---

## Goal List View (`GoalListView.swift`)

`@Query(sort: \Goal.sortOrder)` fetches all goals. Active goals filtered in Swift:
```swift
private var goals: [Goal] { allGoals.filter { $0.isActive } }
```

Also queries `DailyLog`:
```swift
@Query(sort: \DailyLog.date, order: .reverse) private var allDailyLogs: [DailyLog]
```

Cards are rendered by type:
- `GoalCardView` — for recurring and builtin
- `DeadlineGoalCardView` — for deadline

**Daily reset**: `onAppear` calls `GoalViewModel.resetDailyGoals(_:)`, which calls `goal.resetForNewDay()` on any goal where `completedAt` is not today.

**ensureTodayLogExists**: Same helper as GooseView — inserts a `DailyLog` for today if one doesn't exist. Called from `onAppear` and all goal callbacks to guarantee a non-nil log before stat computation.

**Confetti system**: Multiple simultaneous confetti bursts are supported. `confettiBursts: [ConfettiBurst]` is an array of `Identifiable` structs. Each celebration appends a new burst; `ForEach` renders all simultaneously. Each auto-removes after 2.5 s via an async Task keyed to its UUID.

---

## GoalCardView (Recurring)

| Element | Behavior |
|---------|----------|
| Category accent bar | Color from `GoalCategory.color` |
| Title | Strikethrough when completed |
| Frequency label | Below title |
| Streak flame | Shown when `currentStreak > 0` |
| Check button (`targetCount == 1`) | Calls `onComplete` if not done; `onUncomplete` if done |
| Progress ring (`targetCount > 1`) | Calls `onIncrement` if not done; `onUncomplete` if done |
| Kebab menu (⋮) | Edit → opens `GoalEditorView` pre-filled; Delete → removes goal + cancels notification |
| Card opacity | 0.7 when completed, 1.0 otherwise |

---

## DeadlineGoalCardView

| Element | Behavior |
|---------|----------|
| Percentage ring | Animates on `goal.percentageProgress` change |
| Progress bar | Fills proportionally |
| Due date | Shown if `dueDate != nil` |
| Tap | `handleTap()`: increments 1%, counts toward celebration on 5th tap |
| Long press (0.5s) | Reveals inline slider with "Set progress: X%" + Done button |
| Celebration (5th tap) | Immediate: confetti burst at card center + bounce animation + glow border |
| Card bounce | spring(response: 0.15, dampingFraction: 0.4) — only on celebration, not each tap |
| Kebab menu (⋮) | Edit / Delete only (no uncomplete for deadline goals) |
| Tap reset | If user stops tapping for 1.5s, tap counter resets |

**Card center tracking**: `.onGeometryChange(for: CGPoint.self)` captures the card's global screen position. This point is passed to `onCelebration` so confetti originates exactly at the card.

---

## GoalEditorView (`GoalEditorView.swift`)

Handles both creating and editing goals. Accepts an optional `existingGoal: Goal?`.

### Fields

| Section | Fields |
|---------|--------|
| Title | Text field |
| Type | Segmented picker: Recurring / Deadline |
| Category | ScrollView of 11 category chips |
| Frequency (recurring) | Two rows of chips: [Daily, Weekdays, Weekends] + [Weekly, Custom] |
| Custom days (recurring) | Row of 7 day circles (Su–Sa), animated in when frequency == .custom |
| Target count (recurring) | Stepper (1–20) |
| Importance | Slider 0.5–2.0 (maps to `happinessWeight`) |
| Due date (deadline) | DatePicker |
| Reminder | Toggle + `DatePicker(.hourAndMinute)` |

### Save Flow

1. Creates or updates `Goal` model
2. If `preferredTime` is set, calls `NotificationManager.shared.scheduleGoalReminder`
3. If editing an existing goal with notifications, cancels old reminders before scheduling new ones
4. Calls `try? modelContext.save()` then `dismiss()`

---

## GoalViewModel (`GoalViewModel.swift`)

Thin coordinator — delegates all stat changes to `GooseEngine`. All methods that affect stats require a non-nil `DailyLog` (obtained via `ensureTodayLogExists()` at the call site).

```swift
func completeGoal(_ goal: Goal, state: GooseState, log: DailyLog, goals: [Goal])
func incrementGoal(_ goal: Goal, state: GooseState, log: DailyLog, goals: [Goal])
func uncompleteGoal(_ goal: Goal, state: GooseState, log: DailyLog, goals: [Goal])
func incrementDeadlinePercentage(_ goal: Goal, state: GooseState, log: DailyLog, goals: [Goal], amount: Double = 0.01)
func setDeadlinePercentage(_ goal: Goal, state: GooseState, log: DailyLog, goals: [Goal], to value: Double)
func deleteGoal(_ goal: Goal, in context: ModelContext)   // also cancels notification
func seedBuiltinGoalsIfNeeded(in context: ModelContext)   // inserts 4 defaults if none exist
func resetDailyGoals(_ goals: [Goal])                     // resets stale completions
func startEditing(_ goal: Goal)                           // sets editingGoal, showEditor = true
func startCreating()                                      // clears editingGoal, showEditor = true
```

---

## Notifications (`NotificationManager`)

Goal reminders are scheduled in `NotificationManager.scheduleGoalReminder(_ goal: Goal, gooseName: String)`.

### Scheduling by Frequency

| Frequency | Requests created |
|-----------|-----------------|
| Daily | 1 repeating daily request (`goal_<id>`) |
| Weekdays | 5 per-weekday requests (`goal_<id>_2` through `goal_<id>_6`) |
| Weekends | 2 per-weekday requests (`goal_<id>_1`, `goal_<id>_7`) |
| Weekly | 1 repeating weekly request |
| Custom | 1 request per selected weekday in `customDaysSet` |

### Cancellation

`cancelGoalReminder(goalID:)` removes:
- Base ID: `"goal_<id>"`
- Per-weekday IDs: `"goal_<id>_1"` through `"goal_<id>_7"`

Always call this before rescheduling (e.g., when editing a goal's time or frequency).

### Quiet Hours

Notifications are skipped if `preferredTime` falls between 10pm–7am.

---

## Goal Categories (`GoalCategory` enum in `Shared/GoosePhase.swift`)

| Category | Icon | Color |
|----------|------|-------|
| exercise | figure.run | `0xFF6B6B` (coral) |
| water | drop.fill | `0x4ECDC4` (teal) |
| screentime | iphone | `0x95A5A6` (grey) |
| study | book.fill | `0x3498DB` (blue) |
| health | heart.fill | `0xFF6B6B` (coral) |
| fitness | bolt.fill | `0xF39C12` (orange) |
| mindfulness | leaf.fill | `0x27AE60` (green) |
| productivity | checkmark.circle.fill | `0x8E44AD` (purple) |
| social | person.2.fill | `0xE74C3C` (red) |
| learning | lightbulb.fill | `0xF1C40F` (yellow) |
| custom | star.fill | `0xFFD93D` (gold) |

---

## Goal Frequencies (`GoalFrequency` enum in `Shared/GoosePhase.swift`)

| Case | Display name | Notification behavior |
|------|----|---|
| `.daily` | Every Day | Single repeating daily |
| `.weekdays` | Weekdays | 5 per-weekday requests |
| `.weekends` | Weekends | 2 per-weekday requests |
| `.weekly` | Weekly | Single repeating weekly |
| `.custom` | Custom | Per selected weekday |
