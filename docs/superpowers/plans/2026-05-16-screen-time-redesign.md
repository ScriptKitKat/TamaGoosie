# Screen Time Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the Screen Time page into Stats + Blocks tabs, with four block types (Block Now, Schedule Session, App Limit, Lock) replacing the single-plan system and the focus timer.

**Architecture:** New `ScreenBlock` SwiftData model stores all block configurations. `ScreenTimePageView` gets a tab picker routing to `ScreenTimeStatsTab` (read-only data) and `ScreenTimeBlocksTab` (block management). `ScreenTimeManager` gains per-block `DeviceActivityCenter` monitoring. `FocusSessionView` is replaced by `BlockNowSheet`.

**Tech Stack:** SwiftUI, SwiftData, FamilyControls, DeviceActivity

**Spec:** `docs/superpowers/specs/2026-05-16-screen-time-redesign.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `TamaGoosie/Core/Models/ScreenBlock.swift` | Create | SwiftData model for all block types |
| `TamaGoosie/Features/ScreenTime/ScreenTimeTabPicker.swift` | Create | Stats/Blocks segmented control |
| `TamaGoosie/Features/ScreenTime/DayOfWeekPicker.swift` | Create | Shared day-circle component |
| `TamaGoosie/Features/ScreenTime/ScreenTimeStatsTab.swift` | Create | Read-only stats view |
| `TamaGoosie/Features/ScreenTime/ScreenTimeBlocksTab.swift` | Create | Block list + past + new block buttons |
| `TamaGoosie/Features/ScreenTime/BlockCardView.swift` | Create | Card for active/past blocks |
| `TamaGoosie/Features/ScreenTime/BlockNowSheet.swift` | Create | Block Now creation + countdown UI |
| `TamaGoosie/Features/ScreenTime/ScheduleSessionSheet.swift` | Create | Recurring schedule creation |
| `TamaGoosie/Features/ScreenTime/AppLimitSheet.swift` | Create | Time limit creation |
| `TamaGoosie/Features/ScreenTime/LockSheet.swift` | Create | Open limit creation |
| `TamaGoosie/Features/ScreenTime/ScreenTimePageView.swift` | Modify | Add tab picker, route to tabs |
| `TamaGoosie/Core/Services/ScreenTimeManager.swift` | Modify | Per-block monitoring methods |
| `TamaGoosie/App/TamaGoosieApp.swift` | Modify | Register `ScreenBlock` in schema |
| `Shared/Constants.swift` | Modify | Add new constants if needed |

---

### Task 1: Create ScreenBlock Model

**Files:**
- Create: `TamaGoosie/Core/Models/ScreenBlock.swift`
- Modify: `TamaGoosie/App/TamaGoosieApp.swift:80-89`

- [ ] **Step 1: Create the ScreenBlock model file**

Create `TamaGoosie/Core/Models/ScreenBlock.swift`:

```swift
import Foundation
import SwiftData
import FamilyControls

@Model
final class ScreenBlock {
    var id: UUID = UUID()
    var name: String = ""
    var type: String = "blockNow"       // "blockNow" | "schedule" | "appLimit" | "lock"
    var isActive: Bool = true
    var createdAt: Date = Date()

    // App selection (encoded FamilyActivitySelection)
    var selectionData: Data?

    // Block Now
    var durationMinutes: Int = 25
    var startedAt: Date?
    var endedAt: Date?

    // Schedule
    var scheduleStartHour: Int = 8
    var scheduleStartMinute: Int = 0
    var scheduleEndHour: Int = 22
    var scheduleEndMinute: Int = 0
    var activeDays: String = "1,2,3,4,5,6,7"
    var isVacationMode: Bool = false

    // App Limit
    var timeLimitMinutes: Int = 30

    // Lock
    var opensAllowed: Int = 3
    var unlockDurationMinutes: Int = 5
    var opensUsedToday: Int = 0

    // Tracking
    var completedAt: Date?

    init(
        name: String,
        type: String,
        selectionData: Data? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.selectionData = selectionData
        self.createdAt = .now
    }

    // MARK: - Computed

    var activeDaysSet: Set<Int> {
        get {
            Set(activeDays.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) })
        }
        set {
            activeDays = newValue.sorted().map(String.init).joined(separator: ",")
        }
    }

    var isExpired: Bool {
        completedAt != nil
    }

    var isPast: Bool {
        if type == "blockNow" {
            return endedAt != nil
        }
        return completedAt != nil
    }

    /// Decode the stored FamilyActivitySelection
    var selection: FamilyActivitySelection? {
        get {
            guard let data = selectionData else { return nil }
            return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        }
        set {
            selectionData = newValue.flatMap { try? PropertyListEncoder().encode($0) }
        }
    }

    /// Human-readable schedule summary for card display
    var scheduleSummary: String {
        switch type {
        case "blockNow":
            return "\(durationMinutes)m session"
        case "schedule":
            let start = String(format: "%02d:%02d", scheduleStartHour, scheduleStartMinute)
            let end = String(format: "%02d:%02d", scheduleEndHour, scheduleEndMinute)
            let dayCount = activeDaysSet.count
            let dayLabel = dayCount == 7 ? "Every day" : "\(dayCount) days/week"
            return "\(dayLabel), \(start) - \(end)"
        case "appLimit":
            return "\(timeLimitMinutes)m daily limit"
        case "lock":
            return "\(opensAllowed) opens/day, \(unlockDurationMinutes)m each"
        default:
            return ""
        }
    }

    /// Status label for block cards
    var statusLabel: String {
        if type == "blockNow" {
            if let started = startedAt, endedAt == nil {
                let remaining = durationMinutes * 60 - Int(Date().timeIntervalSince(started))
                if remaining > 0 {
                    let mins = remaining / 60
                    let secs = remaining % 60
                    return "Active - \(mins)m \(secs)s left"
                }
                return "Completed"
            }
            return "Ready"
        }
        if isVacationMode { return "Disabled" }
        if type == "schedule" {
            let now = Date()
            let cal = Calendar.current
            let weekday = cal.component(.weekday, from: now)
            guard activeDaysSet.contains(weekday) else { return "Off today" }
            let hour = cal.component(.hour, from: now)
            let minute = cal.component(.minute, from: now)
            let nowMins = hour * 60 + minute
            let startMins = scheduleStartHour * 60 + scheduleStartMinute
            let endMins = scheduleEndHour * 60 + scheduleEndMinute
            if nowMins >= startMins && nowMins < endMins { return "Active" }
            if nowMins < startMins {
                let diff = startMins - nowMins
                return "Starting in \(diff / 60)h \(diff % 60)m"
            }
            return "Done for today"
        }
        return "Active"
    }

    // MARK: - Block Now helpers

    func startSession() {
        startedAt = .now
    }

    func endSession() {
        endedAt = .now
        completedAt = .now
    }

    var blockNowRemainingSeconds: Int {
        guard let started = startedAt else { return durationMinutes * 60 }
        let elapsed = Int(Date().timeIntervalSince(started))
        return max(0, durationMinutes * 60 - elapsed)
    }

    var blockNowProgress: Double {
        let total = Double(durationMinutes * 60)
        guard total > 0 else { return 0 }
        return 1.0 - (Double(blockNowRemainingSeconds) / total)
    }

    var blockNowDisplayTime: String {
        let remaining = blockNowRemainingSeconds
        let mins = remaining / 60
        let secs = remaining % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
```

- [ ] **Step 2: Register ScreenBlock in the SwiftData schema**

In `TamaGoosie/App/TamaGoosieApp.swift`, add `ScreenBlock.self` to the schema array:

```swift
        let schema = Schema([
            GooseState.self,
            Goal.self,
            GoalProgress.self,
            GoalCompletionEvent.self,
            FocusSession.self,
            HealthSnapshot.self,
            DailyLog.self,
            UserProfile.self,
            ScreenBlock.self,
        ])
```

- [ ] **Step 3: Build to verify model compiles**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add TamaGoosie/Core/Models/ScreenBlock.swift TamaGoosie/App/TamaGoosieApp.swift
git commit -m "feat: add ScreenBlock SwiftData model for multi-block support"
```

---

### Task 2: Create ScreenTimeTabPicker

**Files:**
- Create: `TamaGoosie/Features/ScreenTime/ScreenTimeTabPicker.swift`

- [ ] **Step 1: Create the tab picker**

Create `TamaGoosie/Features/ScreenTime/ScreenTimeTabPicker.swift`:

```swift
import SwiftUI

enum ScreenTimeTab: String, CaseIterable {
    case stats = "Stats"
    case blocks = "Blocks"
}

struct ScreenTimeTabPicker: View {
    @Binding var selected: ScreenTimeTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ScreenTimeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(selected == tab ? .white : GoosieTheme.charcoalOutline.opacity(0.6))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selected == tab ? GoosieTheme.skyBlue : .clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/ScreenTime/ScreenTimeTabPicker.swift
git commit -m "feat: add ScreenTimeTabPicker (Stats/Blocks)"
```

---

### Task 3: Create DayOfWeekPicker

**Files:**
- Create: `TamaGoosie/Features/ScreenTime/DayOfWeekPicker.swift`

- [ ] **Step 1: Create the shared day-of-week picker**

Create `TamaGoosie/Features/ScreenTime/DayOfWeekPicker.swift`:

```swift
import SwiftUI

struct DayOfWeekPicker: View {
    @Binding var activeDays: Set<Int>

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Days of week active")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if activeDays.count == 7 {
                    Text("Every day")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { day in
                    let isActive = activeDays.contains(day)
                    Button {
                        if isActive {
                            activeDays.remove(day)
                        } else {
                            activeDays.insert(day)
                        }
                    } label: {
                        Text(dayLabels[day - 1])
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(isActive ? .black : .white.opacity(0.5))
                            .frame(width: 38, height: 38)
                            .background(
                                Circle()
                                    .fill(isActive ? .white : .white.opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.08))
        )
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/ScreenTime/DayOfWeekPicker.swift
git commit -m "feat: add DayOfWeekPicker shared component"
```

---

### Task 4: Create ScreenTimeStatsTab

**Files:**
- Create: `TamaGoosie/Features/ScreenTime/ScreenTimeStatsTab.swift`

- [ ] **Step 1: Create the stats tab view**

Create `TamaGoosie/Features/ScreenTime/ScreenTimeStatsTab.swift`:

```swift
import SwiftUI
import SwiftData
import DeviceActivity

struct ScreenTimeStatsTab: View {
    @State private var manager = ScreenTimeManager.shared
    @State private var selectedPeriod = 0
    @State private var selectedDate = Date()

    @Query(sort: \DailyLog.date, order: .reverse) private var allLogs: [DailyLog]

    private var todayLog: DailyLog? {
        allLogs.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var yesterdayLog: DailyLog? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        return allLogs.first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var body: some View {
        VStack(spacing: 16) {
            periodPicker
            dateNavigation
            heroStat
            quickStatsRow
            distributionReport
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            Text("Day").tag(0)
            Text("Week").tag(1)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Date Navigation

    private var dateNavigation: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(
                    byAdding: selectedPeriod == 0 ? .day : .weekOfYear,
                    value: -1,
                    to: selectedDate
                ) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Text(dateLabel)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button {
                let next = Calendar.current.date(
                    byAdding: selectedPeriod == 0 ? .day : .weekOfYear,
                    value: 1,
                    to: selectedDate
                ) ?? selectedDate
                if next <= Date() {
                    selectedDate = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isToday ? .white.opacity(0.15) : .white.opacity(0.5))
            }
            .disabled(isToday)
        }
        .padding(.vertical, 4)
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let base = formatter.string(from: selectedDate)
        return isToday ? "\(base) (Today)" : base
    }

    // MARK: - Hero Stat

    private var heroStat: some View {
        VStack(spacing: 6) {
            Text(formatMinutes(distractionMinutesForPeriod))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("SCREEN TIME")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)

            if let change = distractionChange {
                Text(change)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(changeColor(change))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(changeColor(change).opacity(0.15), in: Capsule())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.08))
        )
    }

    // MARK: - Quick Stats

    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            quickStatCard(
                icon: "hourglass",
                iconColor: GoosieTheme.skyBlue,
                title: "Limit Remaining",
                value: formatMinutes(max(0, manager.userLimitMinutes - currentDistractionMinutes))
            )

            quickStatCard(
                icon: "iphone.gen1",
                iconColor: GoosieTheme.coralAccent,
                title: "Opens",
                value: "\(todayLog?.distractionOpens ?? 0)"
            )
        }
    }

    private func quickStatCard(icon: String, iconColor: Color, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(iconColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.08))
        )
    }

    // MARK: - Distribution Report

    private var distributionReport: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(GoosieTheme.skyBlue)
                Text("App Usage")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }

            DeviceActivityReport(.init(rawValue: "distraction_summary"))
                .frame(height: 250)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.08))
        )
    }

    // MARK: - Data Helpers

    private var distractionMinutesForPeriod: Int {
        if selectedPeriod == 0 {
            return todayLog?.distractionMinutes ?? (isToday ? manager.approxMinutesToday : 0)
        } else {
            let cal = Calendar.current
            guard let weekStart = cal.date(byAdding: .day, value: -6, to: selectedDate) else { return 0 }
            return allLogs
                .filter { $0.date >= cal.startOfDay(for: weekStart) && $0.date <= cal.startOfDay(for: selectedDate) }
                .reduce(0) { $0 + $1.distractionMinutes }
        }
    }

    private var currentDistractionMinutes: Int {
        todayLog?.distractionMinutes ?? manager.approxMinutesToday
    }

    private var distractionChange: String? {
        guard selectedPeriod == 0 else { return nil }
        guard let yesterday = yesterdayLog, yesterday.distractionMinutes > 0 else {
            return "No prior data"
        }
        let current = todayLog?.distractionMinutes ?? (isToday ? manager.approxMinutesToday : 0)
        if current == 0 && yesterday.distractionMinutes == 0 { return nil }
        let pct = Int(round(Double(current - yesterday.distractionMinutes) / Double(yesterday.distractionMinutes) * 100))
        if pct < 0 { return "\(pct)%" }
        else if pct > 0 { return "+\(pct)%" }
        return "No change"
    }

    private func changeColor(_ change: String) -> Color {
        if change.hasPrefix("-") { return .green }
        else if change.hasPrefix("+") { return GoosieTheme.coralAccent }
        return .white.opacity(0.5)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/ScreenTime/ScreenTimeStatsTab.swift
git commit -m "feat: add ScreenTimeStatsTab with hero stat, quick stats, and DeviceActivityReport"
```

---

### Task 5: Create BlockCardView

**Files:**
- Create: `TamaGoosie/Features/ScreenTime/BlockCardView.swift`

- [ ] **Step 1: Create the block card view**

Create `TamaGoosie/Features/ScreenTime/BlockCardView.swift`:

```swift
import SwiftUI

struct BlockCardView: View {
    let block: ScreenBlock
    var onTap: () -> Void
    var onDelete: () -> Void

    private var typeIcon: String {
        switch block.type {
        case "blockNow": return "timer"
        case "schedule": return "calendar.badge.clock"
        case "appLimit": return "hourglass"
        case "lock": return "lock.fill"
        default: return "questionmark.circle"
        }
    }

    private var typeColor: Color {
        switch block.type {
        case "blockNow": return GoosieTheme.coralAccent
        case "schedule": return GoosieTheme.skyBlue
        case "appLimit": return GoosieTheme.warmOrange
        case "lock": return .purple
        default: return .gray
        }
    }

    private var statusColor: Color {
        let label = block.statusLabel
        if label.contains("Active") { return .green }
        if label.contains("Disabled") || label.contains("Off") { return .gray }
        if label.contains("Starting") { return GoosieTheme.skyBlue }
        return .white.opacity(0.5)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: typeIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(typeColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(block.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(block.scheduleSummary)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    Text(block.statusLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.15), in: Capsule())
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white.opacity(0.08))
            )
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Past Block Row (compact, for history section)

struct PastBlockRow: View {
    let block: ScreenBlock

    private var typeIcon: String {
        switch block.type {
        case "blockNow": return "timer"
        case "schedule": return "calendar.badge.clock"
        case "appLimit": return "hourglass"
        case "lock": return "lock.fill"
        default: return "questionmark.circle"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: typeIcon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(block.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                if let completed = block.completedAt ?? block.endedAt {
                    Text(completed.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            Spacer()

            if block.type == "blockNow" {
                Text("\(block.durationMinutes)m")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.05))
        )
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/ScreenTime/BlockCardView.swift
git commit -m "feat: add BlockCardView and PastBlockRow for block list display"
```

---

### Task 6: Create Block Creation Sheets

**Files:**
- Create: `TamaGoosie/Features/ScreenTime/BlockNowSheet.swift`
- Create: `TamaGoosie/Features/ScreenTime/ScheduleSessionSheet.swift`
- Create: `TamaGoosie/Features/ScreenTime/AppLimitSheet.swift`
- Create: `TamaGoosie/Features/ScreenTime/LockSheet.swift`

- [ ] **Step 1: Create BlockNowSheet**

Create `TamaGoosie/Features/ScreenTime/BlockNowSheet.swift`:

```swift
import SwiftUI
import SwiftData
import FamilyControls

struct BlockNowSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingBlock: ScreenBlock?

    @State private var name: String = "Focus Session"
    @State private var durationMinutes: Int = 25
    @State private var showPicker = false
    @State private var draftSelection = FamilyActivitySelection()
    @State private var selectionData: Data?

    // Active session state
    @State private var activeBlock: ScreenBlock?
    @State private var timer: Timer?
    @State private var remainingSeconds: Int = 0

    private var hasSelection: Bool {
        !draftSelection.applicationTokens.isEmpty || !draftSelection.categoryTokens.isEmpty
    }

    private var isSessionActive: Bool {
        activeBlock?.startedAt != nil && activeBlock?.endedAt == nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if isSessionActive {
                            activeSessionView
                        } else {
                            configView
                        }
                    }
                    .padding(GoosieTheme.padding)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if isSessionActive {
                            endSession()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $draftSelection)
            .onChange(of: showPicker) { wasShowing, isShowing in
                if wasShowing && !isShowing {
                    selectionData = try? PropertyListEncoder().encode(draftSelection)
                }
            }
            .onAppear {
                if let block = existingBlock {
                    name = block.name
                    durationMinutes = block.durationMinutes
                    if let sel = block.selection {
                        draftSelection = sel
                    }
                    selectionData = block.selectionData
                    if block.startedAt != nil && block.endedAt == nil {
                        activeBlock = block
                        remainingSeconds = block.blockNowRemainingSeconds
                        startTimer()
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Config View

    private var configView: some View {
        VStack(spacing: 16) {
            // Name
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                TextField("Session name", text: $name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))

            // Duration
            HStack {
                Text("Duration")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Stepper("\(durationMinutes)m", value: $durationMinutes, in: 5...120, step: 5)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))

            // Apps Blocked
            Button { showPicker = true } label: {
                HStack {
                    Text("Apps Blocked")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    let count = draftSelection.applicationTokens.count + draftSelection.categoryTokens.count
                    Text(count > 0 ? "\(count) selected" : "Choose")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
            }

            Spacer().frame(height: 20)

            // Start button
            Button(action: startSession) {
                Text("Start Session")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!hasSelection)
            .opacity(hasSelection ? 1 : 0.4)
        }
    }

    // MARK: - Active Session View

    private var activeSessionView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            // Timer ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 220, height: 220)

                Circle()
                    .trim(from: 0, to: sessionProgress)
                    .stroke(
                        GoosieTheme.coralAccent,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: sessionProgress)

                VStack(spacing: 4) {
                    Text(displayTime)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(name)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            // End session button
            Button(action: endSession) {
                Text("End Session")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(GoosieTheme.coralAccent, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var sessionProgress: Double {
        let total = Double(durationMinutes * 60)
        guard total > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / total)
    }

    private var displayTime: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Session Management

    private func startSession() {
        let block = ScreenBlock(name: name, type: "blockNow", selectionData: selectionData)
        block.durationMinutes = durationMinutes
        block.startSession()
        modelContext.insert(block)
        try? modelContext.save()

        activeBlock = block
        remainingSeconds = durationMinutes * 60

        ScreenTimeManager.shared.registerBlock(block)
        startTimer()
    }

    private func endSession() {
        timer?.invalidate()
        timer = nil
        if let block = activeBlock {
            block.endSession()
            ScreenTimeManager.shared.unregisterBlock(block)
            try? modelContext.save()
        }
        dismiss()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                endSession()
            }
        }
    }
}
```

- [ ] **Step 2: Create ScheduleSessionSheet**

Create `TamaGoosie/Features/ScreenTime/ScheduleSessionSheet.swift`:

```swift
import SwiftUI
import SwiftData
import FamilyControls

struct ScheduleSessionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingBlock: ScreenBlock?

    @State private var name: String = ""
    @State private var startTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @State private var endTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var activeDays: Set<Int> = Set(1...7)
    @State private var isVacationMode = false
    @State private var showPicker = false
    @State private var draftSelection = FamilyActivitySelection()
    @State private var selectionData: Data?

    private var hasSelection: Bool {
        !draftSelection.applicationTokens.isEmpty || !draftSelection.categoryTokens.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Name
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(GoosieTheme.skyBlue)
                            TextField("Session name", text: $name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))

                        // Time range
                        VStack(spacing: 0) {
                            HStack {
                                Circle().fill(.green).frame(width: 8, height: 8)
                                Text("From")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                            }
                            .padding(.vertical, 10)

                            Divider().background(.white.opacity(0.1))

                            HStack {
                                Circle().stroke(.white.opacity(0.3), lineWidth: 1.5).frame(width: 8, height: 8)
                                Text("To")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                            }
                            .padding(.vertical, 10)
                        }
                        .padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))

                        // Days
                        DayOfWeekPicker(activeDays: $activeDays)

                        // Apps Blocked
                        Button { showPicker = true } label: {
                            HStack {
                                Text("Apps Blocked")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                let count = draftSelection.applicationTokens.count + draftSelection.categoryTokens.count
                                Text(count > 0 ? "\(count) selected" : "Choose")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
                        }

                        // Vacation mode
                        if existingBlock != nil {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Vacation Mode")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Temporarily disable this session")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                Spacer()
                                Toggle("", isOn: $isVacationMode)
                                    .labelsHidden()
                                    .tint(GoosieTheme.skyBlue)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
                        }

                        Spacer().frame(height: 20)

                        // Save
                        Button(action: save) {
                            Text("Save")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(name.isEmpty || !hasSelection)
                        .opacity(name.isEmpty || !hasSelection ? 0.4 : 1)
                    }
                    .padding(GoosieTheme.padding)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $draftSelection)
            .onChange(of: showPicker) { wasShowing, isShowing in
                if wasShowing && !isShowing {
                    selectionData = try? PropertyListEncoder().encode(draftSelection)
                }
            }
            .onAppear { loadExisting() }
            .preferredColorScheme(.dark)
        }
    }

    private func loadExisting() {
        guard let block = existingBlock else { return }
        name = block.name
        activeDays = block.activeDaysSet
        isVacationMode = block.isVacationMode
        if let sel = block.selection { draftSelection = sel }
        selectionData = block.selectionData

        var startComps = DateComponents()
        startComps.hour = block.scheduleStartHour
        startComps.minute = block.scheduleStartMinute
        startTime = Calendar.current.date(from: startComps) ?? startTime

        var endComps = DateComponents()
        endComps.hour = block.scheduleEndHour
        endComps.minute = block.scheduleEndMinute
        endTime = Calendar.current.date(from: endComps) ?? endTime
    }

    private func save() {
        let block = existingBlock ?? ScreenBlock(name: name, type: "schedule", selectionData: selectionData)

        block.name = name
        block.selectionData = selectionData
        block.isVacationMode = isVacationMode
        block.activeDaysSet = activeDays

        let startComps = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        block.scheduleStartHour = startComps.hour ?? 8
        block.scheduleStartMinute = startComps.minute ?? 0
        let endComps = Calendar.current.dateComponents([.hour, .minute], from: endTime)
        block.scheduleEndHour = endComps.hour ?? 22
        block.scheduleEndMinute = endComps.minute ?? 0

        if existingBlock == nil {
            modelContext.insert(block)
        }
        try? modelContext.save()

        if !block.isVacationMode {
            ScreenTimeManager.shared.registerBlock(block)
        } else {
            ScreenTimeManager.shared.unregisterBlock(block)
        }

        dismiss()
    }
}
```

- [ ] **Step 3: Create AppLimitSheet**

Create `TamaGoosie/Features/ScreenTime/AppLimitSheet.swift`:

```swift
import SwiftUI
import SwiftData
import FamilyControls

struct AppLimitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingBlock: ScreenBlock?

    @State private var name: String = ""
    @State private var timeLimitMinutes: Int = 30
    @State private var activeDays: Set<Int> = Set(1...7)
    @State private var showPicker = false
    @State private var draftSelection = FamilyActivitySelection()
    @State private var selectionData: Data?

    private var hasSelection: Bool {
        !draftSelection.applicationTokens.isEmpty || !draftSelection.categoryTokens.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Name
                        HStack {
                            Image(systemName: "hourglass")
                                .foregroundStyle(GoosieTheme.warmOrange)
                            TextField("Limit name", text: $name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))

                        // App selection
                        Button { showPicker = true } label: {
                            HStack {
                                Text("App")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                let count = draftSelection.applicationTokens.count + draftSelection.categoryTokens.count
                                Text(count > 0 ? "\(count) selected" : "Choose")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
                        }

                        // Time allowed
                        VStack(spacing: 0) {
                            HStack {
                                Text("Time Allowed")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Stepper("\(timeLimitMinutes)m", value: $timeLimitMinutes, in: 15...240, step: 15)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))

                        // Days
                        DayOfWeekPicker(activeDays: $activeDays)

                        Spacer().frame(height: 20)

                        // Save
                        Button(action: save) {
                            Text("Save")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(name.isEmpty || !hasSelection)
                        .opacity(name.isEmpty || !hasSelection ? 0.4 : 1)
                    }
                    .padding(GoosieTheme.padding)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $draftSelection)
            .onChange(of: showPicker) { wasShowing, isShowing in
                if wasShowing && !isShowing {
                    selectionData = try? PropertyListEncoder().encode(draftSelection)
                }
            }
            .onAppear { loadExisting() }
            .preferredColorScheme(.dark)
        }
    }

    private func loadExisting() {
        guard let block = existingBlock else { return }
        name = block.name
        timeLimitMinutes = block.timeLimitMinutes
        activeDays = block.activeDaysSet
        if let sel = block.selection { draftSelection = sel }
        selectionData = block.selectionData
    }

    private func save() {
        let block = existingBlock ?? ScreenBlock(name: name, type: "appLimit", selectionData: selectionData)

        block.name = name
        block.selectionData = selectionData
        block.timeLimitMinutes = timeLimitMinutes
        block.activeDaysSet = activeDays

        if existingBlock == nil {
            modelContext.insert(block)
        }
        try? modelContext.save()
        ScreenTimeManager.shared.registerBlock(block)
        dismiss()
    }
}
```

- [ ] **Step 4: Create LockSheet**

Create `TamaGoosie/Features/ScreenTime/LockSheet.swift`:

```swift
import SwiftUI
import SwiftData
import FamilyControls

struct LockSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingBlock: ScreenBlock?

    @State private var name: String = ""
    @State private var opensAllowed: Int = 3
    @State private var unlockDurationMinutes: Int = 5
    @State private var activeDays: Set<Int> = Set(1...7)
    @State private var showPicker = false
    @State private var draftSelection = FamilyActivitySelection()
    @State private var selectionData: Data?

    private var hasSelection: Bool {
        !draftSelection.applicationTokens.isEmpty || !draftSelection.categoryTokens.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Name
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.purple)
                            TextField("Lock name", text: $name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))

                        // App selection
                        Button { showPicker = true } label: {
                            HStack {
                                Text("Apps Blocked")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                let count = draftSelection.applicationTokens.count + draftSelection.categoryTokens.count
                                Text(count > 0 ? "\(count) selected" : "Choose")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
                        }

                        // Explanation
                        Text("The app is **blocked at all times** but you can unlock it a set number of times per day.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 4)

                        // Lock settings
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Opens Allowed")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Per day")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                Spacer()
                                Stepper("\(opensAllowed)", value: $opensAllowed, in: 1...20)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .padding(.vertical, 10)

                            Divider().background(.white.opacity(0.1))

                            HStack {
                                Text("For Up To")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Stepper("\(unlockDurationMinutes)m", value: $unlockDurationMinutes, in: 5...60, step: 5)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .padding(.vertical, 10)
                        }
                        .padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))

                        // Days
                        DayOfWeekPicker(activeDays: $activeDays)

                        Spacer().frame(height: 20)

                        // Save
                        Button(action: save) {
                            Text("Save")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(name.isEmpty || !hasSelection)
                        .opacity(name.isEmpty || !hasSelection ? 0.4 : 1)

                        // Remove button (edit mode only)
                        if existingBlock != nil {
                            Button(role: .destructive) {
                                if let block = existingBlock {
                                    ScreenTimeManager.shared.unregisterBlock(block)
                                    modelContext.delete(block)
                                    try? modelContext.save()
                                }
                                dismiss()
                            } label: {
                                Text("Remove Lock")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(GoosieTheme.padding)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $draftSelection)
            .onChange(of: showPicker) { wasShowing, isShowing in
                if wasShowing && !isShowing {
                    selectionData = try? PropertyListEncoder().encode(draftSelection)
                }
            }
            .onAppear { loadExisting() }
            .preferredColorScheme(.dark)
        }
    }

    private func loadExisting() {
        guard let block = existingBlock else { return }
        name = block.name
        opensAllowed = block.opensAllowed
        unlockDurationMinutes = block.unlockDurationMinutes
        activeDays = block.activeDaysSet
        if let sel = block.selection { draftSelection = sel }
        selectionData = block.selectionData
    }

    private func save() {
        let block = existingBlock ?? ScreenBlock(name: name, type: "lock", selectionData: selectionData)

        block.name = name
        block.selectionData = selectionData
        block.opensAllowed = opensAllowed
        block.unlockDurationMinutes = unlockDurationMinutes
        block.activeDaysSet = activeDays

        if existingBlock == nil {
            modelContext.insert(block)
        }
        try? modelContext.save()
        ScreenTimeManager.shared.registerBlock(block)
        dismiss()
    }
}
```

- [ ] **Step 5: Build to verify all sheets compile**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED` (will fail until Task 8 adds `registerBlock`/`unregisterBlock` to `ScreenTimeManager` — that's expected, proceed to next tasks)

- [ ] **Step 6: Commit**

```bash
git add TamaGoosie/Features/ScreenTime/BlockNowSheet.swift TamaGoosie/Features/ScreenTime/ScheduleSessionSheet.swift TamaGoosie/Features/ScreenTime/AppLimitSheet.swift TamaGoosie/Features/ScreenTime/LockSheet.swift
git commit -m "feat: add creation sheets for all four block types"
```

---

### Task 7: Create ScreenTimeBlocksTab

**Files:**
- Create: `TamaGoosie/Features/ScreenTime/ScreenTimeBlocksTab.swift`

- [ ] **Step 1: Create the blocks tab view**

Create `TamaGoosie/Features/ScreenTime/ScreenTimeBlocksTab.swift`:

```swift
import SwiftUI
import SwiftData

struct ScreenTimeBlocksTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScreenBlock.createdAt, order: .reverse) private var allBlocks: [ScreenBlock]

    @State private var showBlockNow = false
    @State private var showSchedule = false
    @State private var showAppLimit = false
    @State private var showLock = false
    @State private var editingBlock: ScreenBlock?
    @State private var showHistory = false

    private var activeBlocks: [ScreenBlock] {
        allBlocks.filter { !$0.isPast }
    }

    private var pastBlocks: [ScreenBlock] {
        allBlocks.filter { $0.isPast }
            .sorted { ($0.completedAt ?? $0.endedAt ?? .distantPast) > ($1.completedAt ?? $1.endedAt ?? .distantPast) }
    }

    var body: some View {
        VStack(spacing: 16) {
            if activeBlocks.isEmpty && pastBlocks.isEmpty {
                emptyState
            } else {
                // Active blocks
                if !activeBlocks.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(activeBlocks, id: \.id) { block in
                            BlockCardView(
                                block: block,
                                onTap: { editBlock(block) },
                                onDelete: { deleteBlock(block) }
                            )
                        }
                    }
                }

                // Past section
                if !pastBlocks.isEmpty {
                    pastSection
                }
            }

            // New block buttons
            newBlockSection

            Spacer().frame(height: 20)
        }
        .fullScreenCover(isPresented: $showBlockNow) {
            BlockNowSheet(existingBlock: editingBlock?.type == "blockNow" ? editingBlock : nil)
        }
        .fullScreenCover(isPresented: $showSchedule) {
            ScheduleSessionSheet(existingBlock: editingBlock?.type == "schedule" ? editingBlock : nil)
        }
        .fullScreenCover(isPresented: $showAppLimit) {
            AppLimitSheet(existingBlock: editingBlock?.type == "appLimit" ? editingBlock : nil)
        }
        .fullScreenCover(isPresented: $showLock) {
            LockSheet(existingBlock: editingBlock?.type == "lock" ? editingBlock : nil)
        }
        .onChange(of: showBlockNow) { _, showing in if !showing { editingBlock = nil } }
        .onChange(of: showSchedule) { _, showing in if !showing { editingBlock = nil } }
        .onChange(of: showAppLimit) { _, showing in if !showing { editingBlock = nil } }
        .onChange(of: showLock) { _, showing in if !showing { editingBlock = nil } }
    }

    // MARK: - New Block Section

    private var newBlockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New Block")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 12) {
                newBlockButton(icon: "timer", label: "Block Now", color: GoosieTheme.coralAccent) {
                    editingBlock = nil
                    showBlockNow = true
                }
                newBlockButton(icon: "calendar.badge.clock", label: "Schedule", color: GoosieTheme.skyBlue) {
                    editingBlock = nil
                    showSchedule = true
                }
                newBlockButton(icon: "hourglass", label: "App Limit", color: GoosieTheme.warmOrange) {
                    editingBlock = nil
                    showAppLimit = true
                }
                newBlockButton(icon: "lock.fill", label: "Lock", color: .purple) {
                    editingBlock = nil
                    showLock = true
                }
            }
        }
    }

    private func newBlockButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))

                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Past Section

    private var pastSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHistory.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showHistory ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                    Text("Past")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Text("\(pastBlocks.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.6))
                .padding(.vertical, 8)
            }

            if showHistory {
                VStack(spacing: 8) {
                    ForEach(pastBlocks, id: \.id) { block in
                        PastBlockRow(block: block)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))

            Text("No blocks set up")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            Text("Here are some ideas to get you started")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))

            Button {
                editingBlock = nil
                showBlockNow = true
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                    Text("Block Now")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [GoosieTheme.coralAccent.opacity(0.8), GoosieTheme.coralAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .padding(.top, 8)
        }
        .padding(.top, 40)
    }

    // MARK: - Helpers

    private func editBlock(_ block: ScreenBlock) {
        editingBlock = block
        switch block.type {
        case "blockNow": showBlockNow = true
        case "schedule": showSchedule = true
        case "appLimit": showAppLimit = true
        case "lock": showLock = true
        default: break
        }
    }

    private func deleteBlock(_ block: ScreenBlock) {
        ScreenTimeManager.shared.unregisterBlock(block)
        modelContext.delete(block)
        try? modelContext.save()
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: May fail until `ScreenTimeManager` methods are added in Task 8.

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/ScreenTime/ScreenTimeBlocksTab.swift
git commit -m "feat: add ScreenTimeBlocksTab with active/past blocks and new block buttons"
```

---

### Task 8: Update ScreenTimeManager with Per-Block Monitoring

**Files:**
- Modify: `TamaGoosie/Core/Services/ScreenTimeManager.swift`

- [ ] **Step 1: Add registerBlock and unregisterBlock methods**

Add the following methods to `ScreenTimeManager` before the closing `}` of the class, after the existing `stopMonitoring()` method:

```swift
    // MARK: - Per-Block Monitoring

    func registerBlock(_ block: ScreenBlock) {
        guard isAuthorized else { return }
        guard let selection = block.selection else { return }

        let blockID = block.id.uuidString
        let activityName = DeviceActivityName("block-\(blockID)")

        // Stop any existing monitor for this block
        activityCenter.stopMonitoring([activityName])

        let startComps: DateComponents
        let endComps: DateComponents

        switch block.type {
        case "blockNow":
            // Block Now: monitor from now until duration expires
            // The timer handles completion; we just need the shield active
            startComps = DateComponents(hour: 0, minute: 0)
            endComps = DateComponents(hour: 23, minute: 59)

        case "schedule":
            guard !block.isVacationMode else { return }
            startComps = DateComponents(hour: block.scheduleStartHour, minute: block.scheduleStartMinute)
            endComps = DateComponents(hour: block.scheduleEndHour, minute: block.scheduleEndMinute)

        case "appLimit":
            // App Limit: monitor all day, with threshold event at the limit
            startComps = DateComponents(hour: 0, minute: 0)
            endComps = DateComponents(hour: 23, minute: 59)

        case "lock":
            // Lock: monitor all day
            startComps = DateComponents(hour: 0, minute: 0)
            endComps = DateComponents(hour: 23, minute: 59)

        default:
            return
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd: endComps,
            repeats: block.type != "blockNow"
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        if block.type == "appLimit" {
            let eventName = DeviceActivityEvent.Name("limit-\(blockID)")
            events[eventName] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: block.timeLimitMinutes)
            )
        }

        do {
            try activityCenter.startMonitoring(activityName, during: schedule, events: events)
        } catch {
            print("[ScreenTimeManager] registerBlock failed for \(block.name): \(error)")
        }
    }

    func unregisterBlock(_ block: ScreenBlock) {
        let activityName = DeviceActivityName("block-\(block.id.uuidString)")
        activityCenter.stopMonitoring([activityName])
    }

    func refreshAllBlocks(_ blocks: [ScreenBlock]) {
        for block in blocks where !block.isPast {
            registerBlock(block)
        }
    }
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Core/Services/ScreenTimeManager.swift
git commit -m "feat: add per-block DeviceActivity monitoring to ScreenTimeManager"
```

---

### Task 9: Wire Up ScreenTimePageView

**Files:**
- Modify: `TamaGoosie/Features/ScreenTime/ScreenTimePageView.swift`

- [ ] **Step 1: Replace the body of ScreenTimePageView**

Replace the entire contents of `TamaGoosie/Features/ScreenTime/ScreenTimePageView.swift` with:

```swift
import SwiftUI
import SwiftData

struct ScreenTimePageView: View {
    @State private var manager = ScreenTimeManager.shared
    @Query private var gooseStates: [GooseState]
    @Query(sort: \ScreenBlock.createdAt, order: .reverse) private var allBlocks: [ScreenBlock]

    @State private var selectedTab: ScreenTimeTab = .stats

    private var gooseName: String {
        gooseStates.first?.name ?? "Harold"
    }

    var body: some View {
        ZStack {
            GrassyBackgroundView()

            VStack(spacing: 0) {
                if manager.isSetupComplete {
                    ScrollView {
                        VStack(spacing: 16) {
                            ScreenTimeTabPicker(selected: $selectedTab)

                            switch selectedTab {
                            case .stats:
                                ScreenTimeStatsTab()
                            case .blocks:
                                ScreenTimeBlocksTab()
                            }
                        }
                        .padding(.horizontal, GoosieTheme.padding)
                        .padding(.top, 52)
                        .padding(.bottom, 20)
                        .trackScrollOffset()
                    }
                } else {
                    ScreenTimeOnboardingView(gooseName: gooseName) {
                        // onComplete — setup is done
                    }
                }
            }
        }
        .onAppear {
            let activeBlocks = allBlocks.filter { !$0.isPast }
            ScreenTimeManager.shared.refreshAllBlocks(activeBlocks)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/ScreenTime/ScreenTimePageView.swift
git commit -m "feat: wire ScreenTimePageView with Stats/Blocks tab picker"
```

---

### Task 10: Clean Up Replaced Files

**Files:**
- Delete or keep: `TamaGoosie/Features/ScreenTime/ScreenTimeDashboardView.swift`
- Delete or keep: `TamaGoosie/Features/Focus/FocusSessionView.swift`
- Delete or keep: `TamaGoosie/Features/Focus/FocusTimer.swift`
- Modify: `TamaGoosie/Features/ScreenTime/ScreenTimeScheduleView.swift` (check if still referenced)

- [ ] **Step 1: Check for remaining references to deleted views**

Run grep to find any imports or usages of `ScreenTimeDashboardView`, `FocusSessionView`, or `FocusTimer` outside their own files:

```bash
grep -r "ScreenTimeDashboardView\|FocusSessionView\|FocusTimer" --include="*.swift" TamaGoosie/ | grep -v "ScreenTimeDashboardView.swift" | grep -v "FocusSessionView.swift" | grep -v "FocusTimer.swift"
```

If any references remain (e.g., in `ContentView.swift`), remove them. The `ScreenTimePageView` no longer references `ScreenTimeDashboardView`. Check if `FocusSessionView` is used anywhere in tab routing — based on the current `ContentView.swift`, it is NOT in the tab bar (tab 2 is `ScreenTimePageView`), so it's safe to remove.

- [ ] **Step 2: Delete replaced files**

```bash
rm TamaGoosie/Features/ScreenTime/ScreenTimeDashboardView.swift
rm TamaGoosie/Features/Focus/FocusSessionView.swift
rm TamaGoosie/Features/Focus/FocusTimer.swift
```

- [ ] **Step 3: Check if ScreenTimeScheduleView is still used**

It was used in `ScreenTimeOnboardingView` (step 5 of onboarding). Keep it — the onboarding flow still needs it. It will also serve as backward compatibility for users who set up before the redesign.

- [ ] **Step 4: Check if DistractionOverlay still references FocusTimer**

Run: `grep -r "FocusTimer" TamaGoosie/Features/Focus/DistractionOverlay.swift`

If no references, proceed. `DistractionOverlay` is independent and stays.

- [ ] **Step 5: Build to verify everything compiles after deletions**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: remove ScreenTimeDashboardView, FocusSessionView, FocusTimer (replaced by new blocks system)"
```

---

### Task 11: Final Build Verification

- [ ] **Step 1: Full clean build**

```bash
xcodebuild clean build -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 2: Verify no warnings related to new files**

```bash
xcodebuild build -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -i "warning:" | grep -i "screen\|block\|lock\|limit"
```

Expected: No output (no warnings)

- [ ] **Step 3: Commit any final fixes**

If any build issues were found and fixed:
```bash
git add -A
git commit -m "fix: resolve build issues from screen time redesign"
```
