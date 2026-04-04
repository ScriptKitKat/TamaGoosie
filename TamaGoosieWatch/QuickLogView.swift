import SwiftUI

struct QuickLogView: View {
    @State private var syncService = WatchSyncReceiver.shared

    var body: some View {
        NavigationStack {
            List {
                if syncService.activeGoals.isEmpty {
                    Text("No active goals")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(syncService.activeGoals.prefix(3)) { goal in
                        Button {
                            completeGoal(goal)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(goal.title)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .lineLimit(2)

                                    Text("\(goal.currentCount)/\(goal.targetCount)")
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(goal.isCompleted ? .green : .gray)
                            }
                        }
                        .disabled(goal.isCompleted)
                    }
                }
            }
            .navigationTitle("Goals")
        }
    }

    private func completeGoal(_ goal: GoalSummary) {
        syncService.sendGoalCompletion(goalID: goal.id)
    }
}
