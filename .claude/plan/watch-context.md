# Watch Target: Context & Status

_Last updated: 2026-04-04_

---

## Architecture

The Watch app is a **read-only mirror** of the iOS app. The iPhone is the sole source of truth.

```
iPhone (GooseEngine)
  └─ saveStatsToAppGroup()
        ├─ UserDefaults("group.com.tamagoosie")  →  Widget
        └─ WatchSyncService.sendPayload()
              └─ WCSession (ApplicationContext + live message)
                    └─ WatchSyncReceiver.currentPayload  →  all Watch views
```

Watch can **send back** goal completions via `WatchSyncReceiver.sendGoalCompletion(goalID:)`, which the iPhone handles in `WatchSyncService`.

---

## Files

| File | Role | Status |
|------|------|--------|
| `WatchApp.swift` | `@main` entry point; renders `GooseGlanceView` | ✅ Done |
| `WatchSyncReceiver.swift` | `WCSessionDelegate`; holds `currentPayload: GooseSyncPayload`; sends goal completions | ✅ Done |
| `WatchTheme.swift` | Design tokens (colors, typography) for all Watch views | ✅ Done |
| `DuckFaceView.swift` | SwiftUI-drawn duck character (circle body + beak + eyes) | ✅ Done |
| `GooseGlanceView.swift` | Root scroll view: glance ring → goals → today stats | ✅ Done |
| `QuickLogView.swift` | Standalone goals list with tap-to-complete; shown as sheet from glance | ✅ Done |
| `WatchStatsView.swift` | Standalone stats view (steps/exercise/sleep/stand); **not yet wired into navigation** | ⚠️ Built, not wired |
| `Complications/GooseComplication.swift` | WidgetKit complication for Watch face; `GooseComplicationWidget` has **no `@main`** | ✅ Done |

---

## Sync Payload (`GooseSyncPayload`)

Defined in `Shared/GooseStats.swift`. Compiled into iOS, Watch, and Widget targets.

| Field | Type | Source | Notes |
|-------|------|--------|-------|
| `healthiness` | `Double` | `GooseState` | 0.0–1.0 |
| `happiness` | `Double` | `GooseState` | 0.0–1.0 |
| `mood` | `String` | `GooseState.mood` | `GooseMood.rawValue` |
| `phase` | `String` | `GooseState.phase` | `GoosePhase.rawValue` |
| `name` | `String` | `GooseState.name` | Default "Harold" |
| `level` | `Int` | `GooseState.level` | |
| `streakDays` | `Int` | `GooseState.streakDays` | |
| `isDead` | `Bool` | `GooseState.isDead` | |
| `spriteID` | `String` | `GooseState.spriteID` | |
| `topGoals` | `[GoalSummary]` | `GooseEngine` call sites | Up to 5 goals |
| `steps` | `Int` | `GooseEngine.cachedSteps` | Populated by `processHealthData` |
| `exerciseMinutes` | `Int` | `GooseEngine.cachedExerciseMinutes` | Populated by `processHealthData` |
| `sleepHours` | `Double` | `GooseEngine.cachedSleepHours` | Populated by `processHealthData` |
| `standHours` | `Int` | `GooseEngine.cachedStandHours` | Populated by `processHealthData`; requires `standHours:` param |

**All fields have default values** (0 / false / empty string) so old Watch/Widget decoders remain backward compatible.

---

## GooseGlanceView Layout

The root view is a single `ScrollView` with three sections stacked vertically:

```
┌─────────────────────────────┐
│  [double health ring]       │  ← healthiness (outer teal) + happiness (inner coral)
│  Harold                     │
│  Lvl 3 · happy              │
│  ▓▓▓▓▓░  Health             │
│  ▓▓▓░░░  Happy              │
├─────────────────────────────┤
│  Today's goals              │
│  [goal card 1]  ✓           │
│  [goal card 2]  ◉           │
│  [goal card 3]  ○           │
│  ...up to 5...              │
├─────────────────────────────┤
│  Today                      │
│  ● Steps      7,432  ▓▓▓░   │  ← NOW from payload.steps (real data)
│  ● Exercise   28 min ▓▓░░   │  ← NOW from payload.exerciseMinutes
│  ● Sleep      7.1 hr ▓▓▓░   │  ← NOW from payload.sleepHours
│  ● Stand      9 hr   ▓▓▓░   │  ← NOW from payload.standHours
└─────────────────────────────┘
```

Goal cards are tappable (sends completion to phone). Stats are read-only.

---

## WatchStatsView

`WatchStatsView` is built and takes explicit health parameters:

```swift
WatchStatsView(steps: Int, exerciseMinutes: Int, sleepHours: Double, standHours: Int)
```

**It is not yet wired into any navigation.** To show it as a dedicated screen or sheet, add a navigation trigger in `GooseGlanceView` and pass `payload.*` values:

```swift
// In GooseGlanceView:
WatchStatsView(
    steps: payload.steps,
    exerciseMinutes: payload.exerciseMinutes,
    sleepHours: payload.sleepHours,
    standHours: payload.standHours
)
```

---

## QuickLogView

Standalone goals list shown as a sheet (or tab). Shows up to 5 goals (`prefix(5)`). Each goal card has:
- Title + radio indicator (empty / partial / checkmark)
- 4px capsule progress bar
- "Not started / X% done / Complete!" label
- Tap sends `sendGoalCompletion(goalID:)` to phone

---

## Design Tokens (`WatchTheme`)

```swift
WatchTheme.cream          // #FFF8F0 background
WatchTheme.card           // #FFFCF7 card background
WatchTheme.border         // #E8E0D4 empty bar / ring track
WatchTheme.text           // #4A3728 primary text
WatchTheme.textSecondary  // #A09080 secondary text

WatchTheme.teal           // #7ECBC4 health, active states
WatchTheme.coral          // #F4A683 happiness, exercise
WatchTheme.yellow         // #FFD97A streak, XP, study goals
WatchTheme.lavender       // #B4A8E8 mindfulness goals
WatchTheme.stepsBlue      // steps stat dot color
WatchTheme.sleepPurple    // sleep stat dot color
WatchTheme.exerciseDark   // exercise value text
WatchTheme.sleepPurpleDark// sleep value text
WatchTheme.standDark      // stand value text
```

---

## Complications

`GooseComplication.swift` provides two complication views:
- `GooseComplicationCircular` — duck face inside health ring
- `GooseComplicationRectangular` — duck + name + health bar + streak

Both read from `UserDefaults(suiteName: "group.com.tamagoosie")` via the `GooseComplicationProvider`. They update every 30 minutes via WidgetKit timeline.

`GooseComplicationWidget` is the `Widget` struct. **No `@main` — that lives in `WatchApp.swift`.**

---

## Known Gaps / Next Work

| Item | Priority | Notes |
|------|----------|-------|
| Wire `WatchStatsView` into navigation | Medium | Add sheet/tab in `GooseGlanceView`; pass `payload.*` values |
| `standHours` from HealthKit on phone | Medium | `processHealthData` now accepts `standHours:` param; callers need to pass real value from `DailyLog.standHours` |
| Goal completion feedback on Watch | Low | Currently fire-and-forget; no visual confirmation after send |
| Complication live preview in Simulator | Low | Requires paired device; skip for simulator testing |
| Haptic feedback on goal tap | Low | `WKHapticType.success` on completion |

---

## Build Commands

```bash
# iOS + Watch (run iOS scheme to install both)
xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

# Watch only
xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosieWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  build
```

> Always run the **iOS scheme** to install both apps together on the simulator pair.
