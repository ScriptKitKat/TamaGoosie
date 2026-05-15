import SwiftUI
import SwiftData

struct QuestsGoalsTab: View {
    let quests: [Goal]
    let gooseState: GooseState?
    let viewModel: GoalViewModel
    let modelContext: ModelContext
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
                            onDelete: { viewModel.deleteGoal(quest, in: modelContext) }
                        )
                    }
                }
                .padding(.horizontal, GoosieTheme.padding)
            }

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
