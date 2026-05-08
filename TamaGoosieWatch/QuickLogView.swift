import SwiftUI

struct QuickLogView: View {
    @State private var syncService = WatchSyncReceiver.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Today's goals")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(WatchTheme.text)
                    .padding(.bottom, 8)

                VStack(spacing: 6) {
                    if syncService.activeGoals.isEmpty {
                        Text("No active goals")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(WatchTheme.textSecondary)
                            .padding(.top, 16)
                    } else {
                        ForEach(syncService.activeGoals.prefix(5)) { goal in
                            goalCard(goal)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .background(WatchTheme.creamWhite)
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Goal card

    private func goalCard(_ goal: GoalSummary) -> some View {
        Button {
            guard goal.progress < 1.0 else { return }
            syncService.sendGoalCompletion(goalID: goal.id)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(goal.title)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(WatchTheme.text)
                        .lineLimit(1)
                    Spacer()
                    radioIndicator(progress: goal.progress)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(WatchTheme.border)
                        Capsule()
                            .fill(barColor(for: goal))
                            .frame(width: geo.size.width * max(0, min(1, goal.progress)))
                    }
                }
                .frame(height: 3)

                Text(progressLabel(goal.progress))
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(WatchTheme.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(WatchTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(goal.progress >= 1.0)
    }

    // MARK: - Radio button indicator

    @ViewBuilder
    private func radioIndicator(progress: Double) -> some View {
        if progress >= 1.0 {
            ZStack {
                Circle().fill(WatchTheme.teal).frame(width: 16, height: 16)
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
            }
        } else if progress > 0 {
            ZStack {
                Circle()
                    .stroke(WatchTheme.teal, lineWidth: 1.5)
                    .frame(width: 16, height: 16)
                Circle().fill(WatchTheme.teal).frame(width: 8, height: 8)
            }
        } else {
            Circle()
                .stroke(WatchTheme.border, lineWidth: 1.5)
                .frame(width: 16, height: 16)
        }
    }

    // MARK: - Helpers

    private func barColor(for goal: GoalSummary) -> Color {
        switch goal.goalCategory {
        case .water:                    return WatchTheme.teal
        case .exercise, .fitness:       return WatchTheme.coral
        case .study, .learning:         return WatchTheme.yellow
        case .mindfulness:              return WatchTheme.lavender
        default:                        return WatchTheme.teal
        }
    }

    private func progressLabel(_ progress: Double) -> String {
        if progress <= 0 { return "Not started" }
        if progress >= 1 { return "Complete!" }
        return "\(Int(progress * 100))% done"
    }
}
