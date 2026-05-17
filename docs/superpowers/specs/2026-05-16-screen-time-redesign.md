# Screen Time Page Redesign: Stats + Blocks

## Overview

Split the current Screen Time page into two tabs: **Stats** (read-only usage data) and **Blocks** (manage app-blocking rules). Replace the existing single-plan blocking model with four distinct block types. Replace `FocusSessionView` with the new "Block Now" block type.

## Page Structure

`ScreenTimePageView` remains the top-level container:
- If `!manager.isSetupComplete` -> show `ScreenTimeOnboardingView` (unchanged)
- Otherwise -> show a `ScreenTimeTabPicker` (Stats / Blocks) above the active tab content

### Stats Tab (`ScreenTimeStatsTab`)

Replaces `ScreenTimeDashboardView`. Read-only, no action buttons. Layout top to bottom:

1. **Date navigation** - left/right chevrons with date label, day/week period picker (existing logic preserved)
2. **Hero stat** - large distraction time number (e.g., "2h 15m") with "SCREEN TIME" subtitle and change-vs-yesterday badge
3. **Quick stats row** - two compact cards side by side:
   - Limit Remaining (time left before block triggers)
   - Distraction Opens (count from `DailyLog.distractionOpens`)
4. **DeviceActivityReport** - embedded at ~250pt height for per-app usage breakdown with real app names/icons (system-rendered, privacy-compliant)

Data sources: `DailyLog`, `ScreenTimeManager.approxMinutesToday`, `DeviceActivityReport`.

### Blocks Tab (`ScreenTimeBlocksTab`)

Layout top to bottom:

1. **Active Blocks** - cards for each active/scheduled `ScreenBlock`:
   - Block name + type icon
   - Status badge: "Active" (running), "Starting in Xh Xm" (scheduled), "Disabled" (vacation mode)
   - Schedule summary (e.g., "Every day, 06:00 - 08:30" or "30m daily limit")
   - Tap card to edit

2. **New Block** - row of 4 quick-action buttons:
   - Block Now (timer icon)
   - Schedule Session (calendar icon)
   - App Limit (hourglass icon)
   - Lock (lock icon)
   - Each opens the corresponding creation sheet

3. **Past** - collapsible section (chevron toggle, like quest history):
   - Completed Block Now sessions: name, date, duration
   - Expired/ended recurring sessions: name, last active date
   - Sorted by completedAt descending

4. **Empty state** - when no blocks exist: "No blocks set up" message with a "Block Now" CTA button

## Block Types

### 1. Block Now

Replaces `FocusSessionView`. Immediately blocks selected apps for a set duration.

**Creation sheet (`BlockNowSheet`):**
- Name field (default: "Focus Session")
- Duration picker (stepper: 5m increments, 5-120m)
- Apps Blocked (opens `FamilyActivityPicker`)
- "Start Session" button

**Active state:** Shows countdown timer UI (ring + time remaining) within the sheet. When timer completes, the `ScreenBlock` is marked completed (sets `endedAt`, `completedAt`) and moves to Past.

### 2. Schedule Session

Recurring time-based block. Apps are blocked during the scheduled window.

**Creation sheet (`ScheduleSessionSheet`):**
- Name field
- From / To time pickers
- Days of week active (circle buttons)
- Apps Blocked (opens `FamilyActivityPicker`)
- Vacation Mode toggle (temporarily disables without deleting)
- "Save" button

### 3. App Limit

Daily time budget. After the allowed time is used, apps are blocked for the rest of the day.

**Creation sheet (`AppLimitSheet`):**
- Name field
- App selection (opens `FamilyActivityPicker`)
- Time Allowed (stepper: 15m increments, 15-240m)
- Days of week active (circle buttons)
- "Save" button

### 4. Lock

Apps start blocked. User can unlock a set number of times per day, each unlock lasting a set duration.

**Creation sheet (`LockSheet`):**
- Name field
- App selection (opens `FamilyActivityPicker`)
- Opens Allowed per day (stepper: 1-20)
- For Up To (duration per unlock, stepper: 5m increments, 5-60m)
- Days of week active (circle buttons)
- "Save" button

## Data Model

New SwiftData `@Model` class: `ScreenBlock`

```
ScreenBlock
  id: UUID
  name: String
  type: String                    // "blockNow" | "schedule" | "appLimit" | "lock"
  isActive: Bool
  createdAt: Date

  // App selection (encoded FamilyActivitySelection)
  selectionData: Data?

  // Block Now fields
  durationMinutes: Int            // target duration (5-120)
  startedAt: Date?                // when session began
  endedAt: Date?                  // when session ended

  // Schedule fields
  scheduleStartHour: Int
  scheduleStartMinute: Int
  scheduleEndHour: Int
  scheduleEndMinute: Int
  activeDays: String              // comma-separated weekday numbers (1=Sun...7=Sat)
  isVacationMode: Bool

  // App Limit fields
  timeLimitMinutes: Int           // daily allowed minutes

  // Lock fields
  opensAllowed: Int               // max opens per day
  unlockDurationMinutes: Int      // duration per unlock
  opensUsedToday: Int             // resets daily

  // Tracking
  completedAt: Date?              // non-nil = in Past section
```

Only the fields relevant to a block's `type` are used; others stay at default values. This avoids a complex inheritance hierarchy while keeping a single queryable table.

## ScreenTimeManager Changes

- Replace the single "daily-distraction" `DeviceActivityCenter` monitor with per-block monitors
- Each `ScreenBlock` gets its own `DeviceActivityName` (e.g., "block-{id}")
- New methods:
  - `registerBlock(_ block: ScreenBlock)` - starts monitoring for the block
  - `unregisterBlock(_ block: ScreenBlock)` - stops monitoring
  - `refreshAllBlocks(_ blocks: [ScreenBlock])` - called on app launch to re-register active blocks
- Existing schedule/limit properties remain for backward compatibility during migration but are no longer used by the new UI

## Shared Components

Extracted for reuse across all four creation sheets:
- `DayOfWeekPicker` - row of 7 circle buttons (extracted from existing `ScreenTimeScheduleView`)
- `FamilyActivityPicker` usage pattern - already exists, just reused

## Files

**New:**
- `TamaGoosie/Core/Models/ScreenBlock.swift`
- `TamaGoosie/Features/ScreenTime/ScreenTimeTabPicker.swift`
- `TamaGoosie/Features/ScreenTime/ScreenTimeStatsTab.swift`
- `TamaGoosie/Features/ScreenTime/ScreenTimeBlocksTab.swift`
- `TamaGoosie/Features/ScreenTime/BlockNowSheet.swift`
- `TamaGoosie/Features/ScreenTime/ScheduleSessionSheet.swift`
- `TamaGoosie/Features/ScreenTime/AppLimitSheet.swift`
- `TamaGoosie/Features/ScreenTime/LockSheet.swift`
- `TamaGoosie/Features/ScreenTime/BlockCardView.swift`
- `TamaGoosie/Features/ScreenTime/DayOfWeekPicker.swift`

**Modified:**
- `ScreenTimePageView.swift` - add tab picker, route to Stats/Blocks tabs
- `ScreenTimeManager.swift` - add per-block monitoring methods
- `ContentView.swift` - remove FocusSessionView references if present

**Replaced:**
- `ScreenTimeDashboardView.swift` -> `ScreenTimeStatsTab.swift`
- `FocusSessionView.swift` -> `BlockNowSheet.swift` (keep `FocusSession` model for historical data)

## Integration with Existing Systems

- `DailyLog` continues to accumulate `distractionMinutes` and `distractionOpens` from the DeviceActivity extension — Stats tab reads these
- `GooseEngine` happiness formula still uses `distractionMinutes` from `DailyLog` — no changes needed
- `DistractionOverlay` (the "come back" full-screen cover) stays as-is — it's triggered by the DeviceActivity extension independently
- `ScreenTimeOnboardingView` stays unchanged — it gates access to both tabs
- `FocusSession` model preserved for historical records; new Block Now sessions create `ScreenBlock` records
- `ScreenTimeScheduleView` can be removed once the new sheets are in place (its functionality is absorbed by `ScheduleSessionSheet`)

## Out of Scope

- Difficulty levels (Opal's Normal/Timeout/Hard) — keep blocks simple for now
- Block overlap detection/warnings
- Block screens / custom shield UI customization
- Sync blocks to Watch or Widget
