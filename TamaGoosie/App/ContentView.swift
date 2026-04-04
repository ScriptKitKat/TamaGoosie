import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @Query private var goals: [Goal]
    @Query private var gooseStates: [GooseState]
    @EnvironmentObject private var notificationDelegate: AppNotificationDelegate
    @State private var selectedTab = 0
    @State private var showOnboarding = false

    var body: some View {
        mainTabView
            .onAppear {
                if profiles.first?.hasCompletedOnboarding != true {
                    showOnboarding = true
                }
                WatchSyncService.shared.activate()
                HealthKitManager.shared.enableBackgroundDelivery()
                scheduleNotifications()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    processScreenTimeEvents()
                }
            }
            .onChange(of: goals.count) { _, _ in
                scheduleNotifications()
            }
            .sheet(item: $notificationDelegate.pendingNegotiation) { negotiation in
                NegotiationView(negotiation: negotiation)
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingContainerView { showOnboarding = false }
            }
    }

    private func scheduleNotifications() {
        let activeGoals = goals.filter { $0.isActive }
        let gooseName = gooseStates.first?.name ?? "your goose"
        Task {
            await GooseNotificationSystem.shared.rescheduleAll(goals: activeGoals, gooseName: gooseName)
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            GooseView()
                .tabItem {
                    Image(systemName: "bird.fill")
                    Text("Goose")
                }
                .tag(0)

            GoalListView()
                .tabItem {
                    Image(systemName: "checklist")
                    Text("Goals")
                }
                .tag(1)

            FocusSessionView()
                .tabItem {
                    Image(systemName: "timer")
                    Text("Focus")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(3)
        }
        .tint(GoosieTheme.coralAccent)
    }

    // MARK: - Screen Time Event Processing

    private func processScreenTimeEvents() {
        guard let state = gooseStates.first, !state.isDead else { return }
        let approxMinutes = ScreenTimeManager.shared.approxMinutesToday
        guard approxMinutes > 0 else { return }

        let log = fetchOrCreateTodayLog()
        log.distractionMinutes = max(log.distractionMinutes, approxMinutes)
        GooseEngine.shared.updateDistractMinutes(log.distractionMinutes)

        let defaults = UserDefaults(suiteName: GoosieConstants.appGroupID)!
        let lastPenalized = defaults.integer(forKey: GoosieConstants.screenTimeLastPenaltyMinutesKey)
        guard approxMinutes > lastPenalized else { return }

        let deltaMinutes = approxMinutes - lastPenalized
        let penaltyMultiplier = Double(deltaMinutes) / 30.0
        let penalty = RewardEngine.StatDelta(
            happiness: -GoosieConstants.distractionOpenPenalty * penaltyMultiplier
        )
        RewardEngine.applyDelta(penalty, to: state)
        GooseEngine.shared.update(state: state)

        defaults.set(approxMinutes, forKey: GoosieConstants.screenTimeLastPenaltyMinutesKey)
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
