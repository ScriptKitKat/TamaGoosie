import SwiftUI

struct GooseGlanceView: View {
    @State private var syncService = WatchSyncReceiver.shared

    private var payload: GooseSyncPayload { syncService.currentPayload }

    // Map mood to the same goose image used on iOS
    private var gooseImageName: String {
        let mood = payload.moodEnum
        let h = payload.happiness
        let hp = payload.healthiness
        // Mirror GooseDisplayState logic from iOS GooseAnimations
        if h >= 0.70 && hp >= 0.70 { return "goose_happy" }
        if h < 0.40 || hp < 0.40 { return "goose_tired" }
        return "goose_normal"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // MARK: - Goose character
                gooseSection

                // MARK: - Stat bars
                statBarsSection

                // MARK: - Goals
                goalsSection

                // MARK: - Health stats
                healthStatsSection
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)
            .padding(.bottom, 10)
        }
        .background(WatchTheme.mintBackground)
        .navigationTitle("")
    }

    // MARK: - Goose Section

    private var gooseSection: some View {
        VStack(spacing: 4) {
            Image(gooseImageName)
                .resizable()
                .scaledToFit()
                .frame(height: 80)

            Text(payload.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.charcoal)

            Text(payload.moodEnum.displayName)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(WatchTheme.charcoal.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(WatchTheme.creamWhite))

            if payload.streakDays > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(WatchTheme.warmOrange)
                    Text("\(payload.streakDays)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(WatchTheme.charcoal)
                }
            }
        }
    }

    // MARK: - Stat Bars (Health & Happiness - matching iOS)

    private var statBarsSection: some View {
        VStack(spacing: 6) {
            watchStatBar(
                label: "Health",
                icon: "heart.fill",
                value: payload.healthiness,
                color: WatchTheme.healthRed
            )
            watchStatBar(
                label: "Happy",
                icon: "face.smiling.fill",
                value: payload.happiness,
                color: WatchTheme.happinessYellow
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(WatchTheme.creamWhite)
        )
    }

    private func watchStatBar(label: String, icon: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(WatchTheme.charcoal)
                .frame(width: 36, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.2))
                    Capsule().fill(color)
                        .frame(width: max(0, geo.size.width * max(0, min(1, value))))
                }
            }
            .frame(height: 6)

            Text("\(Int(value * 100))")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(WatchTheme.charcoal.opacity(0.6))
                .frame(width: 20, alignment: .trailing)
        }
    }

    // MARK: - Goals Section

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Goals")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(WatchTheme.charcoal)
                .frame(maxWidth: .infinity, alignment: .center)

            if syncService.activeGoals.isEmpty {
                Text("No active goals")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(WatchTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            } else {
                ForEach(syncService.activeGoals.prefix(5)) { goal in
                    goalCard(goal)
                }
            }
        }
    }

    // MARK: - Health Stats Section

    private var healthStatsSection: some View {
        VStack(spacing: 6) {
            Text("Today")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(WatchTheme.charcoal)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 6) {
                healthRow(dot: WatchTheme.stepsBlue, label: "Steps",
                          value: payload.steps.formatted(),
                          fraction: Double(payload.steps) / 10_000)
                healthRow(dot: WatchTheme.coral, label: "Exercise",
                          value: "\(payload.exerciseMinutes) min",
                          fraction: Double(payload.exerciseMinutes) / 30)
                healthRow(dot: WatchTheme.sleepPurple, label: "Sleep",
                          value: String(format: "%.1f hr", payload.sleepHours),
                          fraction: payload.sleepHours / 9.0)
                healthRow(dot: WatchTheme.sunYellow, label: "Outside",
                          value: "\(payload.outsideMinutes) min",
                          fraction: Double(payload.outsideMinutes) / 30)
                healthRow(dot: WatchTheme.teal, label: "Stand",
                          value: "\(payload.standHours) hr",
                          fraction: Double(payload.standHours) / 12)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(WatchTheme.creamWhite)
        )
    }

    private func healthRow(dot: Color, label: String, value: String, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Circle().fill(dot).frame(width: 5, height: 5)
                Text(label)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(WatchTheme.charcoal)
                Spacer()
                Text(value)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(dot)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(dot.opacity(0.2))
                    Capsule().fill(dot)
                        .frame(width: geo.size.width * max(0, min(1, fraction)))
                }
            }
            .frame(height: 3)
        }
    }

    // MARK: - Goal Card

    private func goalCard(_ goal: GoalSummary) -> some View {
        Button {
            guard goal.progress < 1.0 else { return }
            syncService.sendGoalCompletion(goalID: goal.id)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(goal.title)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(WatchTheme.charcoal)
                        .lineLimit(1)
                    Spacer()
                    radioIndicator(progress: goal.progress)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(barColor(for: goal).opacity(0.2))
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
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(WatchTheme.creamWhite)
            )
        }
        .buttonStyle(.plain)
        .disabled(goal.progress >= 1.0)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func radioIndicator(progress: Double) -> some View {
        if progress >= 1.0 {
            ZStack {
                Circle().fill(WatchTheme.teal).frame(width: 14, height: 14)
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
            }
        } else if progress > 0 {
            ZStack {
                Circle().stroke(WatchTheme.teal, lineWidth: 1.5).frame(width: 14, height: 14)
                Circle().fill(WatchTheme.teal).frame(width: 7, height: 7)
            }
        } else {
            Circle().stroke(WatchTheme.border, lineWidth: 1.5).frame(width: 14, height: 14)
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
