import SwiftUI
import SwiftData

struct GoalListView: View {
    @Environment(\.modelContext) private var modelContext
    // NOTE: Do not filter in @Query — SwiftData boolean predicates are unreliable on iOS 17.
    // Filter to active goals in Swift instead.
    @Query(sort: \Goal.sortOrder) private var allGoals: [Goal]
    @Query private var gooseStates: [GooseState]

    private var goals: [Goal] { allGoals.filter { $0.isActive } }

    @State private var confettiBursts: [ConfettiBurst] = []

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
                                    onCelebration: { origin in
                                        let burst = ConfettiBurst(origin: origin)
                                        confettiBursts.append(burst)
                                        Task {
                                            try? await Task.sleep(for: .seconds(2.5))
                                            await MainActor.run {
                                                confettiBursts.removeAll { $0.id == burst.id }
                                            }
                                        }
                                    },
                                    onEdit: { viewModel.startEditing(goal) },
                                    onDelete: { viewModel.deleteGoal(goal, in: modelContext) }
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
                                    onUncomplete: {
                                        if let state = gooseState {
                                            viewModel.uncompleteGoal(goal, gooseState: state)
                                        }
                                    },
                                    onIncrement: {
                                        if let state = gooseState {
                                            viewModel.incrementGoal(goal, gooseState: state)
                                        }
                                    },
                                    onEdit: { viewModel.startEditing(goal) },
                                    onDelete: { viewModel.deleteGoal(goal, in: modelContext) }
                                )
                                .padding(.horizontal, GoosieTheme.padding)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }

            // Full-screen confetti bursts — multiple can stack simultaneously
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
    var onUncomplete: () -> Void
    var onIncrement: () -> Void
    var onEdit: () -> Void
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

                // Kebab menu
                Menu {
                    Button { onEdit() } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) { onDelete() } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
            }
        }
        .opacity(goal.isCompleted ? 0.7 : 1)
    }

    private var progressRing: some View {
        Button(action: goal.isCompleted ? onUncomplete : onIncrement) {
            ZStack {
                Circle()
                    .stroke(categoryColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: goal.progress)
                    .stroke(goal.isCompleted ? categoryColor.opacity(0.5) : categoryColor,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))

                Text("\(goal.currentCount)/\(goal.targetCount)")
                    .font(GoosieTheme.captionFont(10))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
            }
        }
    }

    private var checkButton: some View {
        Button(action: goal.isCompleted ? onUncomplete : onComplete) {
            Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 28))
                .foregroundStyle(goal.isCompleted ? categoryColor.opacity(0.6) : GoosieTheme.charcoalOutline.opacity(0.3))
        }
    }
}

// MARK: - Deadline Goal Card

struct DeadlineGoalCardView: View {
    let goal: Goal
    var onIncrement: () -> Void
    var onSetPercentage: (Double) -> Void
    var onCelebration: (CGPoint) -> Void   // passes card center in screen coords
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var showSlider = false
    @State private var sliderValue: Double = 0
    @State private var bounceScale: CGFloat = 1.0
    @State private var tapCount = 0
    @State private var tapResetTask: Task<Void, Never>? = nil
    @State private var cardGlow = false
    @State private var cardCenter: CGPoint = .zero

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

                        // Kebab menu
                        Menu {
                            Button { onEdit() } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) { onDelete() } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
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

        }
        .opacity(goal.isCompleted ? 0.8 : 1)
        .contentShape(Rectangle())
        // Track card position for confetti burst origin
        .onGeometryChange(for: CGPoint.self) { geo in
            let f = geo.frame(in: .global)
            return CGPoint(x: f.midX, y: f.midY)
        } action: { center in
            cardCenter = center
        }
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
    }

    private func handleTap() {
        onIncrement()
        tapCount += 1

        // Fire celebration immediately on the 5th tap — no delay
        if tapCount >= 5 {
            triggerCelebration()
            tapCount = 0
            tapResetTask?.cancel()
        } else {
            // Reset counter if user stops tapping for 1.5 s
            tapResetTask?.cancel()
            tapResetTask = Task {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                await MainActor.run { tapCount = 0 }
            }
        }
        // No per-tap bounce — the ring percentage is the right visual feedback.
        // Only the celebration (5th tap) triggers the big bounce below.
    }

    private func triggerCelebration() {
        onCelebration(cardCenter)  // full-screen confetti bursts from the card center
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) { bounceScale = 1.12 }
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4).delay(0.15)) { bounceScale = 0.96 }
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4).delay(0.25)) { bounceScale = 1.0 }
        cardGlow = true
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            await MainActor.run { cardGlow = false }
        }
    }
}

// MARK: - Confetti Models

private struct ConfettiBurst: Identifiable {
    let id = UUID()
    let origin: CGPoint
}

// MARK: - Confetti View

struct ConfettiView: View {
    /// Burst origin in global screen coordinates (points).
    let origin: CGPoint

    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        Canvas { context, _ in
            for p in particles {
                var ctx = context
                // Translate to particle center, rotate, then draw centered at origin
                ctx.translateBy(x: p.x, y: p.y)
                ctx.rotate(by: .degrees(p.rotation))
                let rect = CGRect(x: -p.size / 2, y: -p.size * 0.3,
                                  width: p.size, height: p.size * 0.6)
                ctx.fill(Path(ellipseIn: rect),
                         with: .color(p.color.opacity(p.opacity)))
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
            GoosieTheme.coralAccent, GoosieTheme.sunYellow
        ]
        particles = (0..<90).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 5...18)
            return ConfettiParticle(
                x: origin.x,
                y: origin.y,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                size: Double.random(in: 7...13),
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -10...10),
                opacity: 1.0
            )
        }
    }

    private func animateParticles() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            var allFaded = true
            for i in particles.indices {
                particles[i].x  += particles[i].vx
                particles[i].y  += particles[i].vy
                particles[i].vy += 0.4          // gravity pulls down
                particles[i].vx *= 0.98         // light air resistance
                particles[i].rotation += particles[i].rotationSpeed
                particles[i].opacity  -= 0.012  // fade out over ~83 frames ≈ 1.4 s
                if particles[i].opacity > 0 { allFaded = false }
            }
            if allFaded { timer.invalidate() }
        }
    }
}

private struct ConfettiParticle {
    var x: Double
    var y: Double
    var vx: Double          // horizontal velocity (pts/frame)
    var vy: Double          // vertical velocity (pts/frame)
    var size: Double
    var color: Color
    var rotation: Double
    var rotationSpeed: Double
    var opacity: Double
}
