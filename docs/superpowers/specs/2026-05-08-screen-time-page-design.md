# Screen Time Page — Design Spec

**Date:** 2026-05-08

## Summary

Add a Screen Time page to the side menu with a first-visit onboarding flow, schedule-based app limiting, and a rich stats dashboard. Fix the broken data pipeline so distraction minutes affect happiness. Personalize notifications and shield text with the goose's name.

## 1. Navigation

- "Screen Time" added as side menu item id 6 (between Stats=4 and Settings, bumped to id 7).
- Icon: `hourglass` (system image).
- Page uses existing `subpageHeader` pattern (no NavigationView).

## 2. Page States

### State 1: First Visit — Onboarding Flow

Triggered when `screenTimeSetupComplete` is false in UserDefaults. Presented as a multi-step flow within the page (not a sheet/fullScreenCover). Progress shown via segmented bar dots at the top (like Forest).

**Step 1 — Awareness:** "Do you know how long you scroll each day?" GooseCharacterView (bored mood) centered. Button: "probably... too long?"

**Step 2 — Problem:** "One quick scroll... and 30 minutes are gone." GooseCharacterView (sad mood). Button: "that's me..."

**Step 3 — Solution:** "{gooseName} will help guard your time!" GooseCharacterView (ecstatic mood). Button: "Let's set it up!"

**Step 4 — Permissions:** Title: "Enable Screen Time Guard". Two toggle rows in cards:
- Screen Time — toggle triggers `AuthorizationCenter.shared.requestAuthorization(for: .individual)`
- Notifications — toggle triggers `UNUserNotificationCenter.requestAuthorization`
Caption: "Data is stored only on your device." Button: "Let's Go" (enabled when Screen Time is authorized).

**Step 5 — App Selection:** Title: "Choose apps to limit". Opens FamilyActivityPicker inline via `.familyActivityPicker(isPresented:selection:)`. User selects distraction apps/categories. Button: "Continue" (enabled when selection is non-empty).

**Step 6 — Schedule & Limit:** Title: "Set your limits". Contains:
- **Daily limit** stepper (15–120 min, step 15, default 30)
- **Schedule** section with "All the time" toggle. When off:
  - From time picker (default 8:00 AM)
  - To time picker (default 10:00 PM)
- **Active days** — 7 circle buttons (S M T W T F S), all selected by default, tappable to toggle
- Button: "Save" — persists config, starts monitoring, sets `screenTimeSetupComplete = true`

### State 2: After Setup — Dashboard

**Header section:**
- Day/Week segmented picker
- Date navigation: `< May 8, 2026 (Today) >`

**Stat cards** (side by side in HStack):
- Left: "Distraction Time" — shows minutes/hours on tracked apps today, with change % vs yesterday (green down arrow = good, red up arrow = bad). Falls back to "No prior data" if no yesterday log.
- Right: "Total Screen Time" — total device usage if available from DeviceActivityReport, with change %.

**Distribution chart:**
- DeviceActivityReport embedded view showing hourly breakdown
- Legend: Distraction Apps (coral) vs Other Apps (teal)

**Bottom section:**
- "Edit Plan" button — reopens schedule/limit/app config (reuses Step 5+6 UI)
- "Pause Plan" toggle — calls `ScreenTimeManager.stopMonitoring()` when on, `startDailyMonitoring()` when off. Persisted to UserDefaults.

## 3. Schedule Support

`ScreenTimeManager` gains new persisted fields:
- `scheduleStartHour: Int` / `scheduleStartMinute: Int` (default 0:00 = all day)
- `scheduleEndHour: Int` / `scheduleEndMinute: Int` (default 23:59)
- `activeDays: Set<Int>` (1=Sunday through 7=Saturday, default all 7)
- `isAllDay: Bool` (default true)
- `isPaused: Bool` (default false)

`startDailyMonitoring()` uses these to build `DeviceActivitySchedule` with the user's chosen interval and only starts monitoring on active days.

## 4. Data Pipeline Fix

In `ContentView.syncHealthData()`, after health data sync:
1. Read `distractionApproxMinutes` from `UserDefaults(suiteName: appGroupID)`
2. Write to `todayLog.distractionMinutes`
3. This feeds into `RewardEngine.computeHappiness(log:goals:)` which already penalizes via `distractionWeight * (minutes / maxMinutes)`

## 5. Goose Name Personalization

Both extension targets read goose name from app group UserDefaults:
```
let defaults = UserDefaults(suiteName: "group.com.tamagoosie")
let name: String
if let data = defaults?.data(forKey: "gooseStats"),
   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    name = json["name"] as? String ?? "Your goose"
} else {
    name = "Your goose"
}
```

- **DeviceActivityMonitorExtension** — notification title: "{name} is worried" / body uses name
- **ShieldConfigurationProvider** — title: "{name} needs you!" / subtitle: "Take a break and check on {name}"

## 6. Files

| File | Change |
|------|--------|
| `ContentView.swift` | Add menu item id 6, bump Settings to 7, render ScreenTimePageView, sync distraction minutes to DailyLog |
| New: `Features/ScreenTime/ScreenTimePageView.swift` | Container switching between onboarding and dashboard based on `screenTimeSetupComplete` |
| New: `Features/ScreenTime/ScreenTimeOnboardingView.swift` | 6-step onboarding: 3 intro + permissions + app picker + schedule config |
| New: `Features/ScreenTime/ScreenTimeDashboardView.swift` | Stats dashboard with day/week toggle, stat cards, chart, edit/pause |
| New: `Features/ScreenTime/ScreenTimeScheduleView.swift` | Reusable schedule/limit config (used by onboarding step 6 and "Edit Plan") |
| `ScreenTimeManager.swift` | Add schedule fields, activeDays, isPaused, isAllDay. Update startDailyMonitoring to use schedule. |
| `DistractionConfigView.swift` | Deprecated — functionality absorbed into new views |
| `DeviceActivityMonitorExtension.swift` | Read goose name from UserDefaults for notifications |
| `ShieldConfigurationProvider.swift` | Read goose name from UserDefaults for shield text |
| `Constants.swift` | Add `screenTimeSetupCompleteKey`, `screenTimePausedKey`, schedule keys |

## 7. Constraints

- DeviceActivityMonitorExtension and ShieldConfigurationProvider run in separate extension processes — no SwiftData access. Must use UserDefaults via app group and JSON parsing (not GooseSyncPayload Codable, since Shared/ may not be compiled into extensions).
- DeviceActivityReport requires the `DeviceActivity` framework and a report extension target (`Extensions/Report/`). The existing `DistractionReportScene` will be used.
- The side menu reordering bumps Settings from id 5 to id 7. All `selectedTab == 5` references for Settings must update.
- Schedule with active days requires stopping/restarting monitoring at day boundaries. DeviceActivitySchedule's `repeats: true` handles daily reset; day filtering is done by checking current weekday before starting.
