import SwiftUI
import SwiftData

struct TodayGoalsTab: View {
    let goals: [Goal]
    let gooseState: GooseState?
    let todayLog: DailyLog?
    let viewModel: GoalViewModel
    let modelContext: ModelContext
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
            todayHeader
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.bottom, 16)

            if goals.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(goals, id: \.id) { goal in
                        goalCard(for: goal)
                    }
                }
                .padding(.horizontal, GoosieTheme.padding)
            }

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
                onDelete: { viewModel.deleteGoal(goal, in: modelContext) }
            )
        } else if goal.isHealthKitTracked {
            HealthKitGoalCardView(
                goal: goal,
                progress: hkProgress(for: goal),
                valueLabel: hkLabel(for: goal),
                onEdit: { viewModel.startEditing(goal) },
                onDelete: { viewModel.deleteGoal(goal, in: modelContext) }
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
                onDelete: { viewModel.deleteGoal(goal, in: modelContext) }
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
