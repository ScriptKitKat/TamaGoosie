import SwiftUI
import SwiftData

struct HealthDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gooseStates: [GooseState]
    @Query(sort: \Goal.sortOrder) private var allGoals: [Goal]
    @State private var healthManager = HealthKitManager.shared
    @State private var snapshot: HealthSnapshot?
    @State private var isLoading = false

    private var gooseState: GooseState? {
        gooseStates.first
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
            let log = fetchOrCreateTodayLog()
            if let state = gooseState, !data.wasProcessed {
                GooseEngine.shared.processHealthData(
                    steps: data.steps,
                    exerciseMinutes: data.exerciseMinutes,
                    sleepHours: data.sleepHours,
                    activeCalories: data.activeCalories,
                    standHours: data.standHours,
                    state: state,
                    dailyLog: log
                )
                data.wasProcessed = true
            } else {
                // Already processed rewards; just refresh the cache + DailyLog
                GooseEngine.shared.refreshHealthCache(
                    steps: data.steps,
                    exerciseMinutes: data.exerciseMinutes,
                    sleepHours: data.sleepHours,
                    activeCalories: data.activeCalories,
                    standHours: data.standHours,
                    dailyLog: log
                )
            }
            GooseEngine.shared.syncBuiltinGoalProgress(allGoals)
        }
    }

    private func fetchOrCreateTodayLog() -> DailyLog {
        let today = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.date == today })
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let log = DailyLog(date: .now)
        modelContext.insert(log)
        return log
    }
}
