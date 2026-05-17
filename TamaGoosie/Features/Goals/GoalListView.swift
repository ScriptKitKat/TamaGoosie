import SwiftUI
import SwiftData

struct GoalListView: View {
    @Environment(\.modelContext) private var modelContext
    // NOTE: Do not filter in @Query — SwiftData boolean predicates are unreliable on iOS 17.
    // Filter to active goals in Swift instead.
    @Query(sort: \Goal.sortOrder) private var allGoals: [Goal]
    @Query private var gooseStates: [GooseState]
    @Query(sort: \DailyLog.date, order: .reverse) private var allDailyLogs: [DailyLog]
    @Query private var profiles: [UserProfile]

    private var goals: [Goal] {
        let active   = allGoals.filter { $0.isActive }
        return active.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var habits: [Goal] {
        goals.filter { $0.type == "recurring" || $0.type == "builtin" }
    }

    private var quests: [Goal] {
        goals.filter { $0.type == "deadline" && !$0.isCompleted }
    }

    private var completedQuests: [Goal] {
        allGoals.filter { $0.type == "deadline" && $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private var todayLog: DailyLog? {
        allDailyLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    @State private var selectedGoalTab: GoalTab = .today
    @State private var showInitialGoalPicker = false
    @State private var confettiBursts: [ConfettiBurst] = []

    @State private var viewModel = GoalViewModel()

    private var gooseState: GooseState? {
        gooseStates.first
    }

    private var isWatchPaired: Bool { WatchSyncService.shared.isWatchPaired }

    var body: some View {
        ZStack {
            GrassyBackgroundView()

            ScrollView {
                VStack(spacing: 16) {
                    GoalTabPicker(selected: $selectedGoalTab)

                    switch selectedGoalTab {
                    case .today:
                        TodayGoalsTab(
                            goals: goals,
                            gooseState: gooseState,
                            todayLog: todayLog,
                            viewModel: viewModel,
                            modelContext: modelContext,
                            onEnsureTodayLog: { ensureTodayLogExists() },
                            onConfetti: { origin in spawnConfetti(at: origin) }
                        )
                    case .habits:
                        HabitsGoalsTab(
                            habits: habits,
                            viewModel: viewModel,
                            modelContext: modelContext
                        )
                    case .quests:
                        QuestsGoalsTab(
                            quests: quests,
                            completedQuests: completedQuests,
                            gooseState: gooseState,
                            viewModel: viewModel,
                            modelContext: modelContext,
                            onEnsureTodayLog: { ensureTodayLogExists() },
                            onConfetti: { origin in spawnConfetti(at: origin) }
                        )
                    }
                }
                .padding(.top, 52)
                .padding(.bottom, 20)
                .trackScrollOffset()
            }

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
                    goals: goals,
                    steps: steps,
                    sleepHours: GooseEngine.shared.cachedSleepHours,
                    state: state
                )
            }
        }
        .onChange(of: GooseEngine.shared.cachedSleepHours) { _, hours in
            if let state = gooseState {
                viewModel.autoCompleteHealthKitGoals(
                    goals: goals,
                    steps: GooseEngine.shared.cachedSteps,
                    sleepHours: hours,
                    state: state
                )
            }
        }
        .onChange(of: GooseEngine.shared.cachedExerciseMinutes) { _, _ in
            if let state = gooseState {
                viewModel.autoCompleteHealthKitGoals(
                    goals: goals,
                    steps: GooseEngine.shared.cachedSteps,
                    sleepHours: GooseEngine.shared.cachedSleepHours,
                    state: state
                )
            }
        }
        .onChange(of: GooseEngine.shared.cachedOutsideMinutes) { _, _ in
            if let state = gooseState {
                viewModel.autoCompleteHealthKitGoals(
                    goals: goals,
                    steps: GooseEngine.shared.cachedSteps,
                    sleepHours: GooseEngine.shared.cachedSleepHours,
                    state: state
                )
            }
        }
        .onChange(of: GooseEngine.shared.cachedDistractMinutes) { _, _ in }
    }

    // MARK: - Helpers

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

    @discardableResult
    private func ensureTodayLogExists() -> DailyLog {
        if let existing = todayLog { return existing }
        let log = DailyLog(date: .now)
        modelContext.insert(log)
        return log
    }

    /// On a new day, snapshot the current goose stats into yesterday's DailyLog
    /// so DuckHistoryCard can chart real data.
    private func snapshotYesterdayIfNeeded() {
        guard let state = gooseState else { return }
        let calendar = Calendar.current
        let yesterdayLog = allDailyLogs.first {
            calendar.isDateInYesterday($0.date)
        }
        if let yesterdayLog {
            GooseEngine.shared.snapshotEndOfDay(state: state, yesterdayLog: yesterdayLog)
        }
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
        Color(hex: UInt(goal.colorHex, radix: 16) ?? 0xFFD93D)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category tag
            VStack {
                Image(systemName: goal.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(categoryColor)
                    )
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.75))
                    .strikethrough(goal.isCompleted)

                HStack(spacing: 6) {
                    Text(goal.goalFrequency.displayName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.black.opacity(0.4))

                    if goal.currentStreak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(hex: 0xFF6D00))
                            Text("\(goal.currentStreak)")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.black.opacity(0.5))
                        }
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
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
        )
        .opacity(goal.isCompleted ? 0.7 : 1)
    }

    private var progressRing: some View {
        Button(action: goal.isCompleted ? onUncomplete : onIncrement) {
            ZStack {
                Circle()
                    .stroke(categoryColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 38, height: 38)

                Circle()
                    .trim(from: 0, to: goal.progress)
                    .stroke(goal.isCompleted ? categoryColor.opacity(0.5) : categoryColor,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(-90))

                Text("\(goal.currentCount)/\(goal.targetCount)")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black.opacity(0.6))
            }
        }
    }

    private var checkButton: some View {
        Button(action: goal.isCompleted ? onUncomplete : onComplete) {
            ZStack {
                Circle()
                    .fill(goal.isCompleted ? categoryColor : .clear)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(goal.isCompleted ? categoryColor : .black.opacity(0.2), lineWidth: 2.5)
                    )
                if goal.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Deadline Goal Card

struct DeadlineGoalCardView: View {
    let goal: Goal
    var onComplete: () -> Void
    var onUncomplete: () -> Void
    var onSetPercentage: (Double) -> Void
    var onCelebration: (CGPoint) -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var showSlider = false
    @State private var sliderValue: Double = 0
    @State private var bounceScale: CGFloat = 1.0
    @State private var cardGlow = false
    @State private var cardCenter: CGPoint = .zero

    private var categoryColor: Color {
        Color(hex: UInt(goal.colorHex, radix: 16) ?? 0xFFD93D)
    }

    private var percentInt: Int { Int(goal.percentageProgress * 100) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Category tag
                Image(systemName: goal.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(categoryColor)
                    )

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.75))
                        .strikethrough(goal.isCompleted)

                    HStack(spacing: 6) {
                        if let due = goal.dueDate {
                            Text("due \(due.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.black.opacity(0.35))
                        }
                    }
                }

                Spacer()

                // Checkmark button
                checkButton

                // Slider toggle
                Button {
                    sliderValue = goal.percentageProgress
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSlider.toggle()
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(showSlider ? categoryColor : .black.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
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
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(categoryColor.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(categoryColor)
                        .frame(width: geo.size.width * goal.percentageProgress, height: 6)
                        .animation(.easeOut(duration: 0.2), value: goal.percentageProgress)
                }
            }
            .frame(height: 6)
            .padding(.top, 10)

            // Inline slider
            if showSlider {
                VStack(spacing: 4) {
                    Slider(value: $sliderValue, in: 0...1, step: 0.01)
                        .tint(categoryColor)
                        .padding(.top, 10)

                    HStack {
                        Text("Set progress: \(Int(sliderValue * 100))%")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.black.opacity(0.5))
                        Spacer()
                        Button("Done") {
                            onSetPercentage(sliderValue)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSlider = false
                            }
                            if sliderValue >= 1.0 {
                                triggerCelebration()
                            }
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(categoryColor)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
        )
        .scaleEffect(bounceScale)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(categoryColor, lineWidth: cardGlow ? 2 : 0)
                .animation(.easeOut(duration: 0.4), value: cardGlow)
        )
        .opacity(goal.isCompleted ? 0.7 : 1)
        // Track card position for confetti burst origin
        .onGeometryChange(for: CGPoint.self) { geo in
            let f = geo.frame(in: .global)
            return CGPoint(x: f.midX, y: f.midY)
        } action: { center in
            cardCenter = center
        }
    }

    private var checkButton: some View {
        Button(action: {
            if goal.isCompleted {
                onUncomplete()
            } else {
                onComplete()
                triggerCelebration()
            }
        }) {
            ZStack {
                Circle()
                    .fill(goal.isCompleted ? categoryColor : .clear)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(goal.isCompleted ? categoryColor : .black.opacity(0.2), lineWidth: 2.5)
                    )
                if goal.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func triggerCelebration() {
        onCelebration(cardCenter)
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

// MARK: - HealthKit Goal Card

struct HealthKitGoalCardView: View {
    let goal: Goal
    let progress: Double          // 0.0 – 1.0
    let valueLabel: String        // e.g. "7,200 / 10,000 steps"
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var categoryColor: Color {
        Color(hex: UInt(goal.colorHex, radix: 16) ?? 0xFFD93D)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Category tag
                Image(systemName: goal.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(categoryColor)
                    )

                // Title row
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.75))
                        .strikethrough(goal.isCompleted)

                    HStack(spacing: 6) {
                        Text(goal.goalFrequency.displayName)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.black.opacity(0.4))

                        if goal.currentStreak > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: 0xFF6D00))
                                Text("\(goal.currentStreak)")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.black.opacity(0.5))
                            }
                        }
                    }
                }

                Spacer()

                // Kebab menu
                Menu {
                    Button { onEdit() } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
            }

            // Value label
            Text(valueLabel)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.black.opacity(0.45))

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(categoryColor.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(progress >= 1.0 ? categoryColor : categoryColor.opacity(0.8))
                        .frame(width: geo.size.width * min(progress, 1.0), height: 6)
                        .animation(.easeOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
        )
        .opacity(goal.isCompleted ? 0.7 : 1.0)
    }
}

// MARK: - Confetti Models

struct ConfettiBurst: Identifiable {
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
