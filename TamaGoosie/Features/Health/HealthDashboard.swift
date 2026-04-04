import SwiftUI
import SwiftData

struct HealthDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gooseStates: [GooseState]
    @Query private var profiles: [UserProfile]
    @Query(sort: \DailyLog.date, order: .reverse) private var allDailyLogs: [DailyLog]
    @State private var healthManager = HealthKitManager.shared
    @State private var snapshot: HealthSnapshot?
    @State private var isLoading = false

    private var gooseState: GooseState? { gooseStates.first }
    private var profile: UserProfile? { profiles.first }
    private var todayLog: DailyLog? {
        allDailyLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Text("Health")
                        .font(GoosieTheme.titleFont(28))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, GoosieTheme.padding)

                    if !healthManager.isAuthorized {
                        permissionCard
                    } else if isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if let snapshot {
                        statsGrid(snapshot)
                        impactSection(snapshot)
                    }
                }
                .padding(.vertical)
            }
        }
        .task {
            if healthManager.isAuthorized {
                await loadHealthData()
            }
        }
    }

    // MARK: - Permission Card

    private var permissionCard: some View {
        GoosieCard {
            VStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(GoosieTheme.coralAccent)

                Text("Connect Health Data")
                    .font(GoosieTheme.bodyFont(18))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Text("Your goose gets healthier when you do! Connect Apple Health to reward your real-life habits.")
                    .font(GoosieTheme.captionFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                    .multilineTextAlignment(.center)

                PillButton(title: "Connect", icon: "heart.fill", color: GoosieTheme.coralAccent) {
                    Task {
                        try? await healthManager.requestAuthorization()
                        await loadHealthData()
                    }
                }
            }
        }
        .padding(.horizontal, GoosieTheme.padding)
    }

    // MARK: - Stats Grid

    private func statsGrid(_ snapshot: HealthSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statTile("Steps", value: "\(snapshot.steps)", icon: "figure.walk", color: GoosieTheme.coralAccent)
            statTile("Sleep", value: String(format: "%.1fh", snapshot.sleepHours), icon: "moon.fill", color: GoosieTheme.skyBlue)
            statTile("Exercise", value: "\(Int(snapshot.exerciseMinutes))m", icon: "figure.run", color: GoosieTheme.warmOrange)
            statTile("Calories", value: "\(Int(snapshot.activeCalories))", icon: "flame.fill", color: GoosieTheme.happinessYellow)
        }
        .padding(.horizontal, GoosieTheme.padding)
    }

    private func statTile(_ label: String, value: String, icon: String, color: Color) -> some View {
        GoosieCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)

                Text(value)
                    .font(GoosieTheme.titleFont(22))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Text(label)
                    .font(GoosieTheme.captionFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Impact Section

    private func impactSection(_ snapshot: HealthSnapshot) -> some View {
        GoosieCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Impact on \(gooseState?.name ?? "Goose")")
                    .font(GoosieTheme.bodyFont(16))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                if snapshot.steps >= GoosieConstants.stepsThreshold {
                    impactRow(icon: "figure.walk", text: "Amazing steps today!", delta: "+5% Healthiness")
                }

                if snapshot.sleepHours >= GoosieConstants.sleepBonusMin && snapshot.sleepHours <= GoosieConstants.sleepBonusMax {
                    impactRow(icon: "moon.fill", text: "Great sleep!", delta: "+5% Healthiness")
                } else if snapshot.sleepHours < GoosieConstants.sleepPenaltyBelow && snapshot.sleepHours > 0 {
                    impactRow(icon: "moon.fill", text: "Need more sleep", delta: "-10% Healthiness")
                }

                if snapshot.exerciseMinutes >= GoosieConstants.exerciseThresholdMinutes {
                    impactRow(icon: "figure.run", text: "Workout complete!", delta: "+8% Healthiness")
                }
            }
        }
        .padding(.horizontal, GoosieTheme.padding)
    }

    private func impactRow(icon: String, text: String, delta: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(GoosieTheme.coralAccent)
            Text(text)
                .font(GoosieTheme.captionFont())
                .foregroundStyle(GoosieTheme.charcoalOutline)
            Spacer()
            Text(delta)
                .font(GoosieTheme.captionFont(12))
                .foregroundStyle(delta.hasPrefix("-") ? GoosieTheme.coralAccent : GoosieTheme.happinessYellow)
        }
    }

    // MARK: - Data Loading

    private func loadHealthData() async {
        isLoading = true
        defer { isLoading = false }

        if let data = try? await healthManager.fetchTodayStats() {
            snapshot = data
            if let state = gooseState {
                // Write health data to today's DailyLog so computeHealthiness can use it
                let log = todayLog ?? {
                    let newLog = DailyLog(date: .now)
                    modelContext.insert(newLog)
                    return newLog
                }()
                log.steps = data.steps
                log.exerciseMinutes = Int(data.exerciseMinutes)
                log.sleepHours = data.sleepHours
                log.standHours = data.standHours

                GooseEngine.shared.update(state: state, log: log, profile: profile, goals: [])
                data.wasProcessed = true
            }
        }
    }
}
