import SwiftUI
import SwiftData

// MARK: - Scroll Offset Preference

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    /// Attach to a ScrollView's content to report scroll offset to ContentView's header.
    func trackScrollOffset(coordinateSpace: String = "pageScroll") -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: ScrollOffsetKey.self,
                    value: geo.frame(in: .named(coordinateSpace)).minY
                )
            }
        )
    }
}

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
    @State private var onboardingEntryPath: OnboardingEntryPath = .freshInstall
    @State private var showMoreSheet = false
    @State private var moreSubPage: MorePage? = nil
    @State private var pageScrolledDown = false

    enum MorePage: String {
        case friends = "Friends"
        case stats = "Stats"
        case settings = "Settings"
    }

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

    // MARK: - Main Content

    private var mainContentView: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                ZStack(alignment: .bottom) {
                    currentPageView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .coordinateSpace(name: "pageScroll")
                        .onPreferenceChange(ScrollOffsetKey.self) { offset in
                            let scrolled = offset < -10
                            if scrolled != pageScrolledDown {
                                pageScrolledDown = scrolled
                            }
                        }

                    // Dimmed backdrop over content only (not tab bar)
                    if showMoreSheet {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea(edges: .top)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    showMoreSheet = false
                                }
                            }
                    }

                    // More popup anchored at bottom of content area
                    if showMoreSheet {
                        morePopup
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 8)
                    }
                }

                // Floating page header over the content
                if let title = pageTitle {
                    pageHeader(title: title)
                }
            }

            tabBar
        }
    }

    // MARK: - Page Header

    private var pageTitle: String? {
        if let morePage = moreSubPage {
            return morePage.rawValue
        }
        switch selectedTab {
        case 1: return "Goals"
        case 2: return "Screen Time"
        case 3: return "Store"
        case 4: return "Challenges"
        default: return nil
        }
    }

    private var usesLightBackground: Bool {
        moreSubPage != nil // Friends, Stats, Settings all use cream backgrounds
    }

    private func pageHeader(title: String) -> some View {
        VStack(spacing: 0) {
            if pageScrolledDown {
                (usesLightBackground
                    ? Color(hex: 0xFFF8F0).opacity(0.92)
                    : Color.black.opacity(0.35))
                .ignoresSafeArea(edges: .top)
            }

            ZStack {
                if pageScrolledDown {
                    (usesLightBackground
                        ? Color(hex: 0xFFF8F0).opacity(0.92)
                        : Color.black.opacity(0.35))
                }

                Text(title)
                    .font(GoosieTheme.titleFont(20))
                    .foregroundStyle(usesLightBackground ? GoosieTheme.charcoalOutline : .white)
                    .shadow(color: usesLightBackground ? .clear : .black.opacity(0.15), radius: 2, y: 1)
            }
            .frame(height: 44)
        }
        .animation(.easeInOut(duration: 0.2), value: pageScrolledDown)
    }

    // MARK: - Page Content

    @ViewBuilder
    private var currentPageView: some View {
        if let morePage = moreSubPage {
            switch morePage {
            case .friends: FriendsView()
            case .stats: StatsView()
            case .settings: SettingsView()
            }
        } else {
            switch selectedTab {
            case 0: GooseView()
            case 1: GoalListView()
            case 2: ScreenTimePageView()
            case 3: StoreView()
            case 4: ChallengesView()
            default: GooseView()
            }
        }
    }

    // MARK: - Tab Bar

    private struct TabItem: Identifiable {
        let id: Int
        let icon: String
    }

    private let tabs: [TabItem] = [
        TabItem(id: 0, icon: "house.fill"),
        TabItem(id: 1, icon: "checklist"),
        TabItem(id: 2, icon: "hourglass"),
        TabItem(id: 3, icon: "storefront.fill"),
        TabItem(id: 4, icon: "trophy.fill"),
        TabItem(id: 5, icon: "ellipsis"),
    ]

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    if tab.id == 5 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showMoreSheet.toggle()
                        }
                    } else {
                        withAnimation(.spring(response: 0.25)) {
                            showMoreSheet = false
                            moreSubPage = nil
                            selectedTab = tab.id
                            pageScrolledDown = false
                        }
                    }
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 22, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(
                            isTabActive(tab.id)
                                ? GoosieTheme.charcoalOutline
                                : GoosieTheme.charcoalOutline.opacity(0.35)
                        )
                        .background(
                            isTabActive(tab.id)
                                ? RoundedRectangle(cornerRadius: 12)
                                    .fill(GoosieTheme.charcoalOutline.opacity(0.08))
                                    .frame(width: 48, height: 36)
                                : nil
                        )
                }
            }
        }
        .padding(.bottom, 2)
        .background(
            VStack(spacing: 0) {
                Rectangle()
                    .fill(GoosieTheme.charcoalOutline.opacity(0.1))
                    .frame(height: 0.5)
                GoosieTheme.creamWhite
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func isTabActive(_ id: Int) -> Bool {
        if moreSubPage != nil || showMoreSheet { return id == 5 }
        return selectedTab == id
    }

    // MARK: - More Popup

    private var morePopup: some View {
        VStack(spacing: 0) {
            moreRow(icon: "person.2.fill", title: "Friends") {
                pageScrolledDown = false
                moreSubPage = .friends
            }

            Divider()
                .padding(.leading, 56)

            moreRow(icon: "chart.line.uptrend.xyaxis", title: "Stats") {
                pageScrolledDown = false
                moreSubPage = .stats
            }

            Divider()
                .padding(.leading, 56)

            moreRow(icon: "gearshape.fill", title: "Settings") {
                pageScrolledDown = false
                moreSubPage = .settings
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GoosieTheme.creamWhite)
                .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
        )
        .padding(.horizontal, 12)
    }

    private func moreRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showMoreSheet = false
                action()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                    .frame(width: 28)

                Text(title)
                    .font(GoosieTheme.bodyFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
        }
    }

    // MARK: - Identity Restoration & Convex Sync

    private func restoreIdentityIfNeeded() async {
        if !ConvexManager.shared.isAuthenticated {
            _ = await ConvexManager.shared.loadIdentity()
        }

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
