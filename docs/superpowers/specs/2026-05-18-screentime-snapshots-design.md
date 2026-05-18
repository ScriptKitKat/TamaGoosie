# Screen Time Historical Views — Yesterday & Weekly Aggregates

**Date:** 2026-05-18
**Status:** Approved (v2 — simplified, no persistence)

## Overview

Add yesterday and rolling 7-day weekly screen time views by querying Apple's DeviceActivity API directly with historical date ranges. No new data models or capture pipelines needed — the `DeviceActivityReport` view already accepts a `DeviceActivityFilter` with arbitrary `DateInterval`, and Apple retains usage data for at least 1-2 weeks.

The existing dropdown picker in `ScreenTimeTabPicker` (Today / Yesterday / This Week) drives navigation.

## Architecture

### Core Insight

`DeviceActivityFilter` accepts any `DateInterval`. The current code queries today:

```swift
DeviceActivityFilter(
    segment: .hourly(during: DateInterval(start: startOfDay, end: Date())),
    users: .all,
    devices: .all
)
```

For yesterday and weekly, we just change the date interval:

```swift
// Yesterday
DeviceActivityFilter(
    segment: .hourly(during: DateInterval(start: yesterdayStart, end: todayStart)),
    users: .all,
    devices: .all
)

// This Week (rolling 7 days)
DeviceActivityFilter(
    segment: .daily(during: DateInterval(start: sevenDaysAgo, end: now)),
    users: .all,
    devices: .all
)
```

The report extension processes whatever data matches the filter via `makeConfiguration(representing:)`. No persistence layer needed.

### Filter Construction

`ScreenTimeStatsTab` computes the filter based on `ScreenTimePeriod`:

| Period | Segment | DateInterval |
|--------|---------|-------------|
| Today | `.hourly` | start of today ... now |
| Yesterday | `.hourly` | start of yesterday ... start of today |
| This Week | `.daily` | 7 days ago start of day ... now |

### Report Extension Scenes

**Existing scenes (work for Today + Yesterday):**

- `DistractionReportScene` (context: `"distraction_summary"`) — Processes hourly segments, renders: total screen time header, stats row (top 3 apps, focus level, pickups), hourly stacked bar graph, time offline card
- `AllAppsReportScene` (context: `"all_apps_usage"`) — Lists top 20 apps with duration bars and category badges

These work unchanged for Yesterday because the data shape is identical (hourly segments for a single day).

**New scene for weekly view:**

- `WeeklySummaryReportScene` (context: `"weekly_summary"`) — Processes daily segments over 7 days, renders:
  - Total screen time header (sum across 7 days)
  - Stats row: top 3 apps by aggregate time, average focus level, total pickups
  - Daily stacked bar graph — 7 bars (one per day), each showing focused (green) vs distracted (red) time
  - Average time offline card

- `WeeklyAppsReportScene` (context: `"weekly_apps_usage"`) — Aggregates app usage across 7 daily segments, ranks by total duration, shows top 20 with category badges

### Weekly Report Scene Data Processing

`WeeklySummaryReportScene.makeConfiguration(representing:)`:

```
for each day in DeviceActivityResults:
    for each segment in day.activitySegments:
        accumulate total screen time
        accumulate pickups
        for each category > app:
            accumulate per-app durations
            track distracting vs focused time
    produce one DailyBar(date, focusedSeconds, distractedSeconds)

Output:
    totalScreenTime across all days
    totalPickups across all days
    topApps by aggregate duration (top 3)
    focusLevel = avg(daily focused% )
    dailyBars = [DailyBar] for graph (7 entries)
    timeOffline = avg(daily offline%)
```

### Header Label

The total screen time header label changes based on period:
- Today: "SCREEN TIME TODAY"
- Yesterday: "SCREEN TIME YESTERDAY"
- This Week: "SCREEN TIME THIS WEEK"

The header context is passed implicitly — the report extension can infer it from the date interval in the filter (single day = today/yesterday, multi-day = week). Or we use distinct report contexts which already separate the scenes.

## View Architecture

### Navigation Wiring

`ScreenTimeTabPicker` already has `ScreenTimePeriod` enum and dropdown UI. Changes:

1. `period` changes from local `@State` to `@Binding` passed from `ScreenTimePageView`
2. `ScreenTimePageView` owns the `period` state, passes it down
3. `ScreenTimeStatsTab` accepts `period` and switches filters/scenes accordingly

### Stats Tab Behavior

```swift
// ScreenTimeStatsTab
switch period {
case .today, .yesterday:
    // Same two DeviceActivityReport views, different filter date range
    DeviceActivityReport(.init(rawValue: "distraction_summary"), filter: periodFilter)
    DeviceActivityReport(.init(rawValue: "all_apps_usage"), filter: periodFilter)

case .week:
    // Weekly-specific report scenes with .daily segments
    DeviceActivityReport(.init(rawValue: "weekly_summary"), filter: weeklyFilter)
    DeviceActivityReport(.init(rawValue: "weekly_apps_usage"), filter: weeklyFilter)
}
```

**Today:** Current behavior unchanged.

**Yesterday:** Same `DeviceActivityReport` scenes with yesterday's date interval. The hourly graph, top apps, focus level, pickups, time offline all render identically — just for yesterday's data. Header says "SCREEN TIME YESTERDAY".

**This Week:** Uses the two new weekly report scenes. Daily bar graph instead of hourly. Aggregated stats. Header says "SCREEN TIME THIS WEEK".

### Empty States

If Apple returns no data for the requested interval (e.g., the device was off), the existing empty-state handling in the report scenes applies — the graph shows empty bars and stats show zeros.

## Files to Create/Modify

### New Files
- `Extensions/Report/WeeklySummaryReportScene.swift` — Weekly summary report scene (daily bar graph, aggregate stats)
- `Extensions/Report/WeeklyAppsReportScene.swift` — Weekly app usage report scene (aggregate app list)

### Modified Files
- `Extensions/Report/DistractionReportScene.swift` — Update header label to be dynamic (today vs yesterday); register new scenes in `DistractionReportExtension.body`
- `TamaGoosie/Features/ScreenTime/ScreenTimeTabPicker.swift` — Change `period` from `@State` to `@Binding`
- `TamaGoosie/Features/ScreenTime/ScreenTimePageView.swift` — Own `period` state, pass as binding to picker and stats tab
- `TamaGoosie/Features/ScreenTime/ScreenTimeStatsTab.swift` — Accept `period` parameter, compute filter from period, switch between daily/weekly report scenes

### No New Models or Services Needed

The entire feature is driven by:
1. Changing the `DeviceActivityFilter` date interval
2. Adding two new report scenes for weekly aggregation
3. Wiring the existing dropdown picker

## Constraints

- Apple retains DeviceActivity data for approximately 1-2 weeks — sufficient for our rolling 7-day window
- If Apple limits historical access in a future OS update, we can add the snapshot persistence layer as a fallback (design from v1 of this spec)
- Report extension scenes must be registered in `DistractionReportExtension.body`
- Weekly scenes use `.daily` segments; today/yesterday scenes use `.hourly` segments
- Category map (productive/neutral/distracting) is shared across all scenes via existing `CategoryMapStore`
