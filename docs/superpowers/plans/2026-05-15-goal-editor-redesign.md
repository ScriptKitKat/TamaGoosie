# Goal Editor Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the form-heavy GoalEditorView with a guided 2-step creation flow and a single-page edit view.

**Architecture:** GoalEditorView becomes a thin router that dispatches to GoalCreateFlowView (2-step), GoalEditFormView (single-page edit), or the existing builtinThresholdEditor. Two helper functions (suggestCategory, targetUnit) provide smart defaults. Two bottom sheets (GoalCategorySheet, GoalFrequencySheet) are shared between create and edit flows.

**Tech Stack:** SwiftUI, SwiftData, iOS 26+

---

### Task 1: Smart Category Suggestion & Target Unit Helpers

Add two pure helper functions used by both the create flow and edit form.

**Files:**
- Create: `TamaGoosie/Features/Goals/GoalEditorHelpers.swift`

- [ ] **Step 1: Create GoalEditorHelpers.swift with suggestCategory and targetUnit**

```swift
import Foundation

/// Maps title keywords to a GoalCategory.
func suggestCategory(from title: String) -> GoalCategory {
    let t = title.lowercased()
    let mapping: [(keywords: [String], category: GoalCategory)] = [
        (["water", "drink", "glass", "hydra"], .water),
        (["exercise", "run", "walk", "gym", "workout", "jog"], .exercise),
        (["study", "homework", "learn", "class"], .study),
        (["screen", "phone", "social media", "app", "tiktok", "instagram"], .screentime),
        (["sleep", "bed", "rest", "wake"], .health),
        (["read", "book", "chapter", "page"], .learning),
        (["meditate", "breathe", "journal", "mindful", "yoga"], .mindfulness),
        (["friend", "call", "family", "social"], .social),
        (["focus", "productive", "deep work", "task"], .productivity),
        (["stretch", "lift", "weight", "pushup", "plank"], .fitness),
    ]
    for entry in mapping {
        if entry.keywords.contains(where: { t.contains($0) }) {
            return entry.category
        }
    }
    return .custom
}

/// Returns context-aware target metadata for a category.
struct TargetUnitInfo {
    let label: String
    let defaultValue: Int
    let range: ClosedRange<Int>
    let step: Int
}

func targetUnit(for category: GoalCategory) -> TargetUnitInfo {
    switch category {
    case .water:        TargetUnitInfo(label: "glasses", defaultValue: 8, range: 1...20, step: 1)
    case .exercise:     TargetUnitInfo(label: "minutes", defaultValue: 30, range: 5...180, step: 5)
    case .fitness:      TargetUnitInfo(label: "minutes", defaultValue: 30, range: 5...180, step: 5)
    case .screentime:   TargetUnitInfo(label: "minutes", defaultValue: 120, range: 15...480, step: 15)
    case .study:        TargetUnitInfo(label: "minutes", defaultValue: 60, range: 10...300, step: 10)
    case .health:       TargetUnitInfo(label: "hours", defaultValue: 8, range: 4...12, step: 1)
    case .learning:     TargetUnitInfo(label: "minutes", defaultValue: 30, range: 10...180, step: 10)
    case .mindfulness:  TargetUnitInfo(label: "minutes", defaultValue: 15, range: 5...60, step: 5)
    case .productivity: TargetUnitInfo(label: "tasks", defaultValue: 3, range: 1...20, step: 1)
    case .social:       TargetUnitInfo(label: "times", defaultValue: 1, range: 1...10, step: 1)
    case .custom:       TargetUnitInfo(label: "times", defaultValue: 1, range: 1...99, step: 1)
    }
}
```

- [ ] **Step 2: Verify the file builds**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```

If XcodeGen is needed (file not picked up), run `xcodegen generate` first.

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Goals/GoalEditorHelpers.swift
git commit -m "feat: add suggestCategory and targetUnit helpers for goal editor redesign"
```

---

### Task 2: GoalCategorySheet

A bottom sheet presenting the full category grid picker, reusable by both create and edit flows.

**Files:**
- Create: `TamaGoosie/Features/Goals/GoalCategorySheet.swift`

- [ ] **Step 1: Create GoalCategorySheet.swift**

```swift
import SwiftUI

struct GoalCategorySheet: View {
    @Binding var selectedCategory: GoalCategory
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose a category")
                        .font(GoosieTheme.bodyFont())
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                        .padding(.horizontal, GoosieTheme.padding)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(GoalCategory.allCases, id: \.self) { cat in
                            categoryCell(cat)
                        }
                    }
                    .padding(.horizontal, GoosieTheme.padding)
                }
                .padding(.top, 16)
            }
            .background(GoosieTheme.mintBackground.ignoresSafeArea())
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .preferredColorScheme(.light)
        }
        .presentationDetents([.medium])
    }

    private func categoryCell(_ cat: GoalCategory) -> some View {
        let isSelected = selectedCategory == cat
        let chipColor = Color(hex: UInt(cat.color, radix: 16) ?? 0xFFD93D)

        return Button {
            selectedCategory = cat
        } label: {
            VStack(spacing: 4) {
                Image(systemName: cat.icon)
                    .font(.system(size: 20))
                Text(cat.displayName)
                    .font(GoosieTheme.captionFont(10))
            }
            .foregroundStyle(isSelected ? .white : GoosieTheme.charcoalOutline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? chipColor : chipColor.opacity(0.15))
            )
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run:
```bash
xcodegen generate && xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Goals/GoalCategorySheet.swift
git commit -m "feat: add GoalCategorySheet bottom sheet"
```

---

### Task 3: GoalFrequencySheet

A bottom sheet with frequency options and custom weekday picker.

**Files:**
- Create: `TamaGoosie/Features/Goals/GoalFrequencySheet.swift`

- [ ] **Step 1: Create GoalFrequencySheet.swift**

```swift
import SwiftUI

struct GoalFrequencySheet: View {
    @Binding var frequency: GoalFrequency
    @Binding var customDays: Set<Int>
    @Environment(\.dismiss) private var dismiss

    private let weekdayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(GoalFrequency.allCases, id: \.self) { freq in
                    frequencyRow(freq)
                }

                if frequency == .custom {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select days")
                            .font(GoosieTheme.captionFont(11))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

                        HStack(spacing: 6) {
                            ForEach(0..<7, id: \.self) { index in
                                let weekday = index + 1
                                let isSelected = customDays.contains(weekday)
                                Button {
                                    if isSelected {
                                        customDays.remove(weekday)
                                    } else {
                                        customDays.insert(weekday)
                                    }
                                } label: {
                                    Text(weekdayLabels[index])
                                        .font(GoosieTheme.captionFont(12))
                                        .foregroundStyle(isSelected ? .white : GoosieTheme.charcoalOutline)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(isSelected ? Color(hex: 0x43A047) : Color(hex: 0x43A047).opacity(0.12))
                                        )
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()
            }
            .padding(GoosieTheme.padding)
            .animation(.easeInOut(duration: 0.2), value: frequency)
            .background(GoosieTheme.mintBackground.ignoresSafeArea())
            .navigationTitle("Frequency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .preferredColorScheme(.light)
        }
        .presentationDetents([.medium])
    }

    private func frequencyRow(_ freq: GoalFrequency) -> some View {
        let isSelected = frequency == freq
        return Button {
            frequency = freq
        } label: {
            HStack {
                Text(freq.displayName)
                    .font(GoosieTheme.bodyFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: 0x43A047))
                }
            }
            .padding(.vertical, 8)
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run:
```bash
xcodegen generate && xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Goals/GoalFrequencySheet.swift
git commit -m "feat: add GoalFrequencySheet bottom sheet"
```

---

### Task 4: GoalCreateFlowView (2-Step Create)

The guided 2-step creation flow: Step 1 (title + quick suggestions) and Step 2 (customize fields + preview + CTA).

**Files:**
- Create: `TamaGoosie/Features/Goals/GoalCreateFlowView.swift`

- [ ] **Step 1: Create GoalCreateFlowView.swift**

```swift
import SwiftUI
import SwiftData

struct GoalCreateFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var prefill: GoalDraft?

    @State private var step = 1
    @State private var title: String
    @State private var goalType: String = "recurring"
    @State private var category: GoalCategory
    @State private var frequency: GoalFrequency = .daily
    @State private var customDays: Set<Int> = []
    @State private var targetCount: Int
    @State private var happinessWeight: Double = 1.0
    @State private var dueDate: Date = Date()
    @State private var enableReminder: Bool = false
    @State private var preferredTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var notificationPermissionDenied = false
    @State private var showCategorySheet = false
    @State private var showFrequencySheet = false
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    private let greenAccent = Color(hex: 0x43A047)

    init(prefill: GoalDraft? = nil) {
        self.prefill = prefill
        _title = State(initialValue: prefill?.title ?? "")
        let cat = prefill?.category ?? .custom
        _category = State(initialValue: cat)
        _targetCount = State(initialValue: prefill?.targetCount ?? targetUnit(for: cat).defaultValue)
        if let p = prefill {
            _goalType = State(initialValue: p.goalType)
            _frequency = State(initialValue: p.frequency)
            _customDays = State(initialValue: p.customDays)
            _happinessWeight = State(initialValue: p.happinessWeight)
            _dueDate = State(initialValue: p.dueDate)
            _enableReminder = State(initialValue: p.enableReminder)
            _preferredTime = State(initialValue: p.preferredTime)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                GoosieTheme.mintBackground.ignoresSafeArea()

                ScrollView {
                    if step == 1 {
                        step1View
                    } else {
                        step2View
                    }
                }

                if let message = toastMessage {
                    Text(message)
                        .font(GoosieTheme.captionFont(13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(GoosieTheme.charcoalOutline.opacity(0.85)))
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(message)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: toastMessage)
            .navigationTitle(step == 1 ? "New Goal" : "Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showCategorySheet) {
                GoalCategorySheet(selectedCategory: $category)
            }
            .sheet(isPresented: $showFrequencySheet) {
                GoalFrequencySheet(frequency: $frequency, customDays: $customDays)
            }
            .onChange(of: category) { _, newCat in
                let info = targetUnit(for: newCat)
                targetCount = info.defaultValue
            }
            .preferredColorScheme(.light)
        }
    }

    // MARK: - Step 1

    private var step1View: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What do you want to do?")
                    .font(GoosieTheme.titleFont(28))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                TextField("e.g., Drink 8 glasses of water", text: $title, axis: .vertical)
                    .font(GoosieTheme.bodyFont(20))
                    .textFieldStyle(.plain)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    )
            }

            // Auto-category suggestion pill
            if !title.isEmpty {
                let suggested = suggestCategory(from: title)
                if suggested != .custom {
                    HStack(spacing: 6) {
                        Image(systemName: suggested.icon)
                            .font(.system(size: 12))
                        Text(suggested.displayName)
                            .font(GoosieTheme.captionFont(12))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(greenAccent))
                    .transition(.opacity)
                }
            }

            // Quick suggestions
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick suggestions")
                    .font(GoosieTheme.captionFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                let suggestions: [(label: String, cat: GoalCategory, target: Int)] = [
                    ("Drink water", .water, 8),
                    ("Exercise", .exercise, 30),
                    ("Study", .study, 60),
                    ("Sleep earlier", .health, 8),
                    ("Read", .learning, 30),
                    ("Less screen time", .screentime, 120),
                ]

                FlowLayout(spacing: 8) {
                    ForEach(suggestions, id: \.label) { s in
                        Button {
                            title = s.label
                            category = s.cat
                            targetCount = s.target
                        } label: {
                            Text(s.label)
                                .font(GoosieTheme.captionFont(13))
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(.white)
                                        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                                )
                        }
                    }
                }
            }

            Spacer(minLength: 80)

            // Continue CTA
            Button {
                let suggested = suggestCategory(from: title)
                if category == .custom && suggested != .custom {
                    category = suggested
                    targetCount = targetUnit(for: suggested).defaultValue
                }
                withAnimation(.easeInOut(duration: 0.3)) { step = 2 }
            } label: {
                Text("Continue")
                    .font(GoosieTheme.bodyFont())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(title.trimmingCharacters(in: .whitespaces).isEmpty ? greenAccent.opacity(0.4) : greenAccent))
            }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(GoosieTheme.padding)
        .animation(.easeInOut(duration: 0.2), value: title)
    }

    // MARK: - Step 2

    private var step2View: some View {
        let info = targetUnit(for: category)

        return VStack(spacing: 16) {
            // Title (tappable to go back)
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { step = 1 }
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text(title)
                        .font(GoosieTheme.titleFont(20))
                    Spacer()
                }
                .foregroundStyle(GoosieTheme.charcoalOutline)
            }

            // Category pill with Change button
            GoosieCard {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: category.icon)
                            .font(.system(size: 14))
                        Text(category.displayName)
                            .font(GoosieTheme.captionFont(13))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(greenAccent))

                    Spacer()

                    Button("Change") { showCategorySheet = true }
                        .font(GoosieTheme.captionFont(13))
                        .foregroundStyle(greenAccent)
                }
            }

            // Goal style: Build a habit | Reach a deadline
            GoosieCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal style")
                        .font(GoosieTheme.captionFont())
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                    HStack(spacing: 8) {
                        styleChip("Build a habit", type: "recurring")
                        styleChip("Reach a deadline", type: "deadline")
                    }
                }
            }

            // Repeat row (habit only)
            if goalType == "recurring" {
                GoosieCard {
                    Button { showFrequencySheet = true } label: {
                        HStack {
                            Text("Repeat")
                                .font(GoosieTheme.captionFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                            Spacer()
                            Text(frequencyDisplayLabel)
                                .font(GoosieTheme.bodyFont(14))
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                        }
                    }
                }
            }

            // Daily target stepper
            if goalType == "recurring" {
                GoosieCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Target")
                            .font(GoosieTheme.captionFont())
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                        Stepper(value: $targetCount, in: info.range, step: info.step) {
                            Text("\(targetCount) \(info.label)")
                                .font(GoosieTheme.bodyFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                        }
                    }
                }
            }

            // Due date (deadline only)
            if goalType == "deadline" {
                GoosieCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Due Date")
                            .font(GoosieTheme.captionFont())
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                            .font(GoosieTheme.captionFont())
                    }
                }
            }

            // Reminder toggle
            GoosieCard {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $enableReminder.animation()) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reminder")
                                .font(GoosieTheme.captionFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                        }
                    }
                    .tint(greenAccent)

                    if enableReminder {
                        DatePicker("Time", selection: $preferredTime, displayedComponents: .hourAndMinute)
                            .font(GoosieTheme.captionFont())
                    }
                }
            }
            .onChange(of: enableReminder) { _, newValue in
                if newValue { requestNotificationPermission() }
            }

            // Advanced: importance
            DisclosureGroup {
                Slider(value: $happinessWeight, in: 0.5...2.0, step: 0.5)
                    .tint(greenAccent)
                HStack {
                    Text("Importance")
                        .font(GoosieTheme.captionFont(12))
                    Spacer()
                    Text(String(format: "%.1fx", happinessWeight))
                        .font(GoosieTheme.captionFont(12))
                }
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
            } label: {
                Text("Advanced")
                    .font(GoosieTheme.captionFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
            }
            .padding(.horizontal, GoosieTheme.cardPadding)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            )

            // Preview card
            previewCard

            // Microcopy
            Text("You can always edit this later.")
                .font(GoosieTheme.captionFont(12))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))

            // Create Goal CTA
            Button { save() } label: {
                Text("Create Goal")
                    .font(GoosieTheme.bodyFont())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(greenAccent))
            }
            .padding(.bottom, 16)
        }
        .padding(GoosieTheme.padding)
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        let info = targetUnit(for: category)
        return HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 24))
                .foregroundStyle(greenAccent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(greenAccent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(GoosieTheme.bodyFont(14))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                    .lineLimit(1)
                if goalType == "recurring" {
                    Text("\(frequency.displayName) \u{2022} \(targetCount) \(info.label)")
                        .font(GoosieTheme.captionFont(12))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                } else {
                    Text("Deadline")
                        .font(GoosieTheme.captionFont(12))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                }
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: 0xE8F5E9))
        )
    }

    // MARK: - Helpers

    private func styleChip(_ label: String, type: String) -> some View {
        let isSelected = goalType == type
        return Button { goalType = type } label: {
            Text(label)
                .font(GoosieTheme.captionFont(12))
                .foregroundStyle(isSelected ? .white : GoosieTheme.charcoalOutline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? greenAccent : greenAccent.opacity(0.12))
                )
        }
    }

    private var frequencyDisplayLabel: String {
        switch frequency {
        case .daily: "Every day"
        case .weekdays: "Weekdays"
        case .weekends: "Weekends"
        case .weekly: "Weekly"
        case .custom:
            customDays.isEmpty ? "Custom" : customDays.sorted().map { dayName($0) }.joined(separator: ", ")
        }
    }

    private func dayName(_ weekday: Int) -> String {
        let labels = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return weekday >= 1 && weekday <= 7 ? labels[weekday] : ""
    }

    private func requestNotificationPermission() {
        Task {
            do {
                let granted = try await GooseNotificationSystem.shared.requestAuthorization()
                await MainActor.run { notificationPermissionDenied = !granted }
            } catch {
                await MainActor.run { notificationPermissionDenied = true }
            }
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            await MainActor.run { toastMessage = nil }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            showToast("Please enter a goal title")
            return
        }
        if goalType == "recurring", frequency == .custom, customDays.isEmpty {
            showToast("Please select at least one day")
            return
        }

        let goal = Goal(
            title: trimmedTitle,
            type: goalType,
            category: category,
            frequency: frequency,
            targetCount: targetCount,
            happinessWeight: happinessWeight
        )
        goal.dueDate = goalType == "deadline" ? dueDate : nil
        goal.preferredTime = enableReminder ? preferredTime : nil
        goal.customDaysSet = customDays
        modelContext.insert(goal)

        if goal.preferredTime == nil {
            GooseNotificationSystem.shared.cancelPushes(for: goal.id)
        }

        try? modelContext.save()
        syncAllGoalsToConvex()
        dismiss()
    }

    private func syncAllGoalsToConvex() {
        let descriptor = FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.sortOrder)])
        guard let allGoals = try? modelContext.fetch(descriptor) else { return }
        let activeGoals = allGoals.filter { $0.isActive }
        ConvexManager.shared.syncGoals(goals: activeGoals)
    }
}

// MARK: - FlowLayout (chip wrapping)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight + (i > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(subview)
            currentWidth += size.width + spacing
        }
        return rows
    }
}
```

- [ ] **Step 2: Verify build**

Run:
```bash
xcodegen generate && xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Goals/GoalCreateFlowView.swift
git commit -m "feat: add GoalCreateFlowView with 2-step guided creation"
```

---

### Task 5: GoalEditFormView (Single-Page Edit)

All fields visible and pre-filled on one page. Same layout as Step 2 but with "Save" CTA.

**Files:**
- Create: `TamaGoosie/Features/Goals/GoalEditFormView.swift`

- [ ] **Step 1: Create GoalEditFormView.swift**

```swift
import SwiftUI
import SwiftData

struct GoalEditFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let goal: Goal

    @State private var title: String
    @State private var goalType: String
    @State private var category: GoalCategory
    @State private var frequency: GoalFrequency
    @State private var customDays: Set<Int>
    @State private var targetCount: Int
    @State private var happinessWeight: Double
    @State private var dueDate: Date
    @State private var enableReminder: Bool
    @State private var preferredTime: Date
    @State private var notificationPermissionDenied = false
    @State private var showCategorySheet = false
    @State private var showFrequencySheet = false
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    private let greenAccent = Color(hex: 0x43A047)

    init(goal: Goal) {
        self.goal = goal
        let defaultTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
        _title = State(initialValue: goal.title)
        _goalType = State(initialValue: goal.type)
        _category = State(initialValue: goal.goalCategory)
        _frequency = State(initialValue: goal.goalFrequency)
        _customDays = State(initialValue: goal.customDaysSet)
        _targetCount = State(initialValue: goal.targetCount)
        _happinessWeight = State(initialValue: goal.happinessWeight)
        _dueDate = State(initialValue: goal.dueDate ?? Date())
        _enableReminder = State(initialValue: goal.preferredTime != nil)
        _preferredTime = State(initialValue: goal.preferredTime ?? defaultTime)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                GoosieTheme.mintBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Title
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Goal Title")
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                                TextField("Goal title", text: $title)
                                    .font(GoosieTheme.bodyFont())
                                    .textFieldStyle(.plain)
                            }
                        }

                        // Category
                        GoosieCard {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 14))
                                    Text(category.displayName)
                                        .font(GoosieTheme.captionFont(13))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(greenAccent))

                                Spacer()

                                Button("Change") { showCategorySheet = true }
                                    .font(GoosieTheme.captionFont(13))
                                    .foregroundStyle(greenAccent)
                            }
                        }

                        // Goal style
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Goal style")
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                                HStack(spacing: 8) {
                                    styleChip("Build a habit", type: "recurring")
                                    styleChip("Reach a deadline", type: "deadline")
                                }
                            }
                        }

                        // Frequency (habit only)
                        if goalType == "recurring" {
                            GoosieCard {
                                Button { showFrequencySheet = true } label: {
                                    HStack {
                                        Text("Repeat")
                                            .font(GoosieTheme.captionFont())
                                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                                        Spacer()
                                        Text(frequencyDisplayLabel)
                                            .font(GoosieTheme.bodyFont(14))
                                            .foregroundStyle(GoosieTheme.charcoalOutline)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                                    }
                                }
                            }

                            // Daily target
                            let info = targetUnit(for: category)
                            GoosieCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Daily Target")
                                        .font(GoosieTheme.captionFont())
                                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                                    Stepper(value: $targetCount, in: info.range, step: info.step) {
                                        Text("\(targetCount) \(info.label)")
                                            .font(GoosieTheme.bodyFont())
                                            .foregroundStyle(GoosieTheme.charcoalOutline)
                                    }
                                }
                            }
                        }

                        // Due date (deadline only)
                        if goalType == "deadline" {
                            GoosieCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Due Date")
                                        .font(GoosieTheme.captionFont())
                                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                                        .font(GoosieTheme.captionFont())
                                }
                            }
                        }

                        // Reminder
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle(isOn: $enableReminder.animation()) {
                                    Text("Reminder")
                                        .font(GoosieTheme.captionFont())
                                        .foregroundStyle(GoosieTheme.charcoalOutline)
                                }
                                .tint(greenAccent)

                                if enableReminder {
                                    DatePicker("Time", selection: $preferredTime, displayedComponents: .hourAndMinute)
                                        .font(GoosieTheme.captionFont())
                                }
                            }
                        }
                        .onChange(of: enableReminder) { _, newValue in
                            if newValue { requestNotificationPermission() }
                        }

                        // Importance
                        DisclosureGroup {
                            Slider(value: $happinessWeight, in: 0.5...2.0, step: 0.5)
                                .tint(greenAccent)
                            HStack {
                                Text("Importance")
                                    .font(GoosieTheme.captionFont(12))
                                Spacer()
                                Text(String(format: "%.1fx", happinessWeight))
                                    .font(GoosieTheme.captionFont(12))
                            }
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                        } label: {
                            Text("Advanced")
                                .font(GoosieTheme.captionFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                        }
                        .padding(.horizontal, GoosieTheme.cardPadding)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                        )

                        // Save CTA
                        Button { save() } label: {
                            Text("Save")
                                .font(GoosieTheme.bodyFont())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Capsule().fill(greenAccent))
                        }
                        .padding(.bottom, 16)
                    }
                    .padding(GoosieTheme.padding)
                }

                if let message = toastMessage {
                    Text(message)
                        .font(GoosieTheme.captionFont(13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(GoosieTheme.charcoalOutline.opacity(0.85)))
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(message)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: toastMessage)
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showCategorySheet) {
                GoalCategorySheet(selectedCategory: $category)
            }
            .sheet(isPresented: $showFrequencySheet) {
                GoalFrequencySheet(frequency: $frequency, customDays: $customDays)
            }
            .preferredColorScheme(.light)
        }
    }

    // MARK: - Helpers

    private func styleChip(_ label: String, type: String) -> some View {
        let isSelected = goalType == type
        return Button { goalType = type } label: {
            Text(label)
                .font(GoosieTheme.captionFont(12))
                .foregroundStyle(isSelected ? .white : GoosieTheme.charcoalOutline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? greenAccent : greenAccent.opacity(0.12))
                )
        }
    }

    private var frequencyDisplayLabel: String {
        switch frequency {
        case .daily: "Every day"
        case .weekdays: "Weekdays"
        case .weekends: "Weekends"
        case .weekly: "Weekly"
        case .custom:
            customDays.isEmpty ? "Custom" : customDays.sorted().map { dayName($0) }.joined(separator: ", ")
        }
    }

    private func dayName(_ weekday: Int) -> String {
        let labels = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return weekday >= 1 && weekday <= 7 ? labels[weekday] : ""
    }

    private func requestNotificationPermission() {
        Task {
            do {
                let granted = try await GooseNotificationSystem.shared.requestAuthorization()
                await MainActor.run { notificationPermissionDenied = !granted }
            } catch {
                await MainActor.run { notificationPermissionDenied = true }
            }
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            await MainActor.run { toastMessage = nil }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            showToast("Please enter a goal title")
            return
        }
        if goalType == "recurring", frequency == .custom, customDays.isEmpty {
            showToast("Please select at least one day")
            return
        }

        goal.title = trimmedTitle
        goal.type = goalType
        goal.category = category.rawValue
        goal.frequency = frequency.rawValue
        goal.customDaysSet = customDays
        goal.targetCount = targetCount
        goal.happinessWeight = happinessWeight
        goal.dueDate = goalType == "deadline" ? dueDate : nil
        goal.preferredTime = enableReminder ? preferredTime : nil

        if goal.preferredTime == nil {
            GooseNotificationSystem.shared.cancelPushes(for: goal.id)
        }

        try? modelContext.save()
        syncAllGoalsToConvex()
        dismiss()
    }

    private func syncAllGoalsToConvex() {
        let descriptor = FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.sortOrder)])
        guard let allGoals = try? modelContext.fetch(descriptor) else { return }
        let activeGoals = allGoals.filter { $0.isActive }
        ConvexManager.shared.syncGoals(goals: activeGoals)
    }
}
```

- [ ] **Step 2: Verify build**

Run:
```bash
xcodegen generate && xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Goals/GoalEditFormView.swift
git commit -m "feat: add GoalEditFormView single-page edit"
```

---

### Task 6: Refactor GoalEditorView as Router

Replace the current 556-line GoalEditorView with a thin router that dispatches to the appropriate view. Keep the builtinThresholdEditor inline since it's small.

**Files:**
- Modify: `TamaGoosie/Features/Goals/GoalEditorView.swift` (full rewrite)

- [ ] **Step 1: Rewrite GoalEditorView.swift as a router**

Replace the entire file with:

```swift
import SwiftUI
import SwiftData

struct GoalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingGoal: Goal?
    var prefill: GoalDraft?

    @State private var targetCount: Int

    init(existingGoal: Goal? = nil, prefill: GoalDraft? = nil) {
        self.existingGoal = existingGoal
        self.prefill = prefill
        _targetCount = State(initialValue: existingGoal?.targetCount ?? 1)
    }

    private var isBuiltin: Bool { existingGoal?.type == "builtin" }

    var body: some View {
        if isBuiltin {
            builtinEditor
        } else if let goal = existingGoal {
            GoalEditFormView(goal: goal)
        } else {
            GoalCreateFlowView(prefill: prefill)
        }
    }

    // MARK: - Built-in Threshold Editor (unchanged)

    private var builtinEditor: some View {
        NavigationStack {
            ZStack {
                GoosieTheme.mintBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Goal")
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                                Text(existingGoal?.title ?? "")
                                    .font(GoosieTheme.bodyFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                            }
                        }

                        GoosieCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(builtinEditorLabel)
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                                Stepper(value: $targetCount, in: builtinEditorRange, step: builtinEditorStep) {
                                    Text(builtinEditorValueLabel)
                                        .font(GoosieTheme.bodyFont())
                                        .foregroundStyle(GoosieTheme.charcoalOutline)
                                }
                            }
                        }
                    }
                    .padding(GoosieTheme.padding)
                }
            }
            .navigationTitle("Edit Goal Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveBuiltin() }
                }
            }
            .preferredColorScheme(.light)
        }
    }

    // MARK: - Built-in Helpers

    private enum BuiltinGoalKind {
        case steps, sleep, exercise, outside, screentime
    }

    private var builtinKind: BuiltinGoalKind {
        let t = existingGoal?.title ?? ""
        if t.localizedCaseInsensitiveContains("steps") || t.localizedCaseInsensitiveContains("walk") {
            return .steps
        } else if t.localizedCaseInsensitiveContains("sleep") {
            return .sleep
        } else if t.localizedCaseInsensitiveContains("exercise") {
            return .exercise
        } else if t.localizedCaseInsensitiveContains("outside") || t.localizedCaseInsensitiveContains("daylight") {
            return .outside
        } else {
            return .screentime
        }
    }

    private var builtinEditorLabel: String {
        switch builtinKind {
        case .steps: "Daily step target"
        case .sleep: "Sleep target (hours)"
        case .exercise: "Exercise target (minutes)"
        case .outside: "Outside time target (minutes)"
        case .screentime: "Screen time limit (minutes)"
        }
    }

    private var builtinEditorRange: ClosedRange<Int> {
        switch builtinKind {
        case .steps: 1000...50000
        case .sleep: 4...12
        case .exercise: 10...120
        case .outside: 10...180
        case .screentime: 30...480
        }
    }

    private var builtinEditorStep: Int {
        switch builtinKind {
        case .steps: 500
        case .sleep: 1
        case .exercise: 5
        case .outside: 5
        case .screentime: 15
        }
    }

    private var builtinEditorValueLabel: String {
        switch builtinKind {
        case .steps: "\(targetCount.formatted()) steps"
        case .sleep: "\(targetCount) hours"
        case .exercise: "\(targetCount) minutes"
        case .outside: "\(targetCount) minutes"
        case .screentime: "\(targetCount) minutes"
        }
    }

    private func saveBuiltin() {
        guard let goal = existingGoal else { return }
        goal.targetCount = targetCount
        try? modelContext.save()
        let descriptor = FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.sortOrder)])
        if let allGoals = try? modelContext.fetch(descriptor) {
            let activeGoals = allGoals.filter { $0.isActive }
            ConvexManager.shared.syncGoals(goals: activeGoals)
        }
        dismiss()
    }
}
```

- [ ] **Step 2: Verify build**

Run:
```bash
xcodegen generate && xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Verify GoalListView still presents GoalEditorView correctly**

Check that GoalListView's `.sheet` usage still works. The `existingGoal` and `prefill` parameters are unchanged, so it should work without modification.

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
git add TamaGoosie/Features/Goals/GoalEditorView.swift
git commit -m "refactor: GoalEditorView becomes thin router dispatching to create/edit/builtin views"
```

---

### Task 7: Integration Verification

Build the full project and verify all new files are compiled.

**Files:**
- Verify: All new files in `TamaGoosie/Features/Goals/`

- [ ] **Step 1: Regenerate Xcode project and build**

```bash
xcodegen generate && xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Verify new files are in the project**

```bash
grep -r "GoalCreateFlowView\|GoalEditFormView\|GoalCategorySheet\|GoalFrequencySheet\|GoalEditorHelpers" \
  TamaGoosie.xcodeproj/project.pbxproj | head -20
```

Expected: All 5 new files appear in the project file.

- [ ] **Step 3: Verify GoalListView sheet presentation is compatible**

Read GoalListView.swift and confirm the `.sheet` that presents `GoalEditorView` still passes `existingGoal:` and `prefill:` parameters correctly. No changes should be needed since the init signature is unchanged.

- [ ] **Step 4: Commit (if any fixes needed)**

```bash
git add -A && git commit -m "fix: integration fixes for goal editor redesign"
```

Only run if fixes were needed. Skip if build succeeded without changes.
