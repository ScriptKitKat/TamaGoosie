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
    @State private var showMenu = false
    /// Tracks whether we've applied one-time health rewards this session
    @State private var healthProcessedThisSession = false
    @State private var onboardingEntryPath: OnboardingEntryPath = .freshInstall

    private var hasCompletedOnboarding: Bool {
        profiles.first?.hasCompletedOnboarding == true
    }

    var body: some View {
        mainContentView
            .onAppear {
                if !hasCompletedOnboarding {
                    showOnboarding = true
                    onboardingEntryPath = .freshInstall
                } else if !AuthService.shared.isSignedIn {
                    // Path C: completed onboarding before but logged out
                    showOnboarding = true
                    onboardingEntryPath = .loggedOutReturn
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
                    onboardingEntryPath = .freshInstall
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
            .onChange(of: watchSync.isWatchPaired) { _, paired in
                profiles.first?.watchPaired = paired
            }
            .onChange(of: goals.count) { _, _ in
                scheduleNotifications()
            }
            .onChange(of: goals.map { $0.isCompleted }) { _, _ in
                scheduleNotifications()
            }
            .onReceive(NotificationCenter.default.publisher(for: .goalCompletedFromWatch)) { notification in
                handleWatchGoalCompletion(notification)
            }
            .sheet(item: $notificationDelegate.pendingNegotiation) { negotiation in
                NegotiationView(negotiation: negotiation)
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingContainerView(entryPath: onboardingEntryPath) { showOnboarding = false }
            }
    }

    private func scheduleNotifications() {
        let activeGoals = goals.filter { $0.isActive }
        let gooseName = gooseStates.first?.name ?? "your goose"
        Task {
            await GooseNotificationSystem.shared.rescheduleAll(goals: activeGoals, gooseName: gooseName)
        }
    }

    // MARK: - Menu Items

    private struct MenuItem: Identifiable {
        let id: Int
        let title: String
        let icon: String
        let isSystemImage: Bool

        init(id: Int, title: String, systemImage: String) {
            self.id = id
            self.title = title
            self.icon = systemImage
            self.isSystemImage = true
        }

        init(id: Int, title: String, assetImage: String) {
            self.id = id
            self.title = title
            self.icon = assetImage
            self.isSystemImage = false
        }
    }

    private var menuItems: [MenuItem] {
        [
            MenuItem(id: 0, title: "Goose", assetImage: "goose_icon"),
            MenuItem(id: 1, title: "Goals", systemImage: "checklist"),
            MenuItem(id: 2, title: "Chat", systemImage: "bubble.left.fill"),
            MenuItem(id: 3, title: "Friends", systemImage: "person.2.fill"),
            MenuItem(id: 4, title: "Stats", systemImage: "chart.line.uptrend.xyaxis"),
            MenuItem(id: 5, title: "Screen Time", systemImage: "hourglass"),
            MenuItem(id: 6, title: "Settings", systemImage: "gearshape.fill"),
        ]
    }

    // MARK: - Main Content

    private var mainContentView: some View {
        ZStack(alignment: .leading) {
            // Current page content with top bar overlay
            VStack(spacing: 0) {
                if selectedTab != 0 {
                    subpageHeader
                }
                currentPageView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .offset(x: showMenu ? 260 : 0)
            .disabled(showMenu)

            // Dimming overlay when menu is open
            if showMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .offset(x: 260)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showMenu = false
                        }
                    }
            }

            // Side menu
            sideMenu
                .frame(width: 260)
                .offset(x: showMenu ? 0 : -260)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 80 && !showMenu {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showMenu = true
                        }
                    } else if value.translation.width < -80 && showMenu {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showMenu = false
                        }
                    }
                }
        )
        .background(Self.subpageHeaderColor.ignoresSafeArea())
    }

    private var currentPageTitle: String {
        switch selectedTab {
        case 1: return "Goals"
        case 2: return "Chat"
        case 3: return "Friends"
        case 4: return "Stats"
        case 5: return "Screen Time"
        case 6: return "Settings"
        default: return ""
        }
    }

    private static let subpageHeaderColor = Color(
        UIColor(
            red: 1.0 * 0.96 + 0.04 * 0.91,
            green: 0.96 * 0.96 + 0.04 * 0.59,
            blue: 0.90 * 0.96 + 0.04 * 0.23,
            alpha: 1
        )
    )

    private var subpageHeader: some View {
        ZStack {
            Self.subpageHeaderColor

            Text(currentPageTitle)
                .font(GoosieTheme.titleFont(20))
                .foregroundStyle(GoosieTheme.charcoalOutline)

            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedTab = 0
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
                        .frame(width: 32, height: 32)
                }
                Spacer()
            }
            .padding(.horizontal, GoosieTheme.padding)
        }
        .frame(height: 44)
        .background(Self.subpageHeaderColor.ignoresSafeArea(edges: .top))
    }

    @ViewBuilder
    private var currentPageView: some View {
        switch selectedTab {
        case 0: GooseView(onMenuTap: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showMenu.toggle()
            }
        })
        case 1: GoalListView()
        case 2: ChatView()
        case 3: FriendsView()
        case 4: StatsView()
        case 5: ScreenTimePageView()
        case 6: SettingsView()
        default: GooseView()
        }
    }

    private var sideMenu: some View {
        ZStack {
            GoosieTheme.mintBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Image("goose_icon")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(GoosieTheme.charcoalOutline)

                    Text(gooseStates.first?.name ?? "Harold")
                        .font(GoosieTheme.titleFont(22))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 28)

                // Menu items
                ForEach(menuItems) { item in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = item.id
                            showMenu = false
                        }
                    } label: {
                        HStack(spacing: 16) {
                            Group {
                                if item.isSystemImage {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 20))
                                } else {
                                    Image(item.icon)
                                        .resizable()
                                        .frame(width: 22, height: 22)
                                }
                            }
                            .frame(width: 28)
                            .foregroundStyle(
                                selectedTab == item.id
                                    ? GoosieTheme.charcoalOutline
                                    : GoosieTheme.charcoalOutline.opacity(0.5)
                            )

                            Text(item.title)
                                .font(GoosieTheme.bodyFont())
                                .foregroundStyle(
                                    selectedTab == item.id
                                        ? GoosieTheme.charcoalOutline
                                        : GoosieTheme.charcoalOutline.opacity(0.5)
                                )

                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            selectedTab == item.id
                                ? GoosieTheme.creamWhite.opacity(0.4)
                                : Color.clear
                        )
                    }
                }

                Spacer()

                // Version footer
                Text("TamaGoosie v1.0")
                    .font(GoosieTheme.captionFont(11))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.35))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
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
                outsideMinutes: snapshot.outsideMinutes,
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
                outsideMinutes: snapshot.outsideMinutes,
                dailyLog: log
            )
        }

        GooseEngine.shared.syncBuiltinGoalProgress(allGoals)

        // Sync distraction minutes from Screen Time extension
        let stDefaults = UserDefaults(suiteName: GoosieConstants.appGroupID)
        let approxDistraction = stDefaults?.integer(forKey: GoosieConstants.screenTimeApproxMinutesKey) ?? 0
        if approxDistraction > log.distractionMinutes {
            log.distractionMinutes = approxDistraction
        }

        if let createdAt = gooseStates.first?.createdAt {
            Task {
                await GooseEngine.shared.backfillHistory(
                    createdAt: createdAt,
                    modelContext: modelContext,
                    profile: profiles.first,
                    goals: goals
                )

                // Sync snapshotted DailyLogs to Convex
                let descriptor = FetchDescriptor<DailyLog>(
                    sortBy: [SortDescriptor(\.date, order: .forward)]
                )
                if let logs = try? modelContext.fetch(descriptor) {
                    ConvexManager.shared.syncDailyLogs(logs: logs)
                }
            }
        }
    }

    // MARK: - Watch Goal Completion

    private func handleWatchGoalCompletion(_ notification: Foundation.Notification) {
        guard let goalID = notification.userInfo?["goalID"] as? UUID else { return }
        let replyHandler = notification.userInfo?["replyHandler"] as? ([String: Any]) -> Void

        guard let goal = goals.first(where: { $0.id == goalID }),
              !goal.isCompleted,
              let state = gooseStates.first else {
            replyHandler?([:])
            return
        }

        let log = fetchOrCreateTodayLog()
        GooseEngine.shared.completeGoal(goal, state: state, log: log, goals: goals)
        try? modelContext.save()

        // Send updated payload back to Watch
        let payload = state.toSyncPayload()
        if let data = try? JSONEncoder().encode(payload) {
            replyHandler?(["goosePayload": data])
        } else {
            replyHandler?([:])
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
