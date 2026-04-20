import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @Query private var goals: [Goal]
    @Query private var gooseStates: [GooseState]
    @EnvironmentObject private var notificationDelegate: AppNotificationDelegate
    @Query(sort: \Goal.sortOrder) private var allGoals: [Goal]
    @StateObject private var watchSync = WatchSyncService.shared
    @State private var selectedTab = 0
    @State private var showOnboarding = false
    /// Tracks whether we've applied one-time health rewards this session
    @State private var healthProcessedThisSession = false

    private var hasCompletedOnboarding: Bool {
        profiles.first?.hasCompletedOnboarding == true
    }

    var body: some View {
        mainTabView
            .onAppear {
                if !hasCompletedOnboarding {
                    showOnboarding = true
                } else {
                    HealthKitManager.shared.enableBackgroundDelivery()
                }
                scheduleNotifications()
            }
            .task {
                guard hasCompletedOnboarding else { return }
                await restoreIdentityIfNeeded()
                await syncHealthData()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    guard hasCompletedOnboarding else { return }
                    Task {
                        await restoreIdentityIfNeeded()
                        await syncHealthData()
                    }
                }
            }
            .onChange(of: hasCompletedOnboarding) { _, completed in
                if !completed {
                    showOnboarding = true
                }
            }
            .onChange(of: showOnboarding) { _, isShowing in
                if !isShowing {
                    selectedTab = 0
                    HealthKitManager.shared.enableBackgroundDelivery()
                    Task { await syncHealthData() }
                }
            }
            .onChange(of: goals.count) { _, _ in
                scheduleNotifications()
            }
            .onChange(of: goals.map { $0.isCompleted }) { _, _ in
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

            FriendsView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Friends")
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

    // MARK: - Identity Restoration & Convex Sync

    private func restoreIdentityIfNeeded() async {
        if !ConvexManager.shared.isAuthenticated {
            _ = await ConvexManager.shared.loadIdentity()
        }

        // Push current local stats to Convex immediately after identity is available.
        // This covers the case where HealthKit is unavailable or hasn't delivered data yet.
        if ConvexManager.shared.isAuthenticated, let state = gooseStates.first {
            GooseSyncService.shared.syncToConvex(
                happiness: state.happiness,
                healthiness: state.healthiness,
                mood: state.mood,
                gooseName: state.name,
                spriteID: state.spriteID,
                streakDays: state.streakDays
            )
        }
    }

    // MARK: - HealthKit Auto-Sync

    private func syncHealthData() async {
        let hk = HealthKitManager.shared
        if !hk.isAuthorized {
            try? await hk.requestAuthorization()
        }
        guard hk.isAuthorized else { return }

        guard let state = gooseStates.first else { return }
        guard let snapshot = try? await hk.fetchTodayStats() else { return }

        let log = fetchOrCreateTodayLog()

        if !healthProcessedThisSession {
            GooseEngine.shared.processHealthData(
                steps: snapshot.steps,
                exerciseMinutes: snapshot.exerciseMinutes,
                sleepHours: snapshot.sleepHours,
                activeCalories: snapshot.activeCalories,
                standHours: snapshot.standHours,
                state: state,
                dailyLog: log,
                profile: profiles.first,
                goals: goals
            )
            healthProcessedThisSession = true
        } else {
            GooseEngine.shared.refreshHealthCache(
                steps: snapshot.steps,
                exerciseMinutes: snapshot.exerciseMinutes,
                sleepHours: snapshot.sleepHours,
                activeCalories: snapshot.activeCalories,
                standHours: snapshot.standHours,
                dailyLog: log
            )
        }

        GooseEngine.shared.syncBuiltinGoalProgress(allGoals)
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
