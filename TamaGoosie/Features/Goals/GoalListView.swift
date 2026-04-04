import SwiftUI
import SwiftData

struct GoalListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Goal> { $0.isActive }, sort: \Goal.sortOrder)
    private var goals: [Goal]
    @Query private var gooseStates: [GooseState]

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

// MARK: - Goal Card

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
