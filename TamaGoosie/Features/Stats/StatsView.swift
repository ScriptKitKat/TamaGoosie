import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var gooseStates: [GooseState]

    private var profile: UserProfile? { profiles.first }

    private var gooseName: String { gooseStates.first?.name ?? "Harold" }

    private var provider: DailyLogHistoryProvider {
        DailyLogHistoryProvider(modelContext: modelContext)
    }

    private var hasEnoughData: Bool {
        provider.fetchPoints(range: .week).count >= 2
    }

    private var bestDayLog: DailyLog? {
        let points = provider.fetchPoints(range: .quarter)
        guard let bestPoint = points.max(by: {
            ($0.healthiness + $0.happiness) < ($1.healthiness + $1.happiness)
        }) else { return nil }

        let bestDate = bestPoint.date
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == bestDate }
        )
        return try? modelContext.fetch(descriptor).first
    }

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground.ignoresSafeArea()

            if hasEnoughData {
                ScrollView {
                    VStack(spacing: 16) {
                        DuckHistoryCard()

                        if let log = bestDayLog {
                            bestDayCard(log: log)
                        }

                        if let profile {
                            baselinesCard(profile: profile)
                        }
                    }
                    .padding(GoosieTheme.padding)
                }
            } else {
                emptyStateView
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.2))
            Text("\(gooseName) needs a few more days to show you trends")
                .font(GoosieTheme.bodyFont())
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Best Day Highlight

    private func bestDayCard(log: DailyLog) -> some View {
        GoosieCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(GoosieTheme.warmOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Best Day")
                            .font(GoosieTheme.bodyFont())
                            .foregroundStyle(GoosieTheme.charcoalOutline)
                        Text(log.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            .font(GoosieTheme.captionFont(12))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                    }
                    Spacer()
                }

                Divider()

                HStack(spacing: 12) {
                    scorePill(
                        label: "Health",
                        value: Int(log.endOfDayHealthiness * 100),
                        color: GoosieTheme.skyBlue
                    )
                    scorePill(
                        label: "Joy",
                        value: Int(log.endOfDayHappiness * 100),
                        color: GoosieTheme.sunYellow
                    )
                }

                let details: [(String, String, String)] = [
                    ("figure.walk", "\(log.steps)", "steps"),
                    ("heart.fill", "\(log.exerciseMinutes)min", "exercise"),
                    ("moon.fill", "\(String(format: "%.1f", log.sleepHours))h", "sleep"),
                    ("checklist", "\(log.goalsCompleted)/\(log.goalsTotal)", "goals"),
                ]

                HStack(spacing: 0) {
                    ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                        VStack(spacing: 4) {
                            Image(systemName: detail.0)
                                .font(.system(size: 11))
                                .foregroundStyle(GoosieTheme.coralAccent)
                            Text(detail.1)
                                .font(GoosieTheme.captionFont(12))
                                .fontWeight(.semibold)
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                            Text(detail.2)
                                .font(GoosieTheme.captionFont(10))
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.45))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func scorePill(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(GoosieTheme.captionFont(12))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
            Spacer()
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.1)))
    }

    // MARK: - Baselines Card

    private func baselinesCard(profile: UserProfile) -> some View {
        GoosieCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Baselines")
                    .font(GoosieTheme.bodyFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Text("Used to normalize your health scores. Auto-updates after 7 days of data.")
                    .font(GoosieTheme.captionFont(11))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

                Divider()

                baselineRow("Sleep", value: "\(String(format: "%.1f", profile.avgSleepHours))h", icon: "moon.fill")
                baselineRow("Steps", value: "\(profile.avgSteps)", icon: "figure.walk")
                baselineRow("Exercise", value: "\(profile.avgExerciseMinutes)min", icon: "heart.fill")
                baselineRow("Sitting", value: "\(String(format: "%.1f", profile.avgSittingHours))h", icon: "chair.lounge.fill")
            }
        }
    }

    private func baselineRow(_ label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(GoosieTheme.coralAccent)
                .frame(width: 16)
            Text(label)
                .font(GoosieTheme.captionFont())
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
            Spacer()
            Text(value)
                .font(GoosieTheme.captionFont())
                .fontWeight(.semibold)
                .foregroundStyle(GoosieTheme.charcoalOutline)
        }
    }
}
