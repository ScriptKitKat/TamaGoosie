# Stat System

The goose has exactly **two stats**, both stored as `Double` on a **0.0–1.0 scale** in `GooseState`. They are displayed as `Int(stat * 100)` percent in the UI. Never store percent values in the model.

---

## The Two Stats

### Healthiness
Reflects physical wellbeing. Driven primarily by HealthKit data. Falls faster than happiness when neglected.

**Decay rate**: 0.008 per hour baseline.

**Reward sources**:
- 10,000+ steps → +0.05 healthiness, +0.02 happiness, +5 XP
- 30+ minutes exercise → +0.05 healthiness, +0.03 happiness, +8 XP
- Good sleep (7–9h) → +0.07 healthiness, +0.05 happiness, +10 XP
- Bad sleep (<5h) → -0.05 healthiness, -0.03 happiness
- All goals completed bonus → +0.03 healthiness, +0.10 happiness, +20 XP

**Death trigger**: healthiness reaches 0. Happiness alone cannot kill the goose.

### Happiness
Reflects emotional/motivational wellbeing. Driven primarily by goal completion.

**Decay rate**: 0.012 per hour baseline.

**Reward sources**:
- Goal completion → base 0.05 × `happinessWeight`, scaled by streak multiplier
- Focus session → 2 XP/min + small happiness bonus
- Distraction penalty → -0.02 per distraction app open

---

## XP and Leveling

XP is stored as `Int` on `GooseState`. Level thresholds follow:

```
xpForLevel(level) = 100 + (level - 1) * 150
```

| Level | XP to next level |
|-------|-----------------|
| 1 | 100 |
| 2 | 250 |
| 3 | 400 |
| ... | ... |
| 50 | (max level) |

`RewardEngine.applyDelta` handles level-up: when `xp >= xpForLevel(level)`, subtract the threshold and increment level. `GooseEngine.uncompleteGoal` handles level-down: if XP goes negative from a refund, loop backwards through levels.

**Phase** is derived from level (see `docs/goose.md`).

---

## Decay (`DecayEngine`)

`DecayEngine.applyDecay(to:)` is called once per 60-second tick (and on app open via `GooseEngine.update`).

### Algorithm

```
1. Skip if: vacation mode, isDead, or < 0.5 hours since lastUpdated

2. Compute elapsed hours since lastUpdated

3. Grace period:
   If elapsed >= 8 hours: effective hours = elapsed - 2  (first 2h of long absence are free)

4. Base decay:
   healthiness -= 0.008 * hours
   happiness   -= 0.012 * hours

5. Compound penalty:
   If healthiness < 0.2 OR happiness < 0.2:
     healthiness -= 0.004 * hours  (extra penalty)
     happiness   -= 0.004 * hours

6. Death check:
   If healthiness <= 0:
     isDead = true
     deathCause = "neglect" or based on which stat was lowest

7. Clamp both stats to [0.0, 1.0]
8. state.lastUpdated = .now
```

### Key Details
- Stats cannot go below 0.0 or above 1.0.
- Happiness cannot directly cause death — only healthiness triggers `isDead`.
- `deathCause` is set to a message based on whether healthiness or happiness was the primary cause.
- Vacation mode (`isVacationMode = true`) completely skips decay.

---

## Rewards (`RewardEngine`)

All reward functions return a `StatDelta`:

```swift
struct StatDelta {
    var healthiness: Double = 0
    var happiness: Double   = 0
    var xp: Int             = 0
}
```

`RewardEngine.applyDelta(_:to:)` adds the delta to the state, clamps, handles leveling, and updates mood. **It never syncs** — callers are responsible for calling `saveStatsToAppGroup` after.

### Streak Multiplier

Applied to XP (not happiness) on goal completion:

```
multiplier = min(1.0 + streakDays * 0.1, 2.0)
```

| Streak | Multiplier |
|--------|-----------|
| 0 days | 1.0× |
| 5 days | 1.5× |
| 10+ days | 2.0× (cap) |

### Streak Milestones

At days `[7, 14, 30, 60, 90, 180, 365]`, a milestone bonus fires:
- +0.05 healthiness, +0.10 happiness, +50 XP

---

## All-Goals Completion Bonus

`GooseEngine.checkAllGoalsCompleted(goals:state:)` is called after each recurring goal completion. If all active goals are completed:
- +0.03 healthiness, +0.10 happiness, +20 XP

This fires once per "all completed" event, not once per goal.

---

## Uncomplete / Refund

When a user uncompletes a recurring goal, `GooseEngine.uncompleteGoal` refunds the exact amounts:

```swift
xpRefunded = Int(Double(goalCompletionXP) * streakMultiplier(for: state.streakDays))
happinessRefunded = goalCompletionHappinessBase * goal.happinessWeight
```

- If XP goes negative, level-down loop runs: `level--; xp += xpForLevel(level)`
- `goal.currentStreak` is decremented by 1 (min 0) to prevent spam farming
- Deadline goals (`type == "deadline"`) cannot be uncompleted

---

## HealthKit Integration

`HealthKitManager.fetchTodayStats()` returns a `HealthSnapshot`. `GooseEngine.processHealthData(steps:exerciseMinutes:sleepHours:state:)` runs each through its reward function and combines the deltas:

```
steps reward    → healthiness, happiness, xp
exercise reward → healthiness, happiness, xp
sleep reward    → healthiness, happiness, xp
─────────────────────────────────────────────
combined delta applied once
```

`HealthDashboard` marks `wasProcessed = true` on the `HealthSnapshot` after processing to prevent double-applying.

---

## Constants Reference (`GoosieConstants`)

| Constant | Value | Meaning |
|----------|-------|---------|
| `decayRateHealthiness` | 0.008/hr | Base healthiness decay |
| `decayRateHappiness` | 0.012/hr | Base happiness decay |
| `compoundDecayPenalty` | 0.004/hr | Extra decay when either stat < 0.2 |
| `gracePeriodHours` | 2.0 | Hours forgiven in long absences |
| `gracePeriodThreshold` | 8.0 | Hours absence before grace applies |
| `goalCompletionHappinessBase` | 0.05 | Base happiness per goal completion |
| `goalCompletionXP` | 10 | Base XP per goal completion |
| `allGoalsCompletionXP` | 20 | Bonus XP for completing all goals |
| `streakMaxMultiplier` | 2.0 | Cap on streak XP multiplier |
| `streakResetAfterMissedDays` | 2 | Days without 80% goals before streak resets |
| `revivalCooldownHours` | 24 | Cooldown after 3+ deaths |
| `revivalCooldownAfterDeathCount` | 3 | Number of deaths before cooldown kicks in |
| `appGroupID` | `"group.com.tamagoosie"` | Shared UserDefaults suite |
| `gooseStatsKey` | `"gooseStats"` | Key for encoded payload in app group |
