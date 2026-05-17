# Goals Page Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the Goals page from a two-section list into a three-tab layout (Today / Habits / Quests) with weekly heat maps and Pokemon GO-styled UI.

**Architecture:** Split the monolithic GoalListView into a container + three tab-specific views. Add `completionDates: [Date]` to the Goal model for heat map history. Introduce two new reusable components (GoalTabPicker, WeeklyHeatMap). Container keeps all @Query, shared logic, sheets, and confetti. Tabs receive filtered data and callbacks.

**Tech Stack:** SwiftUI, SwiftData, iOS 17+

---

### Task 1: Add `completionDates` to Goal model

**Files:**
- Modify: `TamaGoosie/Core/Models/Goal.swift`

- [ ] **Step 1: Add the completionDates property to Goal**

Add the stored property after `createdAt` (line 31), and add two helper methods. SwiftData handles new defaulted properties without migration.

```swift
// Add after line 31 (createdAt):
var completionDates: [Date] = []
```

Add these methods after the existing `resetForNewDay()` method (after line 175):

```swift
/// Record today as a completion date (idempotent for the same calendar day).
func recordCompletion() {
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)
    if !completionDates.contains(where: { cal.isDate($0, inSameDayAs: today) }) {
        completionDates.append(today)
    }
    // Prune to last 90 days
    let cutoff = cal.date(byAdding: .day, value: -90, to: today) ?? today
    completionDates.removeAll { $0 < cutoff }
}

/// Remove today from completion dates (for uncomplete).
func removeCompletionForToday() {
    let cal = Calendar.current
    completionDates.removeAll { cal.isDate($0, inSameDayAs: .now) }
}
```

- [ ] **Step 2: Wire recordCompletion into existing complete/uncomplete flows**

In `Goal.swift`, update `complete()` to also call `recordCompletion()`:

```swift
func complete() {
    currentCount = targetCount
    isCompleted = true
    completedAt = .now
    lastCompletedDate = .now
    recordCompletion()
}
```

Update `resetForNewDay()` — no change needed (it doesn't remove history, just resets daily state).

- [ ] **Step 3: Wire removeCompletionForToday into uncomplete**

In `GoalViewModel.swift`, the `uncompleteGoal` method calls `GooseEngine.shared.uncompleteGoal`. We need to also call `goal.removeCompletionForToday()`. Add it in `GoalViewModel.uncompleteGoal`:

```swift
func uncompleteGoal(_ goal: Goal, gooseState: GooseState, log: DailyLog?, goals: [Goal]) {
    goal.removeCompletionForToday()
    GooseEngine.shared.uncompleteGoal(goal, state: gooseState, log: log, goals: goals)
}
```

- [ ] **Step 4: Build to verify no compilation errors**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add TamaGoosie/Core/Models/Goal.swift TamaGoosie/Features/Goals/GoalViewModel.swift
git commit -m "feat: add completionDates to Goal model for heat map history"
```

---

### Task 2: Create GoalTabPicker component

**Files:**
- Create: `TamaGoosie/Features/Goals/GoalTabPicker.swift`

- [ ] **Step 1: Create GoalTabPicker.swift**

```swift
import SwiftUI

enum GoalTab: String, CaseIterable {
    case today = "Today"
    case habits = "Habits"
    case quests = "Quests"
}

struct GoalTabPicker: View {
    @Binding var selected: GoalTab

    private let pokGreen = Color(hex: 0x43A047)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(GoalTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(selected == tab ? .white : GoosieTheme.charcoalOutline.opacity(0.6))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selected == tab ? pokGreen : .clear)
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

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Goals/GoalTabPicker.swift
git commit -m "feat: add GoalTabPicker segmented pill component"
```

---

### Task 3: Create WeeklyHeatMap component

**Files:**
- Create: `TamaGoosie/Features/Goals/WeeklyHeatMap.swift`

- [ ] **Step 1: Create WeeklyHeatMap.swift**

The heat map shows 7 cells for the current week (Mon-Sun). Green for completed days, light for incomplete past days, gray for future days.

```swift
import SwiftUI

struct WeeklyHeatMap: View {
    let completionDates: [Date]

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let completedColor = Color(hex: 0x43A047)
    private let missedColor = Color(hex: 0xE8F5E9)
    private let futureColor = Color(hex: 0xEEEEEE)

    /// Returns the Monday-starting dates for the current week.
    private var weekDates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // Find Monday of this week
        let weekday = cal.component(.weekday, from: today)
        // weekday: 1=Sun, 2=Mon, ... 7=Sat
        let daysFromMonday = (weekday + 5) % 7 // Mon=0, Tue=1, ... Sun=6
        guard let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return []
        }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    private func cellColor(for date: Date) -> Color {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        if date > today {
            return futureColor
        }

        let isCompleted = completionDates.contains { cal.isDate($0, inSameDayAs: date) }
        return isCompleted ? completedColor : missedColor
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(zip(weekDates.indices, weekDates)), id: \.0) { index, date in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(cellColor(for: date))
                        .frame(height: 18)

                    Text(dayLabels[index])
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.black.opacity(0.35))
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Goals/WeeklyHeatMap.swift
git commit -m "feat: add WeeklyHeatMap component for habit tracking"
```

---

### Task 4: Create TodayGoalsTab

**Files:**
- Create: `TamaGoosie/Features/Goals/TodayGoalsTab.swift`

This tab shows a date header, a progress summary bar, and a flat list of all active goals for today. It reuses the existing card views (GoalCardView, HealthKitGoalCardView, DeadlineGoalCardView) from GoalListView.swift.

- [ ] **Step 1: Create TodayGoalsTab.swift**

```swift
import SwiftUI

struct TodayGoalsTab: View {
    let goals: [Goal]
    let gooseState: GooseState?
    let todayLog: DailyLog?
    let viewModel: GoalViewModel
    let onEnsureTodayLog: () -> DailyLog
    let onConfetti: (CGPoint) -> Void

    private let pokGreen = Color(hex: 0x43A047)

    private var completedCount: Int { goals.filter(\.isCompleted).count }

    private var dateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: .now)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date + progress header
            todayHeader
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.bottom, 16)

            if goals.isEmpty {
                emptyState
            } else {
                // Goal cards
                VStack(spacing: 10) {
                    ForEach(goals, id: \.id) { goal in
                        goalCard(for: goal)
                    }
                }
                .padding(.horizontal, GoosieTheme.padding)
            }

            // Add goal button
            addGoalButton
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 12)
        }
    }

    // MARK: - Today Header

    private var todayHeader: some View {
        VStack(spacing: 12) {
            Text(dateString)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            // Progress bar
            VStack(spacing: 6) {
                HStack {
                    Text("Today's Progress")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text("\(completedCount) / \(goals.count)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.25))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: geo.size.width * (goals.isEmpty ? 0 : Double(completedCount) / Double(goals.count)), height: 8)
                            .animation(.easeOut(duration: 0.3), value: completedCount)
                    }
                }
                .frame(height: 8)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white.opacity(0.15))
            )
        }
    }

    // MARK: - Goal Card Dispatcher

    @ViewBuilder
    private func goalCard(for goal: Goal) -> some View {
        if goal.type == "deadline" {
            DeadlineGoalCardView(
                goal: goal,
                onIncrement: {
                    if let state = gooseState {
                        viewModel.incrementDeadlinePercentage(goal, gooseState: state, log: onEnsureTodayLog(), goals: goals)
                    }
                },
                onSetPercentage: { value in
                    if let state = gooseState {
                        viewModel.setDeadlinePercentage(goal, gooseState: state, log: onEnsureTodayLog(), goals: goals, to: value)
                    }
                },
                onCelebration: onConfetti,
                onEdit: { viewModel.startEditing(goal) },
                onDelete: { viewModel.deleteGoal(goal, in: goal.modelContext!) }
            )
        } else if goal.isHealthKitTracked {
            HealthKitGoalCardView(
                goal: goal,
                progress: hkProgress(for: goal),
                valueLabel: hkLabel(for: goal),
                onEdit: { viewModel.startEditing(goal) },
                onDelete: { viewModel.deleteGoal(goal, in: goal.modelContext!) }
            )
        } else {
            GoalCardView(
                goal: goal,
                onComplete: {
                    if let state = gooseState {
                        viewModel.completeGoal(goal, gooseState: state, log: onEnsureTodayLog(), goals: goals)
                    }
                },
                onUncomplete: {
                    if let state = gooseState {
                        viewModel.uncompleteGoal(goal, gooseState: state, log: todayLog, goals: goals)
                    }
                },
                onIncrement: {
                    if let state = gooseState {
                        viewModel.incrementGoal(goal, gooseState: state, log: todayLog, goals: goals)
                    }
                },
                onEdit: { viewModel.startEditing(goal) },
                onDelete: { viewModel.deleteGoal(goal, in: goal.modelContext!) }
            )
        }
    }

    // MARK: - HealthKit Helpers

    private func hkProgress(for goal: Goal) -> Double {
        let engine = GooseEngine.shared
        if goal.title.localizedCaseInsensitiveContains("steps") || goal.title.localizedCaseInsensitiveContains("walk") {
            return min(Double(engine.cachedSteps) / Double(goal.targetCount), 1.0)
        } else if goal.title.localizedCaseInsensitiveContains("screen time") {
            return min(Double(engine.cachedDistractMinutes) / Double(goal.targetCount), 1.0)
        } else if goal.title.localizedCaseInsensitiveContains("exercise") {
            return min(Double(engine.cachedExerciseMinutes) / Double(goal.targetCount), 1.0)
        } else if goal.title.localizedCaseInsensitiveContains("outside") || goal.title.localizedCaseInsensitiveContains("daylight") {
            return min(Double(engine.cachedOutsideMinutes) / Double(goal.targetCount), 1.0)
        } else {
            return min(engine.cachedSleepHours / Double(goal.targetCount), 1.0)
        }
    }

    private func hkLabel(for goal: Goal) -> String {
        let engine = GooseEngine.shared
        if goal.title.localizedCaseInsensitiveContains("steps") || goal.title.localizedCaseInsensitiveContains("walk") {
            return "\(engine.cachedSteps.formatted()) / \(goal.targetCount.formatted()) steps"
        } else if goal.title.localizedCaseInsensitiveContains("screen time") {
            return "\(engine.cachedDistractMinutes) / \(goal.targetCount) mins used"
        } else if goal.title.localizedCaseInsensitiveContains("exercise") {
            return "\(engine.cachedExerciseMinutes) / \(goal.targetCount) mins"
        } else if goal.title.localizedCaseInsensitiveContains("outside") || goal.title.localizedCaseInsensitiveContains("daylight") {
            return "\(engine.cachedOutsideMinutes) / \(goal.targetCount) mins"
        } else {
            return String(format: "%.1f / %d hrs", engine.cachedSleepHours, goal.targetCount)
        }
    }

    // MARK: - Supporting Views

    private var addGoalButton: some View {
        Button {
            viewModel.startCreating()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Add Goal")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(pokGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))

            Text("No goals yet!")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.top, 40)
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Goals/TodayGoalsTab.swift
git commit -m "feat: add TodayGoalsTab with date header and progress summary"
```

---

### Task 5: Create HabitsGoalsTab

**Files:**
- Create: `TamaGoosie/Features/Goals/HabitsGoalsTab.swift`

This tab shows stats (longest streak, this week %), habit cards with weekly heat maps, and a "+ New habit" button.

- [ ] **Step 1: Create HabitsGoalsTab.swift**

```swift
import SwiftUI

struct HabitsGoalsTab: View {
    let habits: [Goal]  // recurring + builtin goals only
    let viewModel: GoalViewModel

    private let pokGreen = Color(hex: 0x43A047)

    private var longestStreak: Int {
        habits.map(\.currentStreak).max() ?? 0
    }

    private var thisWeekPercent: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today) else { return 0 }

        // Days elapsed this week (including today)
        let daysElapsed = daysFromMonday + 1
        let totalSlots = daysElapsed * max(habits.count, 1)

        var completedSlots = 0
        for habit in habits {
            for dayOffset in 0..<daysElapsed {
                if let date = cal.date(byAdding: .day, value: dayOffset, to: monday) {
                    if habit.completionDates.contains(where: { cal.isDate($0, inSameDayAs: date) }) {
                        completedSlots += 1
                    }
                }
            }
        }

        guard totalSlots > 0 else { return 0 }
        return Int(Double(completedSlots) / Double(totalSlots) * 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Subtitle
            Text("\(habits.count) active \u{00B7} longest streak \(longestStreak) days")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 12)

            // Stats row
            statsRow
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.bottom, 16)

            if habits.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(habits, id: \.id) { habit in
                        habitCard(for: habit)
                    }
                }
                .padding(.horizontal, GoosieTheme.padding)
            }

            // + New habit button
            newHabitButton
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 12)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(longestStreak)", label: "longest streak")
            statCard(value: "\(thisWeekPercent)%", label: "this week")
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(pokGreen)

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
    }

    // MARK: - Habit Card

    private func habitCard(for habit: Goal) -> some View {
        let categoryColor = Color(hex: UInt(habit.colorHex, radix: 16) ?? 0xFFD93D)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Category icon
                Image(systemName: habit.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(categoryColor)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(habit.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.75))

                        if habit.targetCount > 1 {
                            Text("\(habit.targetCount)x")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(pokGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(pokGreen.opacity(0.12))
                                )
                        }
                    }

                    Text(habit.goalFrequency.displayName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.black.opacity(0.4))
                }

                Spacer()

                // Streak flame
                if habit.currentStreak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: 0xFF6D00))
                        Text("\(habit.currentStreak)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black.opacity(0.6))
                    }
                }

                // Kebab menu
                Menu {
                    Button { viewModel.startEditing(habit) } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    if habit.type != "builtin" {
                        Button(role: .destructive) {
                            if let ctx = habit.modelContext {
                                viewModel.deleteGoal(habit, in: ctx)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
            }

            // Weekly heat map
            WeeklyHeatMap(completionDates: habit.completionDates)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
        )
    }

    // MARK: - Supporting Views

    private var newHabitButton: some View {
        Button {
            viewModel.startCreating()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("New habit")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(pokGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(pokGreen.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "repeat")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.4))
            Text("No habits yet")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 40)
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Goals/HabitsGoalsTab.swift
git commit -m "feat: add HabitsGoalsTab with stats row and weekly heat maps"
```

---

### Task 6: Create QuestsGoalsTab

**Files:**
- Create: `TamaGoosie/Features/Goals/QuestsGoalsTab.swift`

- [ ] **Step 1: Create QuestsGoalsTab.swift**

```swift
import SwiftUI

struct QuestsGoalsTab: View {
    let quests: [Goal]  // deadline goals only
    let gooseState: GooseState?
    let viewModel: GoalViewModel
    let onEnsureTodayLog: () -> DailyLog
    let onConfetti: (CGPoint) -> Void

    private let pokGreen = Color(hex: 0x43A047)

    var body: some View {
        VStack(spacing: 0) {
            if quests.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(quests, id: \.id) { quest in
                        DeadlineGoalCardView(
                            goal: quest,
                            onIncrement: {
                                if let state = gooseState {
                                    viewModel.incrementDeadlinePercentage(quest, gooseState: state, log: onEnsureTodayLog(), goals: quests)
                                }
                            },
                            onSetPercentage: { value in
                                if let state = gooseState {
                                    viewModel.setDeadlinePercentage(quest, gooseState: state, log: onEnsureTodayLog(), goals: quests, to: value)
                                }
                            },
                            onCelebration: onConfetti,
                            onEdit: { viewModel.startEditing(quest) },
                            onDelete: {
                                if let ctx = quest.modelContext {
                                    viewModel.deleteGoal(quest, in: ctx)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, GoosieTheme.padding)
            }

            // + New quest button
            newQuestButton
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 12)
        }
    }

    private var newQuestButton: some View {
        Button {
            viewModel.startCreating()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("New quest")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(pokGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(pokGreen.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.4))
            Text("No quests yet")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Text("Quests are one-time goals with deadlines")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.top, 40)
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Goals/QuestsGoalsTab.swift
git commit -m "feat: add QuestsGoalsTab with deadline cards"
```

---

### Task 7: Refactor GoalListView as tab container

**Files:**
- Modify: `TamaGoosie/Features/Goals/GoalListView.swift`

This is the big task. Replace the body of GoalListView with a tab-based container. Keep all @Query, shared logic, sheets, confetti, and onChange handlers. Remove the old section headers and inline card rendering — those are now in the tab views. Keep the card view structs (GoalCardView, DeadlineGoalCardView, HealthKitGoalCardView, ConfettiView, ConfettiParticle) at the bottom of this file.

- [ ] **Step 1: Rewrite GoalListView body and remove old helpers**

Replace the `body`, `goalCard(for:)`, `goalSectionHeader(...)`, and `emptyState` computed properties. Keep: all stored properties, `@State` vars, computed helpers for goals/builtInGoals/userGoals/todayLog, `ensureTodayLogExists()`, `snapshotYesterdayIfNeeded()`, the `hkProgress` and `hkLabel` functions. Actually, hkProgress/hkLabel are now in TodayGoalsTab, so remove them from here.

The new GoalListView body should be:

```swift
var body: some View {
    ZStack {
        GrassyBackgroundView()

        ScrollView {
            VStack(spacing: 16) {
                // Tab picker
                GoalTabPicker(selected: $selectedGoalTab)

                // Tab content
                switch selectedGoalTab {
                case .today:
                    TodayGoalsTab(
                        goals: goals,
                        gooseState: gooseState,
                        todayLog: todayLog,
                        viewModel: viewModel,
                        onEnsureTodayLog: { ensureTodayLogExists() },
                        onConfetti: { origin in spawnConfetti(at: origin) }
                    )
                case .habits:
                    HabitsGoalsTab(
                        habits: habits,
                        viewModel: viewModel
                    )
                case .quests:
                    QuestsGoalsTab(
                        quests: quests,
                        gooseState: gooseState,
                        viewModel: viewModel,
                        onEnsureTodayLog: { ensureTodayLogExists() },
                        onConfetti: { origin in spawnConfetti(at: origin) }
                    )
                }
            }
            .padding(.top, 52)
            .padding(.bottom, 20)
            .trackScrollOffset()
        }

        // Full-screen confetti bursts
        ForEach(confettiBursts) { burst in
            ConfettiView(origin: burst.origin)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
    .sheet(isPresented: $viewModel.showEditor) {
        GoalEditorView(existingGoal: viewModel.editingGoal)
    }
    .onAppear {
        viewModel.seedBuiltinGoalsIfNeeded(in: modelContext, isWatchPaired: isWatchPaired)
        snapshotYesterdayIfNeeded()
        viewModel.resetDailyGoals(goals)
        ensureTodayLogExists()
        GooseEngine.shared.refreshGoals(goals)
        if profiles.first?.hasPickedInitialGoals == false {
            showInitialGoalPicker = true
        }
    }
    .sheet(isPresented: $showInitialGoalPicker) {
        InitialGoalPickerSheet()
    }
    .onChange(of: goals) { _, newGoals in
        GooseEngine.shared.refreshGoals(newGoals)
    }
    .onChange(of: GooseEngine.shared.cachedSteps) { _, steps in
        if let state = gooseState {
            viewModel.autoCompleteHealthKitGoals(
                goals: goals, steps: steps,
                sleepHours: GooseEngine.shared.cachedSleepHours,
                state: state
            )
        }
    }
    .onChange(of: GooseEngine.shared.cachedSleepHours) { _, hours in
        if let state = gooseState {
            viewModel.autoCompleteHealthKitGoals(
                goals: goals, steps: GooseEngine.shared.cachedSteps,
                sleepHours: hours, state: state
            )
        }
    }
    .onChange(of: GooseEngine.shared.cachedExerciseMinutes) { _, _ in
        if let state = gooseState {
            viewModel.autoCompleteHealthKitGoals(
                goals: goals, steps: GooseEngine.shared.cachedSteps,
                sleepHours: GooseEngine.shared.cachedSleepHours,
                state: state
            )
        }
    }
    .onChange(of: GooseEngine.shared.cachedOutsideMinutes) { _, _ in
        if let state = gooseState {
            viewModel.autoCompleteHealthKitGoals(
                goals: goals, steps: GooseEngine.shared.cachedSteps,
                sleepHours: GooseEngine.shared.cachedSleepHours,
                state: state
            )
        }
    }
    .onChange(of: GooseEngine.shared.cachedDistractMinutes) { _, _ in }
}
```

Add these new properties/computed vars:

```swift
@State private var selectedGoalTab: GoalTab = .today

// Filtered goal lists for each tab
private var habits: [Goal] {
    goals.filter { $0.type == "recurring" || $0.type == "builtin" }
}

private var quests: [Goal] {
    goals.filter { $0.type == "deadline" }
}
```

Add this confetti helper:

```swift
private func spawnConfetti(at origin: CGPoint) {
    let burst = ConfettiBurst(origin: origin)
    confettiBursts.append(burst)
    Task {
        try? await Task.sleep(for: .seconds(2.5))
        await MainActor.run {
            confettiBursts.removeAll { $0.id == burst.id }
        }
    }
}
```

Remove these now-unused properties and functions:
- `healthGoalsExpanded`, `myGoalsExpanded` @State vars
- `hkProgress(for:)` function
- `hkLabel(for:)` function
- `goalCard(for:)` function
- `goalSectionHeader(...)` function
- `emptyState` computed property
- `builtInGoals` and `userGoals` computed properties (replaced by `habits` and `quests`)

Keep these card view structs at the bottom of the file unchanged:
- `GoalCardView`
- `DeadlineGoalCardView`
- `HealthKitGoalCardView`
- `ConfettiBurst`
- `ConfettiView`
- `ConfettiParticle`

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Fix any compilation errors**

Common issues to check:
- `ConfettiBurst` must be visible to GoalListView (it's `private struct` — change to `struct` since it's used in the `onConfetti` closure type)
- Card views reference `GoosieTheme.padding` — ensure they're still accessible
- `goal.modelContext` may be nil for newly inserted goals — the tab views use `goal.modelContext!` which could crash. Consider passing `modelContext` from the container instead.

If `goal.modelContext` causes issues, add `let modelContext: ModelContext` as a parameter to the tab views and use that for delete operations.

- [ ] **Step 4: Commit**

```bash
git add TamaGoosie/Features/Goals/GoalListView.swift
git commit -m "refactor: convert GoalListView to tabbed container (Today/Habits/Quests)"
```

---

### Task 8: Final polish and build verification

**Files:**
- Possibly modify: any files from above tasks that need adjustments

- [ ] **Step 1: Full build verification**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Verify XcodeGen regeneration if needed**

If new files aren't being picked up by the build, regenerate:
```bash
cd /Users/PriscillaYe/Documents/GitHub/TamaGoosie && xcodegen generate
```
Then rebuild.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: goals page redesign with Today/Habits/Quests tabs"
```
