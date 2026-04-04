import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @Query private var gooseStates: [GooseState]
    @Query(sort: \Goal.sortOrder) private var allGoals: [Goal]
    @StateObject private var watchSync = WatchSyncService.shared
    @State private var selectedTab = 0
    @State private var showOnboarding = false
    /// Tracks whether we've applied one-time health rewards this session
    @State private var healthProcessedThisSession = false

    var body: some View {
        mainTabView
            .onAppear {
                if profiles.first?.hasCompletedOnboarding != true {
                    showOnboarding = true
                } else {
                    HealthKitManager.shared.enableBackgroundDelivery()
                }
            }
            .task {
                guard profiles.first?.hasCompletedOnboarding == true else { return }
                await syncHealthData()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    guard profiles.first?.hasCompletedOnboarding == true else { return }
                    // processScreenTimeEvents()  // Screen time tracking removed
                    Task { await syncHealthData() }
                }
            }
            .onChange(of: showOnboarding) { _, isShowing in
                // After onboarding completes, kick off health sync
                if !isShowing {
                    HealthKitManager.shared.enableBackgroundDelivery()
                    Task { await syncHealthData() }
                }
            }
            .onChange(of: watchSync.isPaired) { _, paired in
                // Auto-sync watch pairing state to UserProfile
                if let profile = profiles.first {
                    profile.watchPaired = paired
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingContainerView { showOnboarding = false }
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

    // MARK: - HealthKit Auto-Sync

    private func syncHealthData() async {
        let hk = HealthKitManager.shared
        if !hk.isAuthorized {
            try? await hk.requestAuthorization()
        }
        guard hk.isAuthorized else { return }

        guard let state = gooseStates.first, !state.isDead else { return }
        guard let snapshot = try? await hk.fetchTodayStats() else { return }

        let log = fetchOrCreateTodayLog()

        if !healthProcessedThisSession {
            // First fetch this session: apply rewards
            GooseEngine.shared.processHealthData(
                steps: snapshot.steps,
                exerciseMinutes: snapshot.exerciseMinutes,
                sleepHours: snapshot.sleepHours,
                activeCalories: snapshot.activeCalories,
                standHours: snapshot.standHours,
                state: state,
                dailyLog: log
            )
            healthProcessedThisSession = true
        } else {
            // Subsequent fetches: just refresh the cache + DailyLog
            GooseEngine.shared.refreshHealthCache(
                steps: snapshot.steps,
                exerciseMinutes: snapshot.exerciseMinutes,
                sleepHours: snapshot.sleepHours,
                activeCalories: snapshot.activeCalories,
                standHours: snapshot.standHours,
                dailyLog: log
            )
        }

        // Update built-in goal progress from HealthKit values
        GooseEngine.shared.syncBuiltinGoalProgress(allGoals)
    }

    // MARK: - Screen Time Event Processing

    private func processScreenTimeEvents() {
        guard let state = gooseStates.first, !state.isDead else { return }
        let events = ScreenTimeManager.shared.consumePendingThresholdEvents()
        guard events > 0 else { return }

        let minutesAdded = events * GoosieConstants.screenTimeThresholdMinutes
        let log = fetchOrCreateTodayLog()
        log.distractionMinutes += minutesAdded
        GooseEngine.shared.updateDistractMinutes(log.distractionMinutes)

        let penalty = RewardEngine.penaltyForDistractionOpen()
        for _ in 0..<events {
            RewardEngine.applyDelta(penalty, to: state)
        }
        GooseEngine.shared.update(state: state)
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
