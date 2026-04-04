import SwiftUI

struct GooseGlanceView: View {
    @State private var syncService = WatchSyncReceiver.shared

    private var payload: GooseSyncPayload { syncService.currentPayload }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // MARK: - Glance (screen 1)
                glanceSection

                // MARK: - Goals (scroll down)
                goalsSection

                // MARK: - Stats (scroll further)
                statsSection
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)
            .padding(.bottom, 10)
        }
        .background(WatchTheme.cream)
        .navigationTitle("")
    }

    // MARK: - Glance section

    private var glanceSection: some View {
        VStack(spacing: 4) {
            doubleRing

            VStack(spacing: 1) {
                Text(payload.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(WatchTheme.text)
                Text(payload.moodEnum.displayName.lowercased())
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(WatchTheme.textSecondary)
            }

            HStack(spacing: 10) {
                miniStatBar("Health", value: payload.healthiness, color: WatchTheme.teal)
                miniStatBar("Happy",  value: payload.happiness,   color: WatchTheme.coral)
            }
            .padding(.horizontal, 6)
        }
    }

    // MARK: - Goals section

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today's goals")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(WatchTheme.text)
                .frame(maxWidth: .infinity, alignment: .center)

            if syncService.activeGoals.isEmpty {
                Text("No active goals")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(WatchTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(syncService.activeGoals.prefix(5)) { goal in
                    goalCard(goal)
                }
            }
        }
    }

    // MARK: - Stats section

    private var statsSection: some View {
        VStack(spacing: 0) {
            Text("Today")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(WatchTheme.text)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)

            VStack(spacing: 8) {
                statRow(dot: WatchTheme.stepsBlue, label: "Steps",
                        value: payload.steps.formatted(),
                        valueColor: WatchTheme.stepsBlue,
                        fraction: Double(payload.steps) / 10_000)
                statRow(dot: WatchTheme.coral, label: "Exercise",
                        value: "\(payload.exerciseMinutes) min",
                        valueColor: WatchTheme.exerciseDark,
                        fraction: Double(payload.exerciseMinutes) / 30)
                statRow(dot: WatchTheme.sleepPurple, label: "Sleep",
                        value: String(format: "%.1f hr", payload.sleepHours),
                        valueColor: WatchTheme.sleepPurpleDark,
                        fraction: payload.sleepHours / 9.0)
                statRow(dot: WatchTheme.teal, label: "Stand",
                        value: "\(payload.standHours) hr",
                        valueColor: WatchTheme.standDark,
                        fraction: Double(payload.standHours) / 12)
            }
        }
    }

    // MARK: - Double ring

    private var doubleRing: some View {
        ZStack {
            Circle()
                .stroke(WatchTheme.border, lineWidth: 5)
                .frame(width: 84, height: 84)
            Circle()
                .trim(from: 0, to: payload.healthiness)
                .stroke(WatchTheme.teal, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 84, height: 84)
                .rotationEffect(.degrees(-90))

            Circle()
                .stroke(WatchTheme.border, lineWidth: 4)
                .frame(width: 68, height: 68)
            Circle()
                .trim(from: 0, to: payload.happiness)
                .stroke(WatchTheme.coral, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 68, height: 68)
                .rotationEffect(.degrees(-90))

            DuckFaceView(size: 30)
        }
        .frame(width: 84, height: 84)
    }

    // MARK: - Mini stat bar

    private func miniStatBar(_ label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(WatchTheme.textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(WatchTheme.border)
                    Capsule().fill(color)
                        .frame(width: geo.size.width * max(0, min(1, value)))
                }
            }
            .frame(height: 3)
        }
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

    // MARK: - Stat row

    private func statRow(dot: Color, label: String, value: String, valueColor: Color, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Circle().fill(dot).frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(WatchTheme.text)
                Spacer()
                Text(value)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(valueColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(WatchTheme.border)
                    Capsule().fill(dot)
                        .frame(width: geo.size.width * max(0, min(1, fraction)))
                }
            }
            .frame(height: 3)
        }
    }

    // MARK: - Helpers

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
                Circle().stroke(WatchTheme.teal, lineWidth: 1.5).frame(width: 16, height: 16)
                Circle().fill(WatchTheme.teal).frame(width: 8, height: 8)
            }
        } else {
            Circle().stroke(WatchTheme.border, lineWidth: 1.5).frame(width: 16, height: 16)
        }
    }

    private func barColor(for goal: GoalSummary) -> Color {
        switch goal.goalCategory {
        case .water:              return WatchTheme.teal
        case .exercise, .fitness: return WatchTheme.coral
        case .study, .learning:   return WatchTheme.yellow
        case .mindfulness:        return WatchTheme.lavender
        default:                  return WatchTheme.teal
        }
    }

    private func progressLabel(_ progress: Double) -> String {
        if progress <= 0 { return "Not started" }
        if progress >= 1 { return "Complete!" }
        return "\(Int(progress * 100))% done"
    }
}
