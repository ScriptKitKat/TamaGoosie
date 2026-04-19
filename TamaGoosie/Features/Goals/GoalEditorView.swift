import SwiftUI
import SwiftData

struct GoalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var gooseStates: [GooseState]

    var existingGoal: Goal?
    var prefill: GoalDraft?

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
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    init(existingGoal: Goal? = nil, prefill: GoalDraft? = nil) {
        self.existingGoal = existingGoal
        self.prefill = prefill
        let draft = (existingGoal == nil) ? prefill : nil
        let defaultTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
        _title          = State(initialValue: draft?.title ?? "")
        _goalType       = State(initialValue: draft?.goalType ?? "recurring")
        _category       = State(initialValue: draft?.category ?? .custom)
        _frequency      = State(initialValue: draft?.frequency ?? .daily)
        _customDays     = State(initialValue: draft?.customDays ?? [])
        _targetCount    = State(initialValue: draft?.targetCount ?? 1)
        _happinessWeight = State(initialValue: draft?.happinessWeight ?? 1.0)
        _dueDate        = State(initialValue: draft?.dueDate ?? Date())
        _enableReminder = State(initialValue: draft?.enableReminder ?? false)
        _preferredTime  = State(initialValue: draft?.preferredTime ?? defaultTime)
    }

    var isEditing: Bool { existingGoal != nil }
    var isBuiltin: Bool { existingGoal?.type == "builtin" }

    private let goalTypes = ["recurring", "deadline"]

    // Weekday labels: index 0 → weekday 1 (Sun), index 6 → weekday 7 (Sat)
    private let weekdayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                GoosieTheme.mintBackground
                    .ignoresSafeArea()

                ScrollView {
                    if isBuiltin {
                        builtinThresholdEditor
                    } else {
                        fullEditor
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
            .navigationTitle(isBuiltin ? "Edit Goal Target" : (isEditing ? "Edit Goal" : "New Goal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isBuiltin {
                        Button("Save") { saveBuiltin() }
                    } else {
                        Button("Save") { save() }
                    }
                }
            }
            .onAppear {
                if existingGoal != nil { loadExistingGoal() }
            }
        }
    }

    // MARK: - Built-in threshold editor

    @ViewBuilder
    private var builtinThresholdEditor: some View {
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
                if existingGoal?.title.localizedCaseInsensitiveContains("steps") == true {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily step target")
                            .font(GoosieTheme.captionFont())
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                        Stepper(value: $targetCount, in: 1000...50000, step: 500) {
                            Text("\(targetCount.formatted()) steps")
                                .font(GoosieTheme.bodyFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                        }
                    }
                } else if existingGoal?.title.localizedCaseInsensitiveContains("sleep") == true {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sleep target (hours)")
                            .font(GoosieTheme.captionFont())
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                        Stepper(value: $targetCount, in: 4...12, step: 1) {
                            Text("\(targetCount) hours")
                                .font(GoosieTheme.bodyFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Screen time limit (minutes)")
                            .font(GoosieTheme.captionFont())
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                        Stepper(value: $targetCount, in: 30...480, step: 15) {
                            Text("\(targetCount) minutes")
                                .font(GoosieTheme.bodyFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                        }
                    }
                }
            }
        }
        .padding(GoosieTheme.padding)
    }

    // MARK: - Full editor

    private var fullEditor: some View {
        VStack(spacing: 20) {
                        // Title
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Goal Title")
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                                TextField("e.g., Drink 8 glasses of water", text: $title)
                                    .font(GoosieTheme.bodyFont())
                                    .textFieldStyle(.plain)
                            }
                        }

                        // Goal Type
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Type")
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                                HStack(spacing: 8) {
                                    ForEach(goalTypes, id: \.self) { type in
                                        typeChip(type)
                                    }
                                }
                            }
                        }

                        // Category picker
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Category")
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 10) {
                                    ForEach(GoalCategory.allCases, id: \.self) { cat in
                                        categoryChip(cat)
                                    }
                                }
                            }
                        }

                        // Frequency (recurring only)
                        if goalType == "recurring" {
                            GoosieCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Frequency")
                                        .font(GoosieTheme.captionFont())
                                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                                    // Two-row layout to prevent overflow
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            ForEach([GoalFrequency.daily, .weekdays, .weekends], id: \.self) { freq in
                                                frequencyChip(freq)
                                            }
                                        }
                                        HStack(spacing: 8) {
                                            ForEach([GoalFrequency.weekly, .custom], id: \.self) { freq in
                                                frequencyChip(freq)
                                            }
                                        }
                                    }

                                    // Custom day picker
                                    if frequency == .custom {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Select days")
                                                .font(GoosieTheme.captionFont(11))
                                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

                                            HStack(spacing: 6) {
                                                ForEach(0..<7, id: \.self) { index in
                                                    let weekday = index + 1 // 1=Sun…7=Sat
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
                                                                    .fill(isSelected ? GoosieTheme.coralAccent : GoosieTheme.coralAccent.opacity(0.12))
                                                            )
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.top, 4)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                .animation(.easeInOut(duration: 0.2), value: frequency)
                            }

                            // Target count
                            GoosieCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Daily Target")
                                        .font(GoosieTheme.captionFont())
                                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                                    Stepper(value: $targetCount, in: 1...99) {
                                        Text("\(targetCount) time\(targetCount > 1 ? "s" : "")")
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

                        // Preferred time / reminder (all goal types)
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle(isOn: $enableReminder.animation()) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Set a reminder time")
                                            .font(GoosieTheme.captionFont())
                                            .foregroundStyle(GoosieTheme.charcoalOutline)
                                        Text("Time I usually do this")
                                            .font(GoosieTheme.captionFont(11))
                                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                                    }
                                }
                                .tint(GoosieTheme.coralAccent)

                                if enableReminder {
                                    DatePicker("Time", selection: $preferredTime, displayedComponents: .hourAndMinute)
                                        .font(GoosieTheme.captionFont())

                                    if notificationPermissionDenied {
                                        Text("Notifications are disabled. Enable them in Settings to receive reminders.")
                                            .font(GoosieTheme.captionFont(11))
                                            .foregroundStyle(.orange)
                                    } else {
                                        Text("You'll receive a daily reminder at this time.")
                                            .font(GoosieTheme.captionFont(11))
                                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                                    }
                                }
                            }
                        }
                        .onChange(of: enableReminder) { _, newValue in
                            if newValue { requestNotificationPermissionIfNeeded() }
                        }

                        // Importance weight
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Importance")
                                        .font(GoosieTheme.captionFont())
                                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                                    Spacer()
                                    Text(String(format: "%.1fx", happinessWeight))
                                        .font(GoosieTheme.captionFont(12))
                                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                                }

                                Slider(value: $happinessWeight, in: 0.5...2.0, step: 0.5)
                                    .tint(GoosieTheme.coralAccent)
                            }
                        }
        }
        .padding(GoosieTheme.padding)
    }

    private func typeChip(_ type: String) -> some View {
        let isSelected = goalType == type
        let label = type == "recurring" ? "Recurring" : "Deadline"

        return Button {
            goalType = type
        } label: {
            Text(label)
                .font(GoosieTheme.captionFont(12))
                .foregroundStyle(isSelected ? .white : GoosieTheme.charcoalOutline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? GoosieTheme.coralAccent : GoosieTheme.coralAccent.opacity(0.15))
                )
        }
    }

    private func categoryChip(_ cat: GoalCategory) -> some View {
        let isSelected = category == cat
        let chipColor = Color(hex: UInt(cat.color, radix: 16) ?? 0xFFD93D)

        return Button {
            category = cat
        } label: {
            VStack(spacing: 4) {
                Image(systemName: cat.icon)
                    .font(.system(size: 16))
                Text(cat.displayName)
                    .font(GoosieTheme.captionFont(10))
            }
            .foregroundStyle(isSelected ? .white : GoosieTheme.charcoalOutline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? chipColor : chipColor.opacity(0.15))
            )
        }
    }

    private func frequencyChip(_ freq: GoalFrequency) -> some View {
        let isSelected = frequency == freq

        return Button {
            frequency = freq
        } label: {
            Text(freq.displayName)
                .font(GoosieTheme.captionFont(12))
                .foregroundStyle(isSelected ? .white : GoosieTheme.charcoalOutline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? GoosieTheme.coralAccent : GoosieTheme.coralAccent.opacity(0.15))
                )
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

    private func saveBuiltin() {
        guard let goal = existingGoal else { return }
        goal.targetCount = targetCount
        try? modelContext.save()
        syncAllGoalsToConvex()
        dismiss()
    }

    private func requestNotificationPermissionIfNeeded() {
        Task {
            do {
                let granted = try await GooseNotificationSystem.shared.requestAuthorization()
                await MainActor.run {
                    notificationPermissionDenied = !granted
                }
            } catch {
                await MainActor.run {
                    notificationPermissionDenied = true
                }
            }
        }
    }

    private func loadExistingGoal() {
        guard let goal = existingGoal else { return }
        title = goal.title
        goalType = goal.type
        category = goal.goalCategory
        frequency = goal.goalFrequency
        customDays = goal.customDaysSet
        targetCount = goal.targetCount
        happinessWeight = goal.happinessWeight
        if let due = goal.dueDate { dueDate = due }
        if let pref = goal.preferredTime {
            preferredTime = pref
            enableReminder = true
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

        let resolvedPreferredTime: Date? = enableReminder ? preferredTime : nil

        if let goal = existingGoal {
            goal.title = trimmedTitle
            goal.type = goalType
            goal.category = category.rawValue
            goal.frequency = frequency.rawValue
            goal.customDaysSet = customDays
            goal.targetCount = targetCount
            goal.happinessWeight = happinessWeight
            goal.dueDate = goalType == "deadline" ? dueDate : nil
            goal.preferredTime = resolvedPreferredTime
            scheduleReminderIfNeeded(for: goal)
        } else {
            let goal = Goal(
                title: trimmedTitle,
                type: goalType,
                category: category,
                frequency: frequency,
                targetCount: targetCount,
                happinessWeight: happinessWeight
            )
            goal.dueDate = goalType == "deadline" ? dueDate : nil
            goal.preferredTime = resolvedPreferredTime
            goal.customDaysSet = customDays
            modelContext.insert(goal)
            scheduleReminderIfNeeded(for: goal)
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

    private func scheduleReminderIfNeeded(for goal: Goal) {
        // GooseNotificationSystem.rescheduleAll (called from ContentView) handles all scheduling.
        // Cancel pushes here only when a reminder is explicitly removed.
        if goal.preferredTime == nil {
            GooseNotificationSystem.shared.cancelPushes(for: goal.id)
        }
    }
}
