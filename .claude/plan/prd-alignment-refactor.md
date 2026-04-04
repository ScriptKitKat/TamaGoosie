# Implementation Plan: PRD Alignment Refactor

## Overview

Align the existing TamaGoosie MVP codebase with the canonical PRD spec. The current app is functionally complete but diverges significantly from the PRD in data model structure, stat system, formulas, and several features.

## Task Type
- [x] Frontend (SwiftUI views)
- [x] Backend (models, engines, services)
- [x] Fullstack (parallel)

---

## Gap Analysis: Current vs PRD

### Critical Divergences

| Area | Current | PRD | Impact |
|------|---------|-----|--------|
| **Stats** | 4 stats (health, happiness, energy, hygiene) 0-100 | 2 stats (healthiness, happiness) 0.0-1.0 | **Breaking** — affects every model, engine, view |
| **GooseState** | No spriteID/hatID/colorID/deathCause/reviveCount | Has cosmetic slots + death metadata | Schema change |
| **Goal.type** | Only frequency-based | `deadline` / `recurring` / `builtin` | New goal types |
| **Goal fields** | Missing dueDate, preferredTime, happinessWeight | Has all three | Schema extension |
| **DailyLog** | focusMinutes + stat snapshots | distraction tracking + healthiness/happiness delta | Different columns |
| **DistractionApp model** | Does not exist | Full distraction app tracking | New model |
| **UserProfile model** | Does not exist | Baselines + settings | New model |
| **Healthiness formula** | Fixed decay rates | Weighted composite of normalized HealthKit scores | Complete rewrite |
| **Happiness formula** | Fixed goal/focus rewards | Goal completion ratio + distraction penalty + streak bonus | Complete rewrite |
| **Decay** | 4-stat decay with floors at 5 | 2-stat decay, floors at 0.05, compound penalty | Rewrite |
| **Mood system** | 8 moods, avg of 4 stats | 7 moods (no neutral/sleeping), avg of 2 stats | Simplify |
| **Phase** | 5 phases (egg-elder) | 4 phases (egg-adult, no elder) | Remove elder |
| **Reward events** | Generic tiered rewards | Specific event table per PRD | Rewrite |
| **Watch sync payload** | GooseStats (4 stats) | GooseSyncPayload (2 stats + topGoals) | Breaking change |
| **Distraction cooldown** | Not implemented | Full-screen overlay + timer + tracking | New feature |
| **Adaptive notifications** | Basic reminders | Rolling 7-day averages, adaptive timing | New logic |
| **Built-in goals** | Not present | 4 pre-populated goals | Seed data |

### Things to Preserve

- SwiftUI app structure + tab navigation
- GooseCharacterView animations (kawaii goose)
- GoosieTheme + GoosieComponents design system
- HealthKitManager core queries (adjust output mapping)
- WatchSyncService WCSession infrastructure
- Widget TimelineProvider structure
- Onboarding flow (update content)
- FocusTimer / FocusSessionView (keep, but remove energy/hygiene stat impacts)
- Live Activity infrastructure

---

## Implementation Steps

### Sprint 1: Core Model Refactor (Foundation)

**Goal**: Migrate from 4-stat/0-100 system to 2-stat/0.0-1.0 system. This unblocks everything else.

#### Step 1.1: Update Shared Types

**Files**: `Shared/Constants.swift`, `Shared/GoosePhase.swift`, `Shared/GooseMood.swift`

- Replace `GoosieConstants` stat bounds: `statMin=0.0`, `statMax=1.0`, `statFloor=0.05`
- Replace decay rates: `healthDecay=0.008/hr`, `happinessDecay=0.012/hr`
- Remove `energy*` and `hygiene*` constants
- Remove `.elder` from `GoosePhase`, adjust thresholds: egg(first 24h), baby(1-5), teen(6-15), adult(16+)
- Rewrite `GooseMood` to 7 states: ecstatic/happy/content/bored/sad/sick/dead
- Mood derivation: `avg = (healthiness + happiness) / 2.0`, thresholds per PRD

#### Step 1.2: Rewrite GooseState Model

**File**: `TamaGoosie/Core/Models/GooseState.swift`

```swift
// Remove: energy, hygiene, daysAlive, totalGoalsCompleted, birthDate, hasCompletedOnboarding
// Rename: health → healthiness
// Add: id (UUID), spriteID, hatID, colorID, deathCause, reviveCount, createdAt
// Change defaults: healthiness=0.8, happiness=0.7, name="Harold"
// Update: clampStats() for 2 stats, updateMood() for new derivation
```

#### Step 1.3: Add New Models

**New file**: `TamaGoosie/Core/Models/DistractionApp.swift`
```swift
@Model final class DistractionApp {
    var id: UUID, bundleID: String, displayName: String, iconName: String?, dailyLimitMinutes: Int = 30
}
```

**New file**: `TamaGoosie/Core/Models/UserProfile.swift`
```swift
@Model final class UserProfile {
    var id: UUID, displayName: String?, joinDate: Date,
    avgSleepHours: Double = 8.0, avgSteps: Int = 6000,
    avgExerciseMinutes: Int = 30, avgSittingHours: Double = 8.0,
    notificationsEnabled: Bool = true, vacationMode: Bool = false, watchPaired: Bool = false
}
```

#### Step 1.4: Update Goal Model

**File**: `TamaGoosie/Core/Models/Goal.swift`

- Add: `type: String` (deadline/recurring/builtin), `dueDate: Date?`, `preferredTime: Date?`, `happinessWeight: Double = 1.0`
- Keep: id, title, category, frequency, targetCount, currentCount, isCompleted, completedAt, streakDays (rename to currentStreak), createdAt

#### Step 1.5: Update DailyLog Model

**File**: `TamaGoosie/Core/Models/DailyLog.swift`

- Add: `standHours: Int`, `sittingHours: Double`, `outsideMinutes: Int`, `distractionOpens: Int`, `distractionMinutes: Int`, `healthinessDelta: Double`, `happinessDelta: Double`
- Remove: `focusMinutes`, `healthStart/End`, `happinessStart/End`, `energyStart/End`, `hygieneStart/End`

#### Step 1.6: Update Sync Types

**File**: `Shared/GooseStats.swift` → rename to match PRD `GooseSyncPayload`
```swift
struct GooseSyncPayload: Codable {
    let healthiness: Double, happiness: Double, mood: String, phase: String,
    name: String, level: Int, streakDays: Int, isDead: Bool, spriteID: String,
    topGoals: [GoalSummary]  // max 3
}
```

Update `GoalSummary` to use `progress: Double` instead of currentCount/targetCount.

---

### Sprint 2: Engine Rewrite

**Goal**: Implement PRD formulas exactly.

#### Step 2.1: Rewrite GooseEngine

**File**: `TamaGoosie/Core/Services/GooseEngine.swift`

- `computeHealthiness(log:profile:)` — weighted composite per PRD (sleep/exercise/steps/sitting/outside)
- `computeHappiness(log:goals:)` — goal ratio + distraction penalty + streak bonus per PRD
- `completeGoal()` — apply `+0.05 * happinessWeight` to happiness, +10 XP
- `completeAllDailyGoals()` — +0.03 healthiness, +0.10 happiness, +25 XP
- Reward event table matching PRD exactly

#### Step 2.2: Rewrite DecayEngine

**File**: `TamaGoosie/Core/Services/DecayEngine.swift`

- 2-stat decay: healthDecay=0.008/hr, happinessDecay=0.012/hr
- Grace period: first 2 hours of 8+ hour absence = no decay ("goose napping")
- Compound penalty: if either stat < 0.2, both decay 0.004/hr extra
- Death: only when healthiness <= 0 (happiness alone can't kill)
- Set deathCause based on happiness level at death

#### Step 2.3: Rewrite RewardEngine

**File**: `TamaGoosie/Core/Services/RewardEngine.swift`

- Map PRD reward event table exactly (see PRD section)
- XP streak multiplier: `min(2.0, 1.0 + streak * 0.1)`
- Remove energy/hygiene deltas entirely
- Level-up keeps existing quadratic curve

---

### Sprint 3: View Layer Updates

**Goal**: Update all views for 2-stat system.

#### Step 3.1: GooseView + GooseViewModel

- Replace 4 stat bars with 2 (healthiness ring + happiness ring)
- Remove Feed/Clean quick actions, keep Goal/Exercise
- Update death screen to show deathCause
- Show reviveCount-based revival flow (free first, lesson second, 24h cooldown third+)

#### Step 3.2: GoalListView + GoalEditorView

- Add goal type picker (deadline/recurring/builtin)
- Add dueDate picker for deadline goals
- Add preferredTime picker for recurring goals
- Add happinessWeight slider
- Seed 4 built-in goals on first launch

#### Step 3.3: StatsDashboard / HealthDashboard

- Show healthiness + happiness as primary metrics
- Show breakdown: sleep score, exercise score, steps score, sitting score, outside score
- Show goal completion ratio + distraction stats

#### Step 3.4: SettingsView

- Move vacationMode to UserProfile
- Add distraction app configuration (DistractionConfigView)
- Add UserProfile baseline display/adjustment
- Remove hasCompletedOnboarding from GooseState (move to UserProfile or @AppStorage)

#### Step 3.5: FocusSessionView

- Keep timer mechanics
- Update rewards: focus completion → happiness boost only (no energy/hygiene)
- Remove FocusSession SwiftData model if not needed (or keep for history)

---

### Sprint 4: New Features

#### Step 4.1: Distraction Cooldown Overlay

**New file**: `TamaGoosie/Features/Focus/DistractionOverlay.swift`

- Full-screen overlay with dancing duck animation (1 min)
- Shows incomplete goals list
- After 1 min, dismiss button appears
- Increments `distractionOpens` in DailyLog
- Background timer tracks `distractionMinutes`

#### Step 4.2: UserProfile Baselines

- Auto-calculate baselines after 7 days of DailyLog data
- Use baselines in `computeHealthiness()` normalization

#### Step 4.3: Adaptive Notifications

**File**: `TamaGoosie/Features/Settings/NotificationManager.swift`

- Track rolling 7-day completion times per goal
- Shift reminder to match actual pattern
- If completion rate < 40% over 2 weeks → suggest simplifying
- State-based notifications per PRD (Harold speaks in first person)
- Rate limit: max 5/day, quiet hours 10pm-7am

---

### Sprint 5: Watch + Widget + Live Activity

#### Step 5.1: Watch Sync

- Update WatchSyncService to send `GooseSyncPayload` (includes topGoals)
- Watch receives goal completions → sends to iPhone via WCSession
- Update GooseGlanceView for 2-stat display (healthiness ring + mood)

#### Step 5.2: Complications

- `accessoryCircular`: healthiness ring with mood emoji
- `accessoryRectangular`: name + health bar + streak count
- `accessoryInline`: "Harold: 85% heart | fire 12 days"

#### Step 5.3: Widget Update

- Small: goose sprite + healthiness ring + mood text
- Medium: goose sprite + top 3 goals with progress bars
- Add AppIntent for "tap to increment goal" without opening app

#### Step 5.4: Live Activity / Dynamic Island

- Minimal: tiny goose + healthiness %
- Compact: goose (leading) + "Focus: 23 min left" (trailing)
- Expanded: goose with mood animation + goal progress + timer
- Happy hopping (>0.6) vs sluggish wobble (<0.2)

---

### Sprint 6: Testing & Polish

#### Step 6.1: Unit Tests

- `GooseEngineTests`: healthiness formula, happiness formula, all edge cases
- `DecayEngineTests`: grace period, compound penalty, death trigger
- `RewardEngineTests`: all event types, streak multiplier, level-up
- Edge cases: 0 sleep, 50k steps, all goals completed, no goals set

#### Step 6.2: Integration Tests

- Goal completion → stat change → mood update → widget sync pipeline
- Watch sync payload encoding/decoding
- DailyLog creation and HealthKit data mapping

#### Step 6.3: Anti-Burnout Verification

- Grace period works correctly
- Stat floor at 0.05 prevents instant death
- Vacation mode pauses everything
- Revival flow matches PRD (free → lesson → 24h cooldown)
- Adaptive difficulty triggers at correct thresholds

---

## Key Files

| File | Operation | Description |
|------|-----------|-------------|
| `Shared/Constants.swift` | **Rewrite** | 2-stat constants, 0.0-1.0 scale |
| `Shared/GoosePhase.swift` | **Modify** | Remove elder phase |
| `Shared/GooseMood.swift:L35-96` | **Rewrite** | 7 moods, 2-stat derivation |
| `Shared/GooseStats.swift` | **Rewrite** → `GooseSyncPayload` | 2 stats + topGoals |
| `Shared/SyncPayload.swift` | **Modify** | Update GoalSummary |
| `TamaGoosie/Core/Models/GooseState.swift` | **Rewrite** | 2 stats, add cosmetics/death fields |
| `TamaGoosie/Core/Models/Goal.swift` | **Modify** | Add type, dueDate, preferredTime, happinessWeight |
| `TamaGoosie/Core/Models/DailyLog.swift` | **Rewrite** | Add distraction/sitting/outside fields |
| `TamaGoosie/Core/Models/DistractionApp.swift` | **Create** | New model |
| `TamaGoosie/Core/Models/UserProfile.swift` | **Create** | New model |
| `TamaGoosie/Core/Services/GooseEngine.swift` | **Rewrite** | PRD formulas |
| `TamaGoosie/Core/Services/DecayEngine.swift` | **Rewrite** | 2-stat decay |
| `TamaGoosie/Core/Services/RewardEngine.swift` | **Rewrite** | PRD reward table |
| `TamaGoosie/Features/Goose/GooseView.swift` | **Modify** | 2 stat bars |
| `TamaGoosie/Features/Goose/GooseViewModel.swift` | **Modify** | 2-stat logic |
| `TamaGoosie/Features/Goals/GoalEditorView.swift` | **Modify** | New fields |
| `TamaGoosie/Features/Focus/DistractionOverlay.swift` | **Create** | Cooldown overlay |
| `TamaGoosie/Features/Settings/SettingsView.swift` | **Modify** | UserProfile integration |
| `TamaGoosie/Features/Settings/DistractionConfigView.swift` | **Modify** | Wire to DistractionApp model |
| `TamaGoosieWatch/GooseGlanceView.swift` | **Modify** | 2-stat display |
| `TamaGoosieWidgets/GooseWidget.swift` | **Modify** | 2-stat + goal progress |
| `Tests/GooseEngineTests.swift` | **Rewrite** | PRD formula tests |

## Risks and Mitigation

| Risk | Mitigation |
|------|------------|
| SwiftData migration from 4-stat → 2-stat could lose data | Use `VersionedSchema` with migration plan; map old values: `healthiness = health/100`, `happiness = happiness/100`, drop energy/hygiene |
| Watch sync payload change breaks existing Watch app | Version the payload; Watch falls back gracefully if fields missing |
| Distraction detection without Screen Time API is limited | MVP uses manual tracking + focus timer; full DeviceActivityMonitor is v2 per PRD |
| HealthKit UV exposure only on Watch | Check `profile.watchPaired`; skip outsideScore weight if no Watch data (already in PRD formula) |
| 4-stat views (GooseCharacterView animations) reference energy/hygiene | Audit all animation mood triggers; map to 2-stat thresholds |

## Recommended Execution Order

1. **Sprint 1** first — everything depends on the model change
2. **Sprint 2** immediately after — engines must match new models
3. **Sprint 3** can parallel across team members (Person B handles views)
4. **Sprint 4** can start once engines work (Person C handles distraction overlay)
5. **Sprint 5** depends on Sprint 2 sync payload (Person A handles Watch)
6. **Sprint 6** runs continuously but final pass after Sprint 4

## SESSION_ID (for /ccg:execute use)
- CODEX_SESSION: N/A (codeagent-wrapper not available)
- GEMINI_SESSION: N/A (codeagent-wrapper not available)
