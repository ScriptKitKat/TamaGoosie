# Goose Character

The goose is the central character of TamaGoosie. Its visual state (mood, animations) is derived entirely from `GooseState` values. All rendering is procedural — no image assets.

---

## Mood System (`GooseMood`)

**Defined in**: `Shared/GoosePhase.swift`

Mood is derived from `avg = (healthiness + happiness) / 2`:

| Mood | Threshold | Body color |
|------|-----------|------------|
| `.ecstatic` | avg ≥ 0.80 | `0xFFD93D` |
| `.happy` | avg ≥ 0.60 | `0x6BCB77` |
| `.content` | avg ≥ 0.40 | `0x4ECDC4` |
| `.bored` | avg ≥ 0.25 | `0xFFB347` |
| `.sad` | avg ≥ 0.10 | `0xFF6B6B` |
| `.sick` | avg < 0.10 | `0x95A5A6` |

`GooseMood.deriveMood(healthiness:happiness:)` is called by `GooseState.updateMood()` and cached as a string in `GooseState.mood`. There is no `.dead` mood and no phase system.

---

## GooseCharacterView (`GooseAnimations.swift`)

Fully procedural SwiftUI drawing. No image assets.

**Parameters**:
```swift
GooseCharacterView(
    mood: GooseMood,
    showReaction: GooseReaction  // .none / .goalComplete / .feed
)
```

**Do not add parameters** without updating all call sites (iOS app, Watch app, onboarding).

### Body Parts Drawn

- **Body**: white/cream ellipse
- **Wings**: two ovals on sides, slight rotation
- **Feet**: two small orange ovals at bottom
- **Eyes**: black circles
- **Beak**: orange triangle/trapezoid; open for happy/ecstatic, closed otherwise
- **Blush**: pink circles on cheeks for happy/ecstatic moods

### Mood Overlays

| Mood | Overlay |
|------|---------|
| `.sad` | `SweatDrop` — blue teardrop shape |
| `.ecstatic` | `SparkleParticles` — animated stars |
| `.sick` | `SickOverlay` — green haze + swirl |

### Animations

- **Idle bob**: body moves up/down with `easeInOut` repeating animation. Amplitude varies by mood (more energetic when happy).
- **Blink**: `Timer` fires every 3–6 seconds (random interval), briefly closes eyes.
- **Goal complete reaction**: bounce scale 1.2 → 1.0, spring animation.
- **Feed reaction**: wobble left/right.

Reactions are triggered by `GooseViewModel.triggerReaction(_:)`, which sets `currentReaction` and clears it after 1.5 seconds.

---

## GooseView (`GooseView.swift`)

Main tab view for the goose.

### State & Context

```swift
@Query private var gooseStates: [GooseState]
@Query(sort: \Goal.sortOrder) private var allGoals: [Goal]
@Query private var profiles: [UserProfile]
@Query(sort: \DailyLog.date, order: .reverse) private var allDailyLogs: [DailyLog]
@State private var viewModel = GooseViewModel()
```

`.onAppear` calls `ensureTodayLogExists()` and passes all context to `viewModel.onAppear(state:log:profile:goals:)`.

`.onChange(of: allDailyLogs)` and `.onChange(of: allGoals)` call `viewModel.updateContext(log:profile:goals:)` to keep the ViewModel's stored context fresh.

### ensureTodayLogExists

```swift
@discardableResult
private func ensureTodayLogExists() -> DailyLog {
    if let existing = todayLog { return existing }
    let log = DailyLog(date: .now)
    modelContext.insert(log)
    return log
}
```

Must be called before any stat computation. Returns the existing log for today if it exists, otherwise inserts and returns a new one.

### Layout

```
header (name + StreakFlame)
GooseCharacterView (220pt height)
moodLabel (capsule)
statBars (health + happiness)
quickActions (Goals + Exercise buttons)
Spacer(minLength: 40)   ← intentional space for future additions
```

---

## GooseViewModel (`GooseViewModel.swift`)

`@Observable` class bridging `GooseState` to the view.

### Key Properties

```swift
var gooseState: GooseState?        // the real persisted state
var currentReaction: GooseReaction // drives animation in GooseCharacterView
var currentLog: DailyLog?          // stored context for timer ticks
var currentProfile: UserProfile?   // stored context for timer ticks
var currentGoals: [Goal]           // stored context for timer ticks
```

Computed shortcuts into `gooseState`:
- `mood`, `moodText`
- `healthinessPercent` — `(gooseState?.healthiness ?? 0) * 100`
- `happinessPercent` — `(gooseState?.happiness ?? 0) * 100`
- `gooseName`, `streakDays`

### Lifecycle

```swift
func onAppear(state:log:profile:goals:)         // sets context, calls engine.update, starts timer
func onDisappear()                              // invalidates timer
func updateContext(log:profile:goals:)          // called by View's onChange handlers
```

### 60-Second Timer

```swift
Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
    engine.update(state: state, log: currentLog, profile: currentProfile, goals: currentGoals)
}
```

---

## Live Activity (`GooseLiveActivityManager`)

Manages an ActivityKit lock screen live activity (`GoosePetActivity`).

### Content State

```swift
struct ContentState: Codable, Hashable {
    var healthiness: Double
    var happiness: Double
    var moodEmoji: String
    var streakDays: Int
    var currentGoalTitle: String?
    var currentGoalProgress: Double
    var isFocusing: Bool
    var focusMinutesRemaining: Int
}
```

### Dynamic Island Layout

- **Leading**: mood emoji
- **Trailing**: streak flame (when `streakDays > 0`)
- **Center**: goose name + focus time remaining (or "resting")
- **Expanded bottom**: mini stat bars (health + happiness)

### Lock Screen Banner

Horizontal layout: mood emoji → stats → streak flame

Max duration: 8 hours. Auto-ends after that.

---

## Onboarding (`OnboardingView.swift`)

5-page `TabView`:

1. **Welcome** — egg hatches into goose on tap (spring animation)
2. **Name** — text field, preview goose with entered name
3. **Goals** — pick up to 3 from 12 preset goals (colored chips, checkmarks)
4. **HealthKit** — request permission or skip
5. **Notifications** — request permission or skip

`completeOnboarding()`:
1. Creates `GooseState(name: enteredName)`
2. Creates `UserProfile` with `hasCompletedOnboarding = true`
3. Creates `Goal` records for each selected preset
4. Schedules morning reminder notification
5. `try? modelContext.save()`
6. Sets `hasCompletedOnboarding = true` on profile → triggers `ContentView` to show main app
