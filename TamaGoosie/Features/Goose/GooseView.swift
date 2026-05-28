import SwiftUI
import SwiftData

struct GooseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gooseStates: [GooseState]
    @Query(sort: \Goal.sortOrder) private var allGoals: [Goal]
    @Query private var profiles: [UserProfile]
    @Query(sort: \DailyLog.date, order: .reverse) private var allDailyLogs: [DailyLog]

    @State private var viewModel = GooseViewModel()
    @State private var coinAnimationAmount: Int? = nil

    private var gooseState: GooseState {
        gooseStates.first ?? GooseState()
    }

    private var activeGoals: [Goal] { allGoals.filter { $0.isActive } }

    private var todayLog: DailyLog? {
        allDailyLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var profile: UserProfile? { profiles.first }

    private var equippedAccessories: [GooseAccessory] {
        var result: [GooseAccessory] = []
        if let hatID = gooseState.hatID, let acc = AccessoryCatalog.find(hatID) {
            result.append(acc)
        }
        return result
    }

    var body: some View {
        ZStack {
            GrassyBackgroundView()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, GoosieTheme.padding)
                    .padding(.top, 8)

                Spacer()

                // Goose content group — name, character, mood
                VStack(spacing: 0) {
                    gooseNameLabel
                        .padding(.bottom, 12)

                    GooseCharacterView(
                        mood: viewModel.mood,
                        showReaction: viewModel.currentReaction,
                        healthiness: viewModel.healthinessPercent,
                        happiness: viewModel.happinessPercent,
                        equippedAccessories: equippedAccessories
                    )
                    .frame(maxWidth: 240, maxHeight: 240)
                    .frame(maxWidth: .infinity)

                    moodLabel
                        .padding(.top, 8)
                }

                Spacer()

                statBars
                    .padding(.horizontal, GoosieTheme.padding)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            snapshotYesterdayIfNeeded()
            let log = ensureTodayLogExists()
            viewModel.onAppear(state: gooseState, log: log, profile: profile, goals: activeGoals)
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: gooseStates) { _, newStates in
            if let state = newStates.first {
                viewModel.updateState(state)
            }
        }
        .onChange(of: allDailyLogs) { _, _ in
            viewModel.updateContext(log: todayLog, profile: profile, goals: activeGoals)
        }
        .onChange(of: allGoals) { _, _ in
            viewModel.updateContext(log: todayLog, profile: profile, goals: activeGoals)
        }
        .onChange(of: GooseEngine.shared.lastCoinEarn) { _, earned in
            if earned > 0 {
                coinAnimationAmount = earned
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Goals + Streak combined badge
            GoalStreakBadge(
                progress: viewModel.goalProgress,
                completed: viewModel.completedGoalsCount,
                total: viewModel.totalGoalsCount,
                streakDays: viewModel.streakDays
            )

            Spacer()

            // Coins in parallelogram
            ZStack(alignment: .top) {
                HStack(spacing: 5) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: 0xF5A623))
                    Text("\(viewModel.coins)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black.opacity(0.7))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: viewModel.coins)
                    Button {
                        // Points action placeholder
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.black.opacity(0.3))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedParallelogram(skew: 8)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
                )

                if let amount = coinAnimationAmount {
                    CoinAnimationView(amount: amount) {
                        coinAnimationAmount = nil
                    }
                    .offset(y: -8)
                }
            }
        }
    }

    // MARK: - Mood Label

    private var moodLabel: some View {
        Text(viewModel.moodText)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))
    }

    // MARK: - Goose Name

    private var gooseNameLabel: some View {
        Text(viewModel.gooseName)
            .font(GoosieTheme.titleFont(28))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }

    // MARK: - Stat Bars

    private var statBars: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Health
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(GoosieTheme.healthRed)
                    Text("Health")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black.opacity(0.6))
                }
                StatBar(label: "Health", icon: "heart.fill", value: viewModel.healthinessPercent, color: GoosieTheme.healthRed)
            }

            // Happiness
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "face.smiling.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(GoosieTheme.happinessYellow)
                    Text("Happiness")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black.opacity(0.6))
                }
                StatBar(label: "Happiness", icon: "face.smiling.fill", value: viewModel.happinessPercent, color: GoosieTheme.happinessYellow)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
        )
    }

    // MARK: - Helpers

    @discardableResult
    private func ensureTodayLogExists() -> DailyLog {
        if let existing = todayLog { return existing }
        let log = DailyLog(date: .now)
        modelContext.insert(log)
        return log
    }

    private func snapshotYesterdayIfNeeded() {
        let calendar = Calendar.current
        let yesterdayLog = allDailyLogs.first {
            calendar.isDateInYesterday($0.date)
        }
        if let yesterdayLog {
            GooseEngine.shared.snapshotEndOfDay(state: gooseState, yesterdayLog: yesterdayLog)
        }
    }
}
