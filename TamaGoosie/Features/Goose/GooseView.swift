import SwiftUI
import SwiftData

struct GooseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gooseStates: [GooseState]
    @Query(sort: \Goal.sortOrder) private var allGoals: [Goal]
    @Query private var profiles: [UserProfile]
    @Query(sort: \DailyLog.date, order: .reverse) private var allDailyLogs: [DailyLog]

    @State private var viewModel = GooseViewModel()
    @State private var chatService = GooseChatService()
    @State private var goalViewModel = GoalViewModel()

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

            VStack(spacing: 12) {
                header
                    .padding(.horizontal, GoosieTheme.padding)

                GooseCharacterView(
                    mood: viewModel.mood,
                    showReaction: viewModel.currentReaction,
                    healthiness: viewModel.healthinessPercent,
                    happiness: viewModel.happinessPercent
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                moodLabel
                statBars
                    .padding(.horizontal, GoosieTheme.padding)

                GooseChatPanel(service: chatService) { draft in
                    goalViewModel.pendingDraft = draft
                    goalViewModel.editingGoal = nil
                    goalViewModel.showEditor = true
                }
                .frame(height: 248)
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $goalViewModel.showEditor) {
            GoalEditorView(existingGoal: goalViewModel.editingGoal, prefill: goalViewModel.pendingDraft)
        }
        .onAppear {
            ensureGooseExists()
            let log = ensureTodayLogExists()
            viewModel.onAppear(state: gooseState, log: log, profile: profile, goals: activeGoals)
            chatService.refreshAvailability()
            syncChatService()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: gooseStates) { _, newStates in
            if let state = newStates.first {
                viewModel.updateState(state)
                syncChatService()
            }
        }
        .onChange(of: allDailyLogs) { _, _ in
            viewModel.updateContext(log: todayLog, profile: profile, goals: activeGoals)
        }
        .onChange(of: allGoals) { _, _ in
            viewModel.updateContext(log: todayLog, profile: profile, goals: activeGoals)
            syncChatService()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(viewModel.gooseName)
                .font(GoosieTheme.titleFont(28))
                .foregroundStyle(GoosieTheme.charcoalOutline)

            Spacer()

            StreakFlame(days: viewModel.streakDays)
        }
        .padding(.top, 8)
    }

    // MARK: - Mood Label

    private var moodLabel: some View {
        Text(viewModel.moodText)
            .font(GoosieTheme.bodyFont(18))
            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(GoosieTheme.creamWhite)
            )
    }

    // MARK: - Stat Bars

    private var statBars: some View {
        GoosieCard {
            VStack(spacing: 12) {
                StatBar(label: "Health", icon: "heart.fill", value: viewModel.healthinessPercent, color: GoosieTheme.healthRed)
                StatBar(label: "Happy", icon: "face.smiling.fill", value: viewModel.happinessPercent, color: GoosieTheme.happinessYellow)
            }
        }
    }

    // MARK: - Helpers

    private func syncChatService() {
        chatService.configure(
            name: viewModel.gooseName,
            health: Int(viewModel.healthinessPercent),
            happiness: Int(viewModel.happinessPercent),
            streak: viewModel.streakDays,
            goals: activeGoals
        )
    }

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
}
