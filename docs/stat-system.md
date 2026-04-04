# Stat System

The goose has exactly **two stats**, both stored as `Double` on a **0.0–1.0 scale** in `GooseState`. They are displayed as `Int(stat * 100)` percent in the UI. Never store percent values in the model.

Stats are **computed from formulas, never mutated directly**. Every update cycle recomputes both values from scratch using the current `DailyLog`. There is no decay, no XP, no levels, and no death.

---

## The Two Stats

### Healthiness

Reflects physical wellbeing. A weighted composite of HealthKit data for the current day.

**Formula** (`RewardEngine.computeHealthiness(log:profile:)`):

```
score = clamp(steps / profile.avgSteps,       0–1) * 0.25   (steps weight)
      + clamp(exercise / profile.avgExercise,  0–1) * 0.30   (exercise weight)
      + clamp(sleep / profile.avgSleep,        0–1) * 0.30   (sleep weight)
      + clamp(1 - sitting / maxSitting,        0–1) * 0.15   (sitting weight)
```

With Watch connected, `outsideMinutes` replaces the sitting component and weights shift accordingly.

The result is clamped to [0.0, 1.0].

### Happiness

Reflects goal adherence and focus. Driven by how well the user keeps up with their goals.

**Formula** (`RewardEngine.computeHappiness(log:goals:)`):

```
goalScore        = goalsCompleted / max(goalsTotal, 1)   → weighted 50%
distractionFree  = 1 - clamp(distractionMinutes / 120, 0–1)  → weighted 30%
base             = 0.20 (always present)
streakBonus      = min(streakDays * 0.01, 0.10)

happiness = goalScore * 0.50 + distractionFree * 0.30 + 0.20 + streakBonus
```

The result is clamped to [0.0, 1.0].

---

## Update Trigger

`GooseEngine.update(state:log:profile:goals:)` is the single entry point for recomputing stats. It is called:

- Every 60 seconds by `GooseViewModel`'s timer
- On `GooseView.onAppear`
- After HealthKit data is written to `DailyLog` (from `HealthDashboard`)
- After each goal completion or uncompletion

When a goal is completed, `GooseEngine.completeGoal(_:state:log:goals:)` updates `log.goalsCompleted` / `log.goalsTotal` first, then calls `computeHappiness` directly to update happiness immediately without waiting for the next tick.

---

## DailyLog as Source of Truth

`DailyLog` is the bridge between user actions and stat computation. All inputs to both formulas come from today's `DailyLog` row:

| DailyLog field | Used by |
|----------------|---------|
| `steps` | `computeHealthiness` |
| `exerciseMinutes` | `computeHealthiness` |
| `sleepHours` | `computeHealthiness` |
| `sittingHours` | `computeHealthiness` |
| `outsideMinutes` | `computeHealthiness` (Watch only) |
| `distractionMinutes` | `computeHappiness` |
| `goalsCompleted` | `computeHappiness` |
| `goalsTotal` | `computeHappiness` |

**A `DailyLog` must exist** before stats can be computed. Views call `ensureTodayLogExists()` on appear, which inserts a new `DailyLog(date: .now)` if none exists for today.

---

## Mood Derivation

`GooseMood.deriveMood(healthiness:happiness:)` maps `avg = (healthiness + happiness) / 2`:

| Mood | Threshold | Body color |
|------|-----------|------------|
| `.ecstatic` | avg ≥ 0.80 | `0xFFD93D` |
| `.happy` | avg ≥ 0.60 | `0x6BCB77` |
| `.content` | avg ≥ 0.40 | `0x4ECDC4` |
| `.bored` | avg ≥ 0.25 | `0xFFB347` |
| `.sad` | avg ≥ 0.10 | `0xFF6B6B` |
| `.sick` | avg < 0.10 | `0x95A5A6` |

`GooseMood.deriveMood` is called by `GooseState.updateMood()` and the result is cached as `GooseState.mood` (a `String`).

---

## Streak

`streakDays` on `GooseState` tracks consecutive days where the user completed ≥80% of their active goals. The streak:
- Increments once per day when the threshold is met
- Resets to 0 if the user misses more than `GoosieConstants.streakResetAfterMissedDays` days (default: 2)
- Is stored alongside `longestStreak` (all-time best) and `lastStreakDate`
- Contributes a small bonus (up to +0.10) to the happiness formula

---

## Reset

`GooseEngine.resetGoose(state:)` replaces the old hatch/revive system:
- Sets `healthiness = 0.8`, `happiness = 0.7`
- Clears `streakDays = 0`, `lastStreakDate = nil`
- Calls `updateMood()` and syncs to app group

---

## Constants Reference (`GoosieConstants`)

| Constant | Value | Meaning |
|----------|-------|---------|
| `sleepWeight` | 0.30 | Healthiness formula: sleep contribution |
| `exerciseWeight` | 0.30 | Healthiness formula: exercise contribution |
| `stepsWeight` | 0.25 | Healthiness formula: steps contribution |
| `sittingWeight` | 0.15 | Healthiness formula: sitting contribution |
| `goalScoreWeight` | 0.50 | Happiness formula: goal completion contribution |
| `distractionWeight` | 0.30 | Happiness formula: distraction-free contribution |
| `happinessBase` | 0.20 | Happiness formula: always-present base |
| `streakBonusCap` | 0.10 | Max streak bonus added to happiness |
| `streakResetAfterMissedDays` | 2 | Days without 80% goals before streak resets |
| `appGroupID` | `"group.com.tamagoosie"` | Shared UserDefaults suite |
| `gooseStatsKey` | `"gooseStats"` | Key for encoded payload in app group |
