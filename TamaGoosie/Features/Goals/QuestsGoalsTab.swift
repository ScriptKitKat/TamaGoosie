import SwiftUI
import SwiftData

struct QuestsGoalsTab: View {
    let quests: [Goal]
    let completedQuests: [Goal]
    let gooseState: GooseState?
    let viewModel: GoalViewModel
    let modelContext: ModelContext
    let onEnsureTodayLog: () -> DailyLog
    let onConfetti: (CGPoint) -> Void

    @State private var showHistory = false

    private let pokGreen = Color(hex: 0x43A047)

    var body: some View {
        VStack(spacing: 0) {
            if quests.isEmpty && completedQuests.isEmpty {
                emptyState
            } else {
                // Active quests
                if !quests.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(quests, id: \.id) { quest in
                            DeadlineGoalCardView(
                                goal: quest,
                                onComplete: {
                                    if let state = gooseState {
                                        viewModel.completeDeadlineGoal(quest, gooseState: state, log: onEnsureTodayLog(), goals: quests)
                                    }
                                },
                                onUncomplete: {
                                    if let state = gooseState {
                                        viewModel.uncompleteDeadlineGoal(quest, gooseState: state, log: onEnsureTodayLog(), goals: quests)
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
                } else {
                    emptyActiveState
                }

                // History section for completed quests
                if !completedQuests.isEmpty {
                    historySection
                        .padding(.horizontal, GoosieTheme.padding)
                        .padding(.top, 16)
                }
            }

            newQuestButton
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 12)
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHistory.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showHistory ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                    Text("History")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Text("\(completedQuests.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.vertical, 8)
            }

            if showHistory {
                VStack(spacing: 8) {
                    ForEach(completedQuests, id: \.id) { quest in
                        completedQuestRow(quest)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func completedQuestRow(_ quest: Goal) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(hex: UInt(quest.colorHex, radix: 16) ?? 0xFFD93D).opacity(0.6))

            VStack(alignment: .leading, spacing: 2) {
                Text(quest.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .strikethrough()

                if let completed = quest.completedAt {
                    Text("Completed \(completed.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            Spacer()

            Menu {
                Button(role: .destructive) {
                    viewModel.deleteGoal(quest, in: modelContext)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.08))
        )
    }

    private var emptyActiveState: some View {
        VStack(spacing: 8) {
            Text("All quests completed!")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 24)
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
