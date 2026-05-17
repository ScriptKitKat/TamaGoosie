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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(GoosieTheme.captionFont())
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

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
