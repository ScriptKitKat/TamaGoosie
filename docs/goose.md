# Goose Character

The goose is the central character of TamaGoosie. Its visual state (mood, phase, animations) is derived entirely from `GooseState` values. All rendering is procedural — no image assets.

---

## Mood System (`GooseMood`)

**Defined in**: `Shared/GoosePhase.swift`

Mood is derived from `avg = (healthiness + happiness) / 2`:

| Mood | Threshold | Emoji | Hex color |
|------|-----------|-------|-----------|
| `.ecstatic` | avg ≥ 0.80 | 🤩 | `0xFFD93D` |
| `.happy` | avg ≥ 0.60 | 😊 | `0x6BCB77` |
| `.content` | avg ≥ 0.40 | 😐 | `0x4ECDC4` |
| `.bored` | avg ≥ 0.25 | 😑 | `0xFFB347` |
| `.sad` | avg ≥ 0.10 | 😢 | `0xFF6B6B` |
| `.sick` | avg > 0.0 | 🤢 | `0x95A5A6` |
| `.dead` | healthiness == 0 | 💀 | `0x2C2C2C` |

`GooseMood.deriveMood(healthiness:happiness:)` is called by `GooseState.updateMood()` and cached as a string in `GooseState.mood`.

---

## Phase System (`GoosePhase`)

**Defined in**: `Shared/GoosePhase.swift`

Phase is determined by level:

| Phase | Level range | Description |
|-------|-------------|-------------|
| `.egg` | 0 | Pre-hatched |
| `.baby` | 1–5 | Small, round goose |
| `.teen` | 6–15 | Growing goose |
| `.adult` | 16+ | Full-grown goose |

`GoosePhase.phase(forLevel:)` is called by `GooseState.updatePhase()` and cached as `GooseState.phase`.

`GooseCharacterView` receives `phase: GoosePhase` and scales the goose body accordingly (baby is smaller/rounder, adult is larger).

---

## GooseCharacterView (`GooseAnimations.swift`)

Fully procedural SwiftUI drawing. No image assets.

**Parameters**:
```swift
GooseCharacterView(
    mood: GooseMood,
    phase: GoosePhase,
    showReaction: GooseReaction  // .none / .goalComplete / .feed
)
```

**Do not add parameters** without updating all call sites (iOS app, Watch app, death screen, onboarding).

### Body Parts Drawn

- **Body**: white/cream ellipse, size scales with phase
- **Wings**: two ovals on sides, slight rotation
- **Feet**: two small orange ovals at bottom
- **Eyes**: black circles; go to X's when dead
- **Beak**: orange triangle/trapezoid; open for happy/ecstatic, closed otherwise
- **Blush**: pink circles on cheeks for happy/ecstatic moods

### Mood Overlays

| Mood | Overlay |
|------|---------|
| `.sad` | `SweatDrop` — blue teardrop shape |
| `.ecstatic` | `SparkleParticles` — animated stars |
| `.sick` | `SickOverlay` — green haze + swirl |
| `.dead` | Desaturated + X eyes |

### Animations

- **Idle bob**: body moves up/down with `easeInOut` repeating animation. Amplitude varies by mood (more energetic when happy).
- **Blink**: `Timer` fires every 3–6 seconds (random interval), briefly closes eyes.
- **Goal complete reaction**: bounce scale 1.2 → 1.0, spring animation.
- **Feed reaction**: wobble left/right.

Reactions are triggered by `GooseViewModel.triggerReaction(_:)`, which sets `currentReaction` and clears it after 1.5 seconds.

---

## GooseView (`GooseView.swift`)

Main tab view for the goose.

### State Sync Pattern

```swift
@Query private var gooseStates: [GooseState]
@State private var viewModel = GooseViewModel()

private var gooseState: GooseState {
    gooseStates.first ?? GooseState()   // ← fallback only; real state comes from @Query
}

.onAppear {
    ensureGooseExists()
    viewModel.onAppear(state: gooseState)   // may be fallback if @Query not ready
}
.onChange(of: gooseStates) { _, newStates in
    if let state = newStates.first {
        viewModel.updateState(state)    // ← real state delivered here
    }
}
```

The `.onChange` is critical. Without it, if `@Query` hasn't populated before `onAppear` fires, the ViewModel holds a transient fallback `GooseState()` and stat updates never appear.

### Layout

```
header (name + LevelBadge + StreakFlame)
GooseCharacterView (220pt height)
moodLabel (capsule)
statBars (health + happiness)
quickActions (Goals + Exercise buttons)
```

### DeathScreen Sheet

Shown as a sheet (`$viewModel.showDeathScreen`) when `isDead == true`. Contains:
- Desaturated dead goose
- Memorial stats (longest streak, revive count)
- **Revive** button → `GooseEngine.revive` (checks cooldown, resets to 0.5/0.5)
- **Hatch New Egg** button → `GooseEngine.hatchNewEgg` (resets all progression, preserves name/reviveCount/longestStreak)

---

## GooseViewModel (`GooseViewModel.swift`)

`@Observable` class bridging `GooseState` to the view.

### Key Properties

```swift
var gooseState: GooseState?        // the real persisted state
var currentReaction: GooseReaction // drives animation in GooseCharacterView
var showDeathScreen: Bool          // controls death sheet
```

Computed shortcuts into `gooseState`:
- `mood`, `phase`, `moodText`
- `healthinessPercent` — `(gooseState?.healthiness ?? 0) * 100`
- `happinessPercent` — `(gooseState?.happiness ?? 0) * 100`
- `gooseName`, `level`, `streakDays`, `isDead`

### Lifecycle

```swift
func onAppear(state: GooseState)   // sets gooseState, calls engine.update, starts timer
func onDisappear()                 // invalidates timer
func updateState(_ state: GooseState)  // syncs viewModel after @Query refresh, no timer restart
```

### 60-Second Timer

```swift
Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
    engine.update(state: state)
    if state.isDead && !showDeathScreen { showDeathScreen = true }
}
```

---

## Death & Revival

### Death Trigger
`DecayEngine` sets `isDead = true` when `healthiness <= 0`. `deathCause` is set to a human-readable string describing whether happiness or healthiness was the primary cause.

### Revival (`GooseEngine.revive`)
- Requires `isDead == true`
- If `reviveCount >= 3` (configurable: `revivalCooldownAfterDeathCount`), checks that at least 24 hours have passed since `deathDate`
- On success: `isDead = false`, `healthiness = 0.5`, `happiness = 0.5`, `reviveCount += 1`, `deathDate = nil`

### Hatch New Egg (`GooseEngine.hatchNewEgg`)
Full reset:
- `isDead = false`
- `healthiness = 0.8`, `happiness = 0.7`
- `xp = 0`, `level = 1`, `phase = .baby`
- `createdAt = .now`, `streakDays = 0`
- **Preserved**: `name`, `reviveCount`, `longestStreak`

---

## Live Activity (`GooseLiveActivityManager`)

Manages an ActivityKit lock screen live activity (`GoosePetActivity`).

### Content State
```swift
struct ContentState: Codable, Hashable {
    var healthiness: Double
    var happiness: Double
    var moodEmoji: String
    var level: Int
    var streakDays: Int
    var currentGoalTitle: String?
    var currentGoalProgress: Double
    var isFocusing: Bool
    var focusMinutesRemaining: Int
}
```

### Dynamic Island Layout
- **Leading**: mood emoji
- **Trailing**: "Lv.X 🔥Y" (level + streak)
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
