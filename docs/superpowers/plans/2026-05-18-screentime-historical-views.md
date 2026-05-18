# Screen Time Historical Views Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add yesterday and rolling 7-day weekly screen time views by querying Apple's DeviceActivity API with historical date ranges.

**Architecture:** The existing `DeviceActivityReport` accepts a `DeviceActivityFilter` with any `DateInterval`. We change the filter based on the dropdown period (Today/Yesterday/This Week). Today and Yesterday share the same report scenes (hourly segments). This Week uses two new report scenes that process daily segments and render a 7-day bar graph.

**Tech Stack:** SwiftUI, DeviceActivity framework, FamilyControls, ExtensionKit (DeviceActivityReportExtension)

**Spec:** `docs/superpowers/specs/2026-05-18-screentime-snapshots-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `TamaGoosie/Features/ScreenTime/ScreenTimeTabPicker.swift` | Modify | Change `period` from `@State` to `@Binding` |
| `TamaGoosie/Features/ScreenTime/ScreenTimePageView.swift` | Modify | Own `period` state, pass binding to picker and stats tab |
| `TamaGoosie/Features/ScreenTime/ScreenTimeStatsTab.swift` | Modify | Accept `period`, compute filter per period, switch report scenes |
| `Extensions/Report/DistractionReportScene.swift` | Modify | Make header label dynamic (today vs yesterday), extract shared helpers |
| `Extensions/Report/WeeklyReportScenes.swift` | Create | `WeeklySummaryReportScene` + `WeeklyAppsReportScene` for 7-day aggregate views |

No new models, services, or `project.yml` changes needed. The report extension's `sources: - Extensions/Report` auto-includes new `.swift` files.

---

### Task 1: Wire up the period dropdown binding

**Files:**
- Modify: `TamaGoosie/Features/ScreenTime/ScreenTimeTabPicker.swift:16`
- Modify: `TamaGoosie/Features/ScreenTime/ScreenTimePageView.swift:17,46,55`

- [ ] **Step 1: Change `period` from `@State` to `@Binding` in `ScreenTimeTabPicker`**

In `ScreenTimeTabPicker.swift`, change line 16 from:

```swift
@State private var period: ScreenTimePeriod = .today
```

to:

```swift
@Binding var period: ScreenTimePeriod
```

- [ ] **Step 2: Add `period` state to `ScreenTimePageView` and pass bindings**

In `ScreenTimePageView.swift`, add a new `@State` property after line 17:

```swift
@State private var selectedPeriod: ScreenTimePeriod = .today
```

Change line 46 from:

```swift
ScreenTimeTabPicker(selected: $selectedTab)
```

to:

```swift
ScreenTimeTabPicker(selected: $selectedTab, period: $selectedPeriod)
```

Change line 55 from:

```swift
ScreenTimeStatsTab()
```

to:

```swift
ScreenTimeStatsTab(period: selectedPeriod)
```

- [ ] **Step 3: Add `period` parameter to `ScreenTimeStatsTab`**

In `ScreenTimeStatsTab.swift`, add a stored property after line 8:

```swift
var period: ScreenTimePeriod = .today
```

- [ ] **Step 4: Build to verify compilation**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add TamaGoosie/Features/ScreenTime/ScreenTimeTabPicker.swift \
       TamaGoosie/Features/ScreenTime/ScreenTimePageView.swift \
       TamaGoosie/Features/ScreenTime/ScreenTimeStatsTab.swift
git commit -m "feat: wire up period dropdown binding across screen time views"
```

---

### Task 2: Compute DeviceActivityFilter per period in ScreenTimeStatsTab

**Files:**
- Modify: `TamaGoosie/Features/ScreenTime/ScreenTimeStatsTab.swift`

- [ ] **Step 1: Replace the single `allActivityFilter` with a period-aware computed property**

Replace the entire `allActivityFilter` computed property (lines 10-18) and body (lines 20-33) with:

```swift
struct ScreenTimeStatsTab: View {
    var period: ScreenTimePeriod = .today
    @State private var manager = ScreenTimeManager.shared

    private var summaryFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        switch period {
        case .today:
            return DeviceActivityFilter(
                segment: .hourly(during: DateInterval(start: startOfToday, end: now)),
                users: .all,
                devices: .all
            )
        case .yesterday:
            let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
            return DeviceActivityFilter(
                segment: .hourly(during: DateInterval(start: startOfYesterday, end: startOfToday)),
                users: .all,
                devices: .all
            )
        case .week:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday)!
            return DeviceActivityFilter(
                segment: .daily(during: DateInterval(start: sevenDaysAgo, end: now)),
                users: .all,
                devices: .all
            )
        }
    }

    private var summaryContext: DeviceActivityReport.Context {
        period == .week ? .init(rawValue: "weekly_summary") : .init(rawValue: "distraction_summary")
    }

    private var appsContext: DeviceActivityReport.Context {
        period == .week ? .init(rawValue: "weekly_apps_usage") : .init(rawValue: "all_apps_usage")
    }

    var body: some View {
        VStack(spacing: 14) {
            DeviceActivityReport(summaryContext, filter: summaryFilter)
                .frame(height: 470)

            DeviceActivityReport(appsContext, filter: summaryFilter)
                .frame(height: 420)
        }
        .id(period)
        .task {
            manager.refreshAuthorizationStatus()
        }
    }
}
```

Key details:
- Today and Yesterday both use `.hourly` segments with different date ranges, sharing the existing `distraction_summary` and `all_apps_usage` report scenes.
- This Week uses `.daily` segments with the new `weekly_summary` and `weekly_apps_usage` contexts (created in Task 4).
- `.id(period)` forces the `DeviceActivityReport` views to re-create when the period changes, ensuring the filter is re-evaluated.

- [ ] **Step 2: Build to verify compilation**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED (the weekly contexts don't exist yet in the extension, but the main app compiles — the contexts are just string identifiers)

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/ScreenTime/ScreenTimeStatsTab.swift
git commit -m "feat: compute DeviceActivityFilter per period selection"
```

---

### Task 3: Make DistractionReportScene header dynamic for yesterday

**Files:**
- Modify: `Extensions/Report/DistractionReportScene.swift:15-21,127-129`

- [ ] **Step 1: Add `isYesterday` flag to ReportData**

In `DistractionReportScene.swift`, add a field to `ReportData` (after line 20):

Change the struct from:

```swift
struct ReportData {
    var totalScreenTime: TimeInterval = 0
    var totalPickups: Int = 0
    var distractingMinutes: Int = 0
    var topAppTokens: [ApplicationToken] = []
    var hourlyBuckets: [HourlyBucket] = []
}
```

to:

```swift
struct ReportData {
    var totalScreenTime: TimeInterval = 0
    var totalPickups: Int = 0
    var distractingMinutes: Int = 0
    var topAppTokens: [ApplicationToken] = []
    var hourlyBuckets: [HourlyBucket] = []
    var isToday: Bool = true
}
```

- [ ] **Step 2: Detect whether data is for today or yesterday in `makeConfiguration`**

At the end of `makeConfiguration`, before the `return` statement (around line 94), add logic to detect the date. Replace the return statement:

```swift
// Detect if this is today's data or yesterday's by checking the filter date range.
// If most activity segments start before today's start-of-day, it's yesterday.
let startOfToday = Calendar.current.startOfDay(for: Date())
var latestSegmentStart: Date = .distantPast
for await activityData in data {
    for await segment in activityData.activitySegments {
        if segment.dateInterval.start > latestSegmentStart {
            latestSegmentStart = segment.dateInterval.start
        }
    }
}
let isToday = latestSegmentStart >= startOfToday || latestSegmentStart == .distantPast
```

Wait — we can't iterate `data` twice since it's an `AsyncSequence`. Instead, capture the date during the existing loop. Add a variable at the top of `makeConfiguration` (after line 28):

```swift
var latestSegmentStart: Date = .distantPast
```

Inside the existing `for await segment in activityData.activitySegments` loop (after line 36), add:

```swift
if segment.dateInterval.start > latestSegmentStart {
    latestSegmentStart = segment.dateInterval.start
}
```

Then update the return statement (line 94) to include:

```swift
let startOfToday = Calendar.current.startOfDay(for: Date())
let isToday = latestSegmentStart >= startOfToday || latestSegmentStart == .distantPast

return ReportData(
    totalScreenTime: totalScreenTime,
    totalPickups: totalPickups,
    distractingMinutes: Int(distractingSec / 60),
    topAppTokens: topTokens,
    hourlyBuckets: buckets,
    isToday: isToday
)
```

- [ ] **Step 3: Update the header label in the `content` closure**

Change line 127 from:

```swift
Text("SCREEN TIME TODAY")
```

to:

```swift
Text(config.isToday ? "SCREEN TIME TODAY" : "SCREEN TIME YESTERDAY")
```

- [ ] **Step 4: Also update the time offline label**

Change line 261 from:

```swift
Text("\(offlinePct)% of your day")
```

to:

```swift
Text(config.isToday ? "\(offlinePct)% of your day" : "\(offlinePct)% of yesterday")
```

- [ ] **Step 5: Build the report extension to verify compilation**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add Extensions/Report/DistractionReportScene.swift
git commit -m "feat: dynamic header label for today vs yesterday in report scene"
```

---

### Task 4: Create WeeklySummaryReportScene

**Files:**
- Create: `Extensions/Report/WeeklyReportScenes.swift`

- [ ] **Step 1: Create the weekly summary report scene**

Create `Extensions/Report/WeeklyReportScenes.swift` with the following content. This scene processes `.daily` segments over 7 days and renders a daily stacked bar graph.

```swift
import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

// MARK: - Weekly Summary Report Scene

struct WeeklySummaryReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "weekly_summary")

    struct DailyBucket {
        let date: Date
        var totalSeconds: TimeInterval = 0
        var distractingSeconds: TimeInterval = 0
    }

    struct ReportData {
        var totalScreenTime: TimeInterval = 0
        var totalPickups: Int = 0
        var distractingMinutes: Int = 0
        var topAppTokens: [ApplicationToken] = []
        var dailyBuckets: [DailyBucket] = []
        var dayCount: Int = 0
    }

    typealias Configuration = ReportData

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ReportData {
        let appCategoryMap = DistractionReportScene.loadCategoryMap()
        let calendar = Calendar.current

        var totalScreenTime: TimeInterval = 0
        var totalPickups = 0
        var appDurations: [String: (token: ApplicationToken, duration: TimeInterval)] = [:]
        var dailyTotals: [DateComponents: (total: TimeInterval, distracting: TimeInterval)] = [:]
        var datesSet: Set<DateComponents> = []

        for await activityData in data {
            for await segment in activityData.activitySegments {
                let dayComponents = calendar.dateComponents([.year, .month, .day], from: segment.dateInterval.start)
                datesSet.insert(dayComponents)

                let segmentDuration = segment.totalActivityDuration
                var segmentAppDuration: TimeInterval = 0
                var segmentDistractingSec: TimeInterval = 0
                totalPickups += segment.totalPickupsWithoutApplicationActivity

                for await category in segment.categories {
                    for await app in category.applications {
                        let duration = app.totalActivityDuration
                        guard duration > 0 else { continue }
                        segmentAppDuration += duration
                        totalPickups += app.numberOfPickups

                        if let token = app.application.token {
                            let key = (try? JSONEncoder().encode(token))?.base64EncodedString() ?? "\(token.hashValue)"

                            if let existing = appDurations[key] {
                                appDurations[key] = (token: existing.token, duration: existing.duration + duration)
                            } else {
                                appDurations[key] = (token: token, duration: duration)
                            }

                            let cat = appCategoryMap[key] ?? "distracting"
                            if cat == "distracting" {
                                segmentDistractingSec += duration
                            }
                        }
                    }
                }

                let effective = max(segmentDuration, segmentAppDuration)
                totalScreenTime += effective

                let existing = dailyTotals[dayComponents] ?? (total: 0, distracting: 0)
                dailyTotals[dayComponents] = (
                    total: existing.total + effective,
                    distracting: existing.distracting + segmentDistractingSec
                )
            }
        }

        // Build sorted daily buckets for the last 7 days
        let startOfToday = calendar.startOfDay(for: Date())
        var buckets: [DailyBucket] = []
        for dayOffset in (-6...0) {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday)!
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            let entry = dailyTotals[components]
            buckets.append(DailyBucket(
                date: date,
                totalSeconds: entry?.total ?? 0,
                distractingSeconds: entry?.distracting ?? 0
            ))
        }

        // Top 3 apps by aggregate duration
        let sorted = appDurations.sorted { $0.value.duration > $1.value.duration }
        let topTokens = sorted.prefix(3).map { $0.value.token }

        var distractingSec: TimeInterval = 0
        for (key, value) in appDurations {
            if (appCategoryMap[key] ?? "distracting") == "distracting" {
                distractingSec += value.duration
            }
        }

        return ReportData(
            totalScreenTime: totalScreenTime,
            totalPickups: totalPickups,
            distractingMinutes: Int(distractingSec / 60),
            topAppTokens: topTokens,
            dailyBuckets: buckets,
            dayCount: max(1, datesSet.count)
        )
    }

    var content: (ReportData) -> AnyView = { config in
        let awakeMinutesTotal = 960 * max(1, config.dayCount)
        let totalMinutes = Int(config.totalScreenTime / 60)
        let avgFocusScore = max(0, min(100, 100 - Int(round(Double(config.distractingMinutes) / Double(awakeMinutesTotal) * 100))))
        let avgOfflineMinutes = max(0, (awakeMinutesTotal - totalMinutes) / max(1, config.dayCount))
        let totalOfflineMinutes = max(0, awakeMinutesTotal - totalMinutes)
        let avgOfflinePct = Int(round(Double(totalOfflineMinutes) / Double(awakeMinutesTotal) * 100))

        let accentGreen = Color(red: 0.29, green: 0.56, blue: 0.29)
        let focusGreen = Color(red: 0.40, green: 0.73, blue: 0.42)
        let distractedRed = Color(red: 0.90, green: 0.45, blue: 0.45)
        let lightGreen = Color(red: 0.91, green: 0.96, blue: 0.91)
        let charcoal = Color(red: 0.18, green: 0.18, blue: 0.18)

        let dayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f
        }()

        return AnyView(
            VStack(spacing: 14) {
                // Screen time header
                VStack(spacing: 6) {
                    Text(weeklyFormatTime(totalMinutes))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text("SCREEN TIME THIS WEEK")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.vertical, 8)

                // Stats row
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("MOST USED")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        if config.topAppTokens.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Circle().fill(.white.opacity(0.2)).frame(width: 26, height: 26)
                                }
                            }
                        } else {
                            HStack(spacing: 4) {
                                ForEach(Array(config.topAppTokens.enumerated()), id: \.offset) { _, token in
                                    Label(token)
                                        .labelStyle(.iconOnly)
                                        .scaleEffect(1.1)
                                        .frame(width: 26, height: 26)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("AVG FOCUS")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("\(avgFocusScore)%")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("PICKUPS")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("\(config.totalPickups)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 4)

                // Daily bar graph card
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(focusGreen).frame(width: 8, height: 8)
                            Text("Focused")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(charcoal.opacity(0.5))
                        }
                        HStack(spacing: 4) {
                            Circle().fill(distractedRed).frame(width: 8, height: 8)
                            Text("Distracted")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(charcoal.opacity(0.5))
                        }
                    }

                    // Find max daily total for scaling
                    let maxDailySeconds = config.dailyBuckets.map(\.totalSeconds).max() ?? 1

                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(config.dailyBuckets.enumerated()), id: \.offset) { _, bucket in
                            let distractSec = bucket.distractingSeconds
                            let focusedSec = max(0, bucket.totalSeconds - distractSec)
                            let maxH: CGFloat = 80
                            let scale = maxDailySeconds > 0 ? maxH / CGFloat(maxDailySeconds) : 0
                            let focusedH = CGFloat(focusedSec) * scale
                            let distractH = CGFloat(distractSec) * scale

                            VStack(spacing: 2) {
                                if focusedH > 1 || distractH > 1 {
                                    if focusedH > 1 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(focusGreen)
                                            .frame(height: max(4, focusedH))
                                    }
                                    if distractH > 1 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(distractedRed)
                                            .frame(height: max(4, distractH))
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(charcoal.opacity(0.08))
                                        .frame(height: 4)
                                }

                                Text(dayFormatter.string(from: bucket.date))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(charcoal.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 100)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                )

                // Avg time offline card
                HStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(accentGreen)
                        .frame(width: 36, height: 36)
                        .background(lightGreen, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avg Time Offline")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(charcoal)
                        Text("\(avgOfflinePct)% of your day")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(accentGreen)
                    }

                    Spacer()

                    Text(weeklyFormatTime(avgOfflineMinutes))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(accentGreen)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                )
            }
            .frame(maxWidth: .infinity)
        )
    }
}

private func weeklyFormatTime(_ minutes: Int) -> String {
    if minutes >= 60 {
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
    return "\(minutes)m"
}

private func weeklyFormatDuration(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    if hours > 0 {
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }
    return "\(minutes)m"
}
```

- [ ] **Step 2: Build the report extension to verify compilation**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Extensions/Report/WeeklyReportScenes.swift
git commit -m "feat: add WeeklySummaryReportScene for 7-day daily bar graph"
```

---

### Task 5: Create WeeklyAppsReportScene

**Files:**
- Modify: `Extensions/Report/WeeklyReportScenes.swift` (append)

- [ ] **Step 1: Add WeeklyAppsReportScene to the same file**

Append the following to `Extensions/Report/WeeklyReportScenes.swift`, before the closing of the file (after the `weeklyFormatDuration` function):

```swift
// MARK: - Weekly Apps Usage Report Scene

struct WeeklyAppsReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "weekly_apps_usage")

    struct AppEntry: Identifiable {
        let id: String
        let token: ApplicationToken
        let durationSeconds: TimeInterval
    }

    struct ReportData {
        var totalScreenTime: TimeInterval = 0
        var entries: [AppEntry] = []
        var categoryMap: [String: String] = [:]
    }

    typealias Configuration = ReportData

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ReportData {
        let appCategoryMap = DistractionReportScene.loadCategoryMap()

        var totalScreenTime: TimeInterval = 0
        var appData: [String: (token: ApplicationToken, duration: TimeInterval)] = [:]

        for await activityData in data {
            for await segment in activityData.activitySegments {
                let segmentDuration = segment.totalActivityDuration
                var segmentAppDuration: TimeInterval = 0

                for await category in segment.categories {
                    for await app in category.applications {
                        let duration = app.totalActivityDuration
                        guard duration > 0 else { continue }
                        segmentAppDuration += duration

                        if let token = app.application.token,
                           let tokenData = try? JSONEncoder().encode(token) {
                            let tokenKey = tokenData.base64EncodedString()
                            if let existing = appData[tokenKey] {
                                appData[tokenKey] = (token: existing.token, duration: existing.duration + duration)
                            } else {
                                appData[tokenKey] = (token: token, duration: duration)
                            }
                        }
                    }
                }

                totalScreenTime += max(segmentDuration, segmentAppDuration)
            }
        }

        let sortedEntries = appData.sorted { $0.value.duration > $1.value.duration }
            .prefix(20)
            .map { AppEntry(id: $0.key, token: $0.value.token, durationSeconds: $0.value.duration) }

        return ReportData(
            totalScreenTime: totalScreenTime,
            entries: sortedEntries,
            categoryMap: appCategoryMap
        )
    }

    var content: (ReportData) -> AnyView = { config in
        AnyView(WeeklyAppUsageContentView(config: config))
    }
}

// MARK: - Weekly App Usage Content View

private struct WeeklyAppUsageContentView: View {
    let config: WeeklyAppsReportScene.ReportData
    @State private var categoryMap: [String: String]

    private let accentGreen = Color(red: 0.29, green: 0.56, blue: 0.29)
    private let charcoal = Color(red: 0.18, green: 0.18, blue: 0.18)
    private let distractedRed = Color(red: 0.90, green: 0.45, blue: 0.45)
    private let neutralGray = Color(red: 0.62, green: 0.62, blue: 0.62)

    init(config: WeeklyAppsReportScene.ReportData) {
        self.config = config
        self._categoryMap = State(initialValue: config.categoryMap)
    }

    private var maxDuration: TimeInterval {
        config.entries.first?.durationSeconds ?? 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentGreen)
                        .frame(width: 4, height: 18)
                    Text("App Usage This Week")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(charcoal)

                    Spacer()

                    Text(weeklyFormatDuration(config.totalScreenTime))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accentGreen)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                if config.entries.isEmpty {
                    Text("Usage data will appear after some screen time")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(charcoal.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(config.entries.enumerated()), id: \.element.id) { index, entry in
                            weeklyAppRow(entry: entry)

                            if index < config.entries.count - 1 {
                                Divider()
                                    .padding(.leading, 62)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
            )
        }
    }

    @ViewBuilder
    private func weeklyAppRow(entry: WeeklyAppsReportScene.AppEntry) -> some View {
        let catRaw = categoryMap[entry.id] ?? "distracting"
        let catColor = colorForCategory(catRaw)
        let catLabel = labelForCategory(catRaw)
        let progress = maxDuration > 0 ? min(1.0, entry.durationSeconds / maxDuration) : 0

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Label(entry.token)
                    .labelStyle(.iconOnly)
                    .scaleEffect(1.6)
                    .frame(width: 40, height: 40)

                Label(entry.token)
                    .labelStyle(.titleOnly)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(charcoal)

                Spacer()

                Text(weeklyFormatDuration(entry.durationSeconds))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(catColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(charcoal.opacity(0.08))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(catColor)
                        .frame(width: max(4, geo.size.width * progress), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.leading, 52)

            Button {
                cycleCategory(for: entry.id)
            } label: {
                Text(catLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(catColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(catColor.opacity(0.12), in: Capsule())
            }
            .padding(.leading, 52)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func cycleCategory(for appId: String) {
        let current = categoryMap[appId] ?? "distracting"
        let next: String
        switch current {
        case "distracting": next = "neutral"
        case "neutral": next = "productive"
        default: next = "distracting"
        }
        categoryMap[appId] = next
        // Use the shared CategoryMapStore from DistractionReportScene.swift
        // We need to access it — but it's private. We'll fix this in the next step.
    }

    private func colorForCategory(_ cat: String) -> Color {
        switch cat {
        case "productive": return accentGreen
        case "neutral": return neutralGray
        default: return distractedRed
        }
    }

    private func labelForCategory(_ cat: String) -> String {
        switch cat {
        case "productive": return "Productive"
        case "neutral": return "Neutral"
        default: return "Distracting"
        }
    }
}
```

- [ ] **Step 2: Make CategoryMapStore accessible from WeeklyReportScenes.swift**

In `Extensions/Report/DistractionReportScene.swift`, change line 288 from:

```swift
private enum CategoryMapStore {
```

to:

```swift
enum CategoryMapStore {
```

Then in `WeeklyAppUsageContentView.cycleCategory`, replace the comment line with:

```swift
CategoryMapStore.save(categoryMap)
```

- [ ] **Step 3: Build to verify compilation**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Extensions/Report/WeeklyReportScenes.swift Extensions/Report/DistractionReportScene.swift
git commit -m "feat: add WeeklyAppsReportScene with aggregate app usage list"
```

---

### Task 6: Register new scenes in the report extension entry point

**Files:**
- Modify: `Extensions/Report/DistractionReportScene.swift:551-557`

- [ ] **Step 1: Add the two new scenes to the extension's body**

Change the `DistractionReportExtension` (lines 551-557) from:

```swift
@main
struct DistractionReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        DistractionReportScene()
        AllAppsReportScene()
    }
}
```

to:

```swift
@main
struct DistractionReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        DistractionReportScene()
        AllAppsReportScene()
        WeeklySummaryReportScene()
        WeeklyAppsReportScene()
    }
}
```

- [ ] **Step 2: Build the full project**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Extensions/Report/DistractionReportScene.swift
git commit -m "feat: register weekly report scenes in extension entry point"
```

---

### Task 7: Final integration build and manual test

**Files:** None (verification only)

- [ ] **Step 1: Clean build**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  clean build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Manual test checklist**

On a device or simulator with Screen Time data:

1. Open app, go to Screen Time tab
2. Verify "Today" dropdown shows live data as before
3. Switch to "Yesterday" — verify header says "SCREEN TIME YESTERDAY", hourly graph shows yesterday's data, pickups and focus level reflect yesterday
4. Switch to "This Week" — verify header says "SCREEN TIME THIS WEEK", daily bar graph shows 7 bars (Mon-Sun), stats show aggregate totals, app list shows aggregate usage
5. Switch back to "Today" — verify live data returns
6. Verify category tapping works in all three views (today, yesterday, week)

- [ ] **Step 3: Final commit if any fixes needed**

If manual testing reveals issues, fix and commit. Otherwise, all done.
