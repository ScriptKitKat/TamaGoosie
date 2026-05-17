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
