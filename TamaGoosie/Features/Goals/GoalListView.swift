import SwiftUI
import SwiftData

struct GoalListView: View {
    @Environment(\.modelContext) private var modelContext
    // NOTE: Do not filter in @Query — SwiftData boolean predicates are unreliable on iOS 17.
    // Filter to active goals in Swift instead.
    @Query(sort: \Goal.sortOrder) private var allGoals: [Goal]
    @Query private var gooseStates: [GooseState]

    private var goals: [Goal] { allGoals.filter { $0.isActive } }

    @State private var viewModel = GoalViewModel()

    private var gooseState: GooseState? {
        gooseStates.first
    }

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text("Goals")
                            .font(GoosieTheme.titleFont(28))
                            .foregroundStyle(GoosieTheme.charcoalOutline)
                        Spacer()
                        Button {
                            viewModel.startCreating()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(GoosieTheme.coralAccent)
                        }
                    }
                    .padding(.horizontal, GoosieTheme.padding)

                    // Goal cards
                    if goals.isEmpty {
                        emptyState
                    } else {
                        ForEach(goals, id: \.id) { goal in
                            if goal.type == "deadline" {
                                DeadlineGoalCardView(
                                    goal: goal,
                                    onIncrement: {
                                        if let state = gooseState {
                                            viewModel.incrementDeadlinePercentage(goal, gooseState: state)
                                        }
                                    },
                                    onSetPercentage: { value in
                                        if let state = gooseState {
                                            viewModel.setDeadlinePercentage(goal, gooseState: state, to: value)
                                        }
                                    },
                                    onDelete: {
                                        viewModel.deleteGoal(goal, in: modelContext)
                                    }
                                )
                                .padding(.horizontal, GoosieTheme.padding)
                            } else {
                                GoalCardView(
                                    goal: goal,
                                    onComplete: {
                                        if let state = gooseState {
                                            viewModel.completeGoal(goal, gooseState: state)
                                        }
                                    },
                                    onIncrement: {
                                        if let state = gooseState {
                                            viewModel.incrementGoal(goal, gooseState: state)
                                        }
                                    },
                                    onDelete: {
                                        viewModel.deleteGoal(goal, in: modelContext)
                                    }
                                )
                                .padding(.horizontal, GoosieTheme.padding)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .sheet(isPresented: $viewModel.showEditor) {
            GoalEditorView(existingGoal: viewModel.editingGoal)
        }
        .onAppear {
            viewModel.seedBuiltinGoalsIfNeeded(in: modelContext)
            viewModel.resetDailyGoals(goals)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.3))

            Text("No goals yet!")
                .font(GoosieTheme.bodyFont(18))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

            PillButton(title: "Add Goal", icon: "plus", color: GoosieTheme.coralAccent) {
                viewModel.startCreating()
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - Recurring / Builtin Goal Card

struct GoalCardView: View {
    let goal: Goal
    var onComplete: () -> Void
    var onIncrement: () -> Void
    var onDelete: () -> Void

    private var categoryColor: Color {
        Color(hex: UInt(goal.goalCategory.color, radix: 16) ?? 0xFFD93D)
    }

    var body: some View {
        GoosieCard {
            HStack(spacing: 12) {
                // Category accent
                RoundedRectangle(cornerRadius: 4)
                    .fill(categoryColor)
                    .frame(width: 4)

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: goal.goalCategory.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(categoryColor)

                        Text(goal.title)
                            .font(GoosieTheme.bodyFont(16))
                            .foregroundStyle(GoosieTheme.charcoalOutline)
                            .strikethrough(goal.isCompleted)
                    }

                    HStack {
                        Text(goal.goalFrequency.displayName)
                            .font(GoosieTheme.captionFont(11))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

                        if goal.currentStreak > 0 {
                            StreakFlame(days: goal.currentStreak)
                        }
                    }
                }

                Spacer()

                // Progress ring / check button
                if goal.targetCount > 1 {
                    progressRing
                } else {
                    checkButton
                }
            }
        }
        .opacity(goal.isCompleted ? 0.7 : 1)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var progressRing: some View {
        Button(action: onIncrement) {
            ZStack {
                Circle()
                    .stroke(categoryColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: goal.progress)
                    .stroke(categoryColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))

                Text("\(goal.currentCount)/\(goal.targetCount)")
                    .font(GoosieTheme.captionFont(10))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
            }
        }
    }

    private var checkButton: some View {
        Button(action: onComplete) {
            Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 28))
                .foregroundStyle(goal.isCompleted ? categoryColor : GoosieTheme.charcoalOutline.opacity(0.3))
        }
        .disabled(goal.isCompleted)
    }
}

// MARK: - Deadline Goal Card

struct DeadlineGoalCardView: View {
    let goal: Goal
    var onIncrement: () -> Void
    var onSetPercentage: (Double) -> Void
    var onDelete: () -> Void

    @State private var showSlider = false
    @State private var sliderValue: Double = 0
    @State private var showConfetti = false
    @State private var bounceScale: CGFloat = 1.0
    @State private var tapCount = 0
    @State private var tapResetTask: Task<Void, Never>? = nil
    @State private var cardGlow = false

    private var categoryColor: Color {
        Color(hex: UInt(goal.goalCategory.color, radix: 16) ?? 0xFFD93D)
    }

    private var percentInt: Int { Int(goal.percentageProgress * 100) }

    var body: some View {
        ZStack {
            GoosieCard {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Category accent
                        RoundedRectangle(cornerRadius: 4)
                            .fill(categoryColor)
                            .frame(width: 4)

                        // Content
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: goal.goalCategory.icon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(categoryColor)

                                Text(goal.title)
                                    .font(GoosieTheme.bodyFont(16))
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                                    .strikethrough(goal.isCompleted)
                            }

                            HStack(spacing: 6) {
                                Text("Deadline")
                                    .font(GoosieTheme.captionFont(11))
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

                                if let due = goal.dueDate {
                                    Text("· due \(due.formatted(date: .abbreviated, time: .omitted))")
                                        .font(GoosieTheme.captionFont(11))
                                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                                }
                            }
                        }

                        Spacer()

                        // Percentage ring
                        ZStack {
                            Circle()
                                .stroke(categoryColor.opacity(0.2), lineWidth: 4)
                                .frame(width: 48, height: 48)

                            Circle()
                                .trim(from: 0, to: goal.percentageProgress)
                                .stroke(categoryColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 48, height: 48)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut(duration: 0.2), value: goal.percentageProgress)

                            Text("\(percentInt)%")
                                .font(GoosieTheme.captionFont(10))
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                        }
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(categoryColor.opacity(0.15))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(categoryColor)
                                .frame(width: geo.size.width * goal.percentageProgress, height: 4)
                                .animation(.easeOut(duration: 0.2), value: goal.percentageProgress)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 10)
                    .padding(.leading, 12)

                    // Inline slider (long press)
                    if showSlider {
                        VStack(spacing: 4) {
                            Slider(value: $sliderValue, in: 0...1, step: 0.01)
                                .tint(categoryColor)
                                .padding(.top, 10)

                            HStack {
                                Text("Set progress: \(Int(sliderValue * 100))%")
                                    .font(GoosieTheme.captionFont(12))
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                                Spacer()
                                Button("Done") {
                                    onSetPercentage(sliderValue)
                                    showSlider = false
                                }
                                .font(GoosieTheme.captionFont(12))
                                .foregroundStyle(GoosieTheme.coralAccent)
                            }
                        }
                        .padding(.top, 4)
                        .padding(.leading, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
            .scaleEffect(bounceScale)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(categoryColor, lineWidth: cardGlow ? 2 : 0)
                    .animation(.easeOut(duration: 0.4), value: cardGlow)
            )

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .opacity(goal.isCompleted ? 0.8 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !goal.isCompleted else { return }
            handleTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            sliderValue = goal.percentageProgress
            withAnimation(.easeInOut(duration: 0.2)) {
                showSlider.toggle()
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func handleTap() {
        onIncrement()

        tapCount += 1
        tapResetTask?.cancel()
        tapResetTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if tapCount >= 5 {
                    triggerCelebration()
                }
                tapCount = 0
            }
        }

        // Small bounce on every tap
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            bounceScale = 1.05
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5).delay(0.1)) {
            bounceScale = 1.0
        }
    }

    private func triggerCelebration() {
        showConfetti = true
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) { bounceScale = 1.12 }
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4).delay(0.15)) { bounceScale = 0.96 }
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4).delay(0.25)) { bounceScale = 1.0 }
        cardGlow = true
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            await MainActor.run { cardGlow = false }
            try? await Task.sleep(for: .seconds(2.0))
            await MainActor.run { showConfetti = false }
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        Canvas { context, size in
            for p in particles {
                let rect = CGRect(
                    x: p.x * size.width - p.size / 2,
                    y: p.y * size.height - p.size / 2,
                    width: p.size,
                    height: p.size * 0.6
                )
                var contextCopy = context
                contextCopy.rotate(by: .degrees(p.rotation))
                contextCopy.fill(Path(ellipseIn: rect), with: .color(p.color))
            }
        }
        .onAppear {
            spawnParticles()
            animateParticles()
        }
    }

    private func spawnParticles() {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .blue, .purple, .pink,
            GoosieTheme.coralAccent, GoosieTheme.mintBackground
        ]
        particles = (0..<50).map { _ in
            ConfettiParticle(
                x: Double.random(in: 0.1...0.9),
                y: Double.random(in: -0.2...0.2),
                size: Double.random(in: 6...12),
                color: colors.randomElement()!,
                speed: Double.random(in: 0.003...0.007),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -8...8),
                drift: Double.random(in: -0.002...0.002)
            )
        }
    }

    private func animateParticles() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            var allGone = true
            for i in particles.indices {
                particles[i].y += particles[i].speed
                particles[i].x += particles[i].drift
                particles[i].rotation += particles[i].rotationSpeed
                if particles[i].y < 1.3 { allGone = false }
            }
            if allGone { timer.invalidate() }
        }
    }
}

private struct ConfettiParticle {
    var x: Double
    var y: Double
    var size: Double
    var color: Color
    var speed: Double
    var rotation: Double
    var rotationSpeed: Double
    var drift: Double
}
