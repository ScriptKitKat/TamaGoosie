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

    var onMenuTap: (() -> Void)?

    private var gooseState: GooseState {
        gooseStates.first ?? GooseState()
    }

    private var activeGoals: [Goal] { allGoals.filter { $0.isActive } }

    private var todayLog: DailyLog? {
        allDailyLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, GoosieTheme.padding)
                    .padding(.top, 8)

                Spacer()

                // Goose content group — mood, character, name
                VStack(spacing: 0) {
                    moodLabel
                        .padding(.bottom, 12)

                    GooseCharacterView(
                        mood: viewModel.mood,
                        showReaction: viewModel.currentReaction,
                        healthiness: viewModel.healthinessPercent,
                        happiness: viewModel.happinessPercent
                    )
                    .frame(maxWidth: 240, maxHeight: 240)
                    .frame(maxWidth: .infinity)

                    gooseNameLabel
                        .padding(.top, 12)
                }

                Spacer()

                statBars
                    .padding(.horizontal, GoosieTheme.padding)
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            ensureGooseExists()
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
        ZStack {
            // Goals + Streak centered together
            HStack(spacing: 16) {
                GoalProgressRing(
                    progress: viewModel.goalProgress,
                    completed: viewModel.completedGoalsCount,
                    total: viewModel.totalGoalsCount
                )

                StreakFlame(days: viewModel.streakDays)
                    .frame(minWidth: 40)
            }

            HStack(spacing: 0) {
                // Hamburger menu
                Button {
                    onMenuTap?()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
                        .frame(width: 34, height: 34)
                }

                Spacer()

                // Coins
                ZStack(alignment: .top) {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(GoosieTheme.sunYellow)
                        Text("\(viewModel.coins)")
                            .font(GoosieTheme.bodyFont(14))
                            .foregroundStyle(GoosieTheme.charcoalOutline)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: viewModel.coins)
                        Button {
                            // Points action placeholder
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                        }
                    }

                    if let amount = coinAnimationAmount {
                        CoinAnimationView(amount: amount) {
                            coinAnimationAmount = nil
                        }
                        .offset(y: -8)
                    }
                }
            }
        }
    }

    // MARK: - Mood Label

    private var moodLabel: some View {
        Text(viewModel.moodText)
            .font(GoosieTheme.titleFont(26))
            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.8))
    }

    // MARK: - Goose Name

    private var gooseNameLabel: some View {
        Text(viewModel.gooseName)
            .font(GoosieTheme.titleFont(22))
            .foregroundStyle(GoosieTheme.charcoalOutline)
    }

    // MARK: - Stat Bars

    private var statBars: some View {
        VStack(spacing: 10) {
            StatBar(label: "Health", icon: "heart.fill", value: viewModel.healthinessPercent, color: GoosieTheme.healthRed)
            StatBar(label: "Happiness", icon: "face.smiling.fill", value: viewModel.happinessPercent, color: GoosieTheme.happinessYellow)
        }
    }

    // MARK: - Helpers

    private func ensureGooseExists() {
        if gooseStates.isEmpty {
            let newGoose = GooseState()
            modelContext.insert(newGoose)
        }
    }

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
