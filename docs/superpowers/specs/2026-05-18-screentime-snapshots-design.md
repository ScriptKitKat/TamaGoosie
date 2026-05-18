# Screen Time Snapshots — Yesterday & Weekly Aggregates

**Date:** 2026-05-18
**Status:** Approved

## Overview

Add persistent screen time data capture so users can view yesterday's stats and a rolling 7-day weekly aggregate. The existing dropdown picker in `ScreenTimeTabPicker` (Today / Yesterday / This Week) drives navigation between live and historical views.

## Data Model

### `ScreenTimeSnapshot` (SwiftData `@Model`)

One row per calendar day. Upserted on capture — partial snapshots are overwritten by more complete ones.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Primary key |
| `date` | `Date` | Start-of-day for the snapshot |
| `isComplete` | `Bool` | `true` = end-of-day capture, `false` = partial/in-progress |
| `totalScreenTimeSeconds` | `Int` | Total screen time for the day |
| `totalPickups` | `Int` | Number of device pickups |
| `focusLevelPercent` | `Int` | 0-100, percentage of time in non-distracting apps |
| `timeOfflinePercent` | `Int` | 0-100, percentage of waking hours offline |
| `topAppsData` | `Data` | JSON-encoded `[AppUsageRecord]` — top apps |
| `allAppsData` | `Data` | JSON-encoded `[AppUsageRecord]` — full list |
| `hourlyData` | `Data` | JSON-encoded `[HourlyRecord]` — per-hour breakdown |
| `distractingMinutes` | `Int` | Minutes in distracting apps |
| `productiveMinutes` | `Int` | Minutes in productive apps |
| `neutralMinutes` | `Int` | Minutes in neutral apps |
| `capturedAt` | `Date` | Timestamp of when this snapshot was taken |

### Supporting Codable Structs

```swift
struct AppUsageRecord: Codable {
    let name: String
    let bundleID: String?
    let tokenKey: String?
    let durationSeconds: Int
    let category: String // "productive" | "neutral" | "distracting"
}

struct HourlyRecord: Codable {
    let hour: Int       // 0-23
    let focusedSeconds: Int
    let distractedSeconds: Int
}
```

### Staging Payload

```swift
struct ScreenTimeSnapshotPayload: Codable {
    let dateString: String          // "yyyy-MM-dd"
    let totalScreenTimeSeconds: Int
    let totalPickups: Int
    let focusLevelPercent: Int
    let timeOfflinePercent: Int
    let topApps: [AppUsageRecord]
    let allApps: [AppUsageRecord]
    let hourlyData: [HourlyRecord]
    let distractingMinutes: Int
    let productiveMinutes: Int
    let neutralMinutes: Int
    let capturedAt: Date
}
```

Written to app group UserDefaults under key `"latestScreenTimeSnapshot"`.

## Capture Pipeline

### Stage 1: Report Extension Capture (Primary)

`DistractionReportScene` already processes full `DeviceActivityResults`. On every render:

1. Serialize processed data into `ScreenTimeSnapshotPayload`
2. Write JSON to app group UserDefaults key `"latestScreenTimeSnapshot"`
3. Include timestamp for freshness checking

This is the primary capture mechanism — the report extension is the only component with access to per-app usage data via `DeviceActivityResults`.

### Stage 2: Monitor Extension End-of-Day Signal

`DeviceActivityMonitorExtension.intervalDidEnd()` (already fires daily):

1. Write trigger flag `"pendingSnapshotDate"` = yesterday's date string to app group
2. This signals the main app to ingest any staged data on next foreground

### Stage 3: Main App Foreground Ingestion

On app foreground (`scenePhase` change to `.active`):

1. Read `"latestScreenTimeSnapshot"` from app group UserDefaults
2. Parse `ScreenTimeSnapshotPayload`
3. Upsert `ScreenTimeSnapshot` in SwiftData:
   - If snapshot date = today: upsert with `isComplete: false`
   - If snapshot date = yesterday (or pending flag set): upsert with `isComplete: true`
4. Clear processed entries from app group staging area

### Limitation

If the user never opens the app for a full day, no snapshot is captured for that day. The report extension only runs when the `DeviceActivityReport` SwiftUI view is rendered. This is an Apple platform constraint.

## View Architecture

### Navigation

`ScreenTimeTabPicker` already has the `ScreenTimePeriod` enum (Today / Yesterday / This Week) and dropdown UI. Changes:

1. `period` changes from local `@State` to `@Binding` passed from `ScreenTimePageView`
2. `ScreenTimePageView` passes `period` down to `ScreenTimeStatsTab`
3. `ScreenTimeStatsTab` switches content based on period

### Stats Tab by Period

**Today:** Current behavior unchanged — live `DeviceActivityReport` views.

**Yesterday:** Native SwiftUI view reading from `ScreenTimeSnapshot` for yesterday's date. Same visual layout as the live report:
- Total screen time header
- Stats row: top 3 apps, focus level %, pickups count
- Hourly stacked bar graph (focused green vs distracted red)
- Time offline card
- App usage list with category badges (read-only, non-interactive)

**This Week:** Native SwiftUI view with aggregated data from up to 7 `ScreenTimeSnapshot` records (rolling 7-day window):
- Total screen time header (sum of daily totals)
- Stats row: top 3 apps by aggregate time, average focus level, total pickups
- Daily stacked bar graph — 7 bars (one per day), focused vs distracted
- Average time offline
- App usage list ranked by aggregate duration

### Aggregation Logic

`ScreenTimeAggregator` utility:
- Total screentime = sum of daily `totalScreenTimeSeconds`
- Average focus = mean of daily `focusLevelPercent`
- Top apps = merge `allAppsData` across days, sum durations per app, sort descending
- Daily graph bars = one bar per `ScreenTimeSnapshot` (date, total focused, total distracted)
- Time offline = mean of daily `timeOfflinePercent`

### Empty States

- Yesterday with no snapshot: "No data for yesterday. Open the app daily to capture screen time."
- Week with <2 snapshots: Show available data + same hint message

## Files to Create/Modify

### New Files
- `TamaGoosie/Core/Models/ScreenTimeSnapshot.swift` — SwiftData model + Codable structs
- `TamaGoosie/Core/Services/ScreenTimeSnapshotService.swift` — Ingestion from app group, upsert logic
- `TamaGoosie/Core/Services/ScreenTimeAggregator.swift` — Weekly aggregation
- `TamaGoosie/Features/ScreenTime/ScreenTimeSavedStatsView.swift` — Yesterday/week native view
- `TamaGoosie/Features/ScreenTime/ScreenTimeDailyBarGraph.swift` — Weekly daily bar graph component

### Modified Files
- `Extensions/Report/DistractionReportScene.swift` — Add payload serialization to app group on render
- `TamaGoosieDeviceActivity/DeviceActivityMonitorExtension.swift` — Add pending snapshot flag on interval end
- `TamaGoosie/Features/ScreenTime/ScreenTimeTabPicker.swift` — Change `period` to `@Binding`
- `TamaGoosie/Features/ScreenTime/ScreenTimePageView.swift` — Own `period` state, pass as binding
- `TamaGoosie/Features/ScreenTime/ScreenTimeStatsTab.swift` — Accept `period`, switch between live/saved views
- `project.yml` — Add new Swift files to sources (if needed)

## Constraints

- All data stored as standard types (Int, Date, Data) in SwiftData — no iOS-only framework imports in model
- App group ID: `group.com.tamagoosie`, staging key: `"latestScreenTimeSnapshot"`
- Report extension writes to both `UserDefaults.standard` and app group (following existing `CategoryMapStore` pattern)
- `ScreenTimeSnapshot` model must be added to the SwiftData `ModelContainer` configuration
