import Foundation
import SwiftData
import Observation

@Observable
final class GooseEngine {
    static let shared = GooseEngine()

    private(set) var isUpdating = false

    /// Most recent coin earn amount — views observe this to trigger animation.
    private(set) var lastCoinEarn: Int = 0

    // Cached health data populated by processHealthData; included in every sync payload
    private(set) var cachedSteps: Int = 0
    private(set) var cachedExerciseMinutes: Int = 0
    private(set) var cachedSleepHours: Double = 0.0
    private(set) var cachedActiveCalories: Double = 0.0
    private(set) var cachedOutsideMinutes: Int = 0
    private var cachedStandHours: Int = 0
    // Cached distraction minutes updated by DistractionOverlay each minute
    private(set) var cachedDistractMinutes: Int = 0

    // Cached goals populated by refreshGoals(_:); included in every sync payload
    private var cachedTopGoals: [GoalSummary] = []

    private init() {}

    // MARK: - Core Update Loop

    func update(state: GooseState, log: DailyLog?, profile: UserProfile?, goals: [Goal]) {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        if let log, let profile {
            state.healthiness = RewardEngine.computeHealthiness(log: log, profile: profile)
        }
        if let log {
            state.happiness = RewardEngine.computeHappiness(log: log, goals: goals)
        }
        state.updateMood()
        state.lastUpdated = .now
        saveStatsToAppGroup(state.toSyncPayload())
    }

    // MARK: - Goal Completion

    /// Completes a goal and awards coins. Returns total coins earned for animation.
    @discardableResult
    func completeGoal(_ goal: Goal, state: GooseState, log: DailyLog?, goals: [Goal]) -> Int {
        goal.complete()

        // Immediately cancel all pending notifications for this goal so nothing stale fires.
        GooseNotificationSystem.shared.cancelGoalNotifications(for: goal.id)

        // Update goal streak — only extend when last completion was yesterday,
        // leave unchanged if already completed today, restart otherwise.
        if let lastDate = goal.lastCompletedDate {
            if Calendar.current.isDateInYesterday(lastDate) {
                goal.currentStreak += 1
            } else if !Calendar.current.isDateInToday(lastDate) {
                goal.currentStreak = 1
            }
            // Already completed today: streak stays the same.
        } else {
            goal.currentStreak = 1
        }

        // Sync goal counts in today's log
        if let log {
            log.goalsCompleted = goals.filter { $0.isActive && $0.isCompleted }.count
            log.goalsTotal = goals.filter { $0.isActive }.count
            state.happiness = RewardEngine.computeHappiness(log: log, goals: goals)
        }

        // Award coins
        var coinsEarned = GoosieConstants.coinsPerGoalCompletion

        // All active goals done bonus
        let activeGoals = goals.filter { $0.isActive }
        if !activeGoals.isEmpty && activeGoals.allSatisfy({ $0.isCompleted }) {
            coinsEarned += GoosieConstants.coinsPerAllGoalsDone
        }

        state.coins += coinsEarned
        lastCoinEarn = coinsEarned
        state.updateMood()
        saveStatsToAppGroup(state.toSyncPayload())

        return coinsEarned
    }

    // MARK: - Goal Uncompletion

    func uncompleteGoal(_ goal: Goal, state: GooseState, log: DailyLog?, goals: [Goal]) {
        guard goal.isCompleted, goal.type != "deadline" else { return }

        goal.currentCount = 0
        goal.isCompleted = false
        goal.completedAt = nil
        goal.currentStreak = max(0, goal.currentStreak - 1)

        // Sync goal counts in today's log
        if let log {
            log.goalsCompleted = goals.filter { $0.isActive && $0.isCompleted }.count
            log.goalsTotal = goals.filter { $0.isActive }.count
            state.happiness = RewardEngine.computeHappiness(log: log, goals: goals)
        }
        state.updateMood()
        saveStatsToAppGroup(state.toSyncPayload())
    }

    // MARK: - Health Data Processing

    func processHealthData(
        steps: Int,
        exerciseMinutes: Double,
        sleepHours: Double,
        activeCalories: Double = 0,
        standHours: Int = 0,
        outsideMinutes: Double = 0,
        state: GooseState,
        dailyLog: DailyLog? = nil,
        profile: UserProfile? = nil,
        goals: [Goal] = []
    ) {
        // Update cache + DailyLog
        refreshHealthCache(
            steps: steps,
            exerciseMinutes: exerciseMinutes,
            sleepHours: sleepHours,
            activeCalories: activeCalories,
            standHours: standHours,
            outsideMinutes: outsideMinutes,
            dailyLog: dailyLog
        )

        // Recompute stats from formulas
        update(state: state, log: dailyLog, profile: profile, goals: goals)
    }

    /// Update cached health values without recomputing stats (for subsequent fetches
    /// within the same day after the initial processing).
    func refreshHealthCache(
        steps: Int,
        exerciseMinutes: Double,
        sleepHours: Double,
        activeCalories: Double = 0,
        standHours: Int = 0,
        outsideMinutes: Double = 0,
        dailyLog: DailyLog? = nil
    ) {
        cachedSteps = steps
        cachedExerciseMinutes = Int(exerciseMinutes)
        cachedSleepHours = sleepHours
        cachedActiveCalories = activeCalories
        cachedOutsideMinutes = Int(outsideMinutes)
        cachedStandHours = standHours

        if let log = dailyLog {
            log.steps = steps
            log.exerciseMinutes = Int(exerciseMinutes)
            log.sleepHours = sleepHours
            log.standHours = standHours
            log.outsideMinutes = Int(outsideMinutes)
        }
    }

    /// Sync built-in goal currentCount from cached HealthKit values so progress
    /// persists across app restarts.
    func syncBuiltinGoalProgress(_ goals: [Goal]) {
        for goal in goals where goal.isHealthKitTracked && !goal.isCompleted {
            if goal.title.localizedCaseInsensitiveContains("steps") || goal.title.localizedCaseInsensitiveContains("walk") {
                goal.currentCount = min(cachedSteps, goal.targetCount)
            } else if goal.title.localizedCaseInsensitiveContains("sleep") {
                goal.currentCount = min(Int(cachedSleepHours), goal.targetCount)
            } else if goal.title.localizedCaseInsensitiveContains("exercise") {
                goal.currentCount = min(cachedExerciseMinutes, goal.targetCount)
            } else if goal.title.localizedCaseInsensitiveContains("outside") || goal.title.localizedCaseInsensitiveContains("daylight") {
                goal.currentCount = min(cachedOutsideMinutes, goal.targetCount)
            }
        }
    }

    // MARK: - Reset

    func resetGoose(state: GooseState) {
        state.healthiness = 0.8
        state.happiness = 0.7
        state.coins = 0
        state.streakDays = 0
        state.lastStreakDate = nil
        state.createdAt = .now
        state.lastUpdated = .now
        state.updateMood()
        saveStatsToAppGroup(state.toSyncPayload())
    }

    // MARK: - History Backfill

    /// Backfills DailyLog records from `createdAt` to yesterday using real HealthKit data.
    /// Only fills days on or after the goose was created (no pre-install data).
    /// Skips any day that already has a non-zero endOfDayHealthiness snapshot.
    func backfillHistory(createdAt: Date, modelContext: ModelContext, profile: UserProfile?, goals: [Goal]) async {
        guard HealthKitManager.shared.isAuthorized else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let earliest = calendar.startOfDay(for: createdAt)

        // Calculate how many days back we can go (capped at createdAt)
        let maxDaysBack = calendar.dateComponents([.day], from: earliest, to: today).day ?? 0
        guard maxDaysBack > 0 else { return }

        for offset in 1...maxDaysBack {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            // Never backfill before the app was installed
            guard date >= earliest else { break }

            // Fetch or create the log for this date
            let descriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.date == date })
            let existing = try? modelContext.fetch(descriptor)
            let log: DailyLog

            if let found = existing?.first {
                // Skip days already snapshotted
                guard found.endOfDayHealthiness == 0 && found.endOfDayHappiness == 0 else { continue }
                log = found
            } else {
                log = DailyLog(date: date)
                modelContext.insert(log)
            }

            // Fetch real HealthKit data for this day
            guard let snapshot = try? await HealthKitManager.shared.fetchStats(for: date) else { continue }
            log.steps = snapshot.steps
            log.exerciseMinutes = Int(snapshot.exerciseMinutes)
            log.sleepHours = snapshot.sleepHours
            log.standHours = snapshot.standHours

            // Compute and store end-of-day scores
            if let profile {
                log.endOfDayHealthiness = RewardEngine.computeHealthiness(log: log, profile: profile)
            }
            log.endOfDayHappiness = RewardEngine.computeHappiness(log: log, goals: goals)
        }
    }

    // MARK: - End-of-Day Snapshot

    /// Snapshots current goose stats into yesterday's DailyLog.
    /// Call once when a new day is detected (e.g. on app launch before resetDailyGoals).
    func snapshotEndOfDay(state: GooseState, yesterdayLog: DailyLog) {
        guard yesterdayLog.endOfDayHealthiness == 0 && yesterdayLog.endOfDayHappiness == 0 else { return }
        yesterdayLog.endOfDayHealthiness = state.healthiness
        yesterdayLog.endOfDayHappiness = state.happiness
    }

    // MARK: - Streak Management

    /// Updates daily streak and awards milestone coins. Returns coins earned (0 or milestone amount).
    @discardableResult
    func updateDailyStreak(state: GooseState, goalsCompletedToday: Int, totalGoalsToday: Int) -> Int {
        let completionRate = totalGoalsToday > 0 ? Double(goalsCompletedToday) / Double(totalGoalsToday) : 0
        let previousStreak = state.streakDays
        var coinsEarned = 0

        if completionRate >= 0.8 {
            if let lastStreak = state.lastStreakDate,
               Calendar.current.isDateInYesterday(lastStreak) || Calendar.current.isDateInToday(lastStreak) {
                if !Calendar.current.isDateInToday(lastStreak) {
                    state.streakDays += 1
                }
            } else {
                state.streakDays = 1
            }
            state.lastStreakDate = .now
            state.longestStreak = max(state.longestStreak, state.streakDays)

            // Streak milestone bonus (every N days)
            let interval = GoosieConstants.streakMilestoneInterval
            if state.streakDays >= interval &&
               state.streakDays / interval != previousStreak / interval {
                coinsEarned = GoosieConstants.coinsPerStreakMilestone
                state.coins += coinsEarned
            }
        } else if let lastStreak = state.lastStreakDate {
            let daysSinceStreak = Calendar.current.dateComponents([.day], from: lastStreak, to: .now).day ?? 0
            if daysSinceStreak >= GoosieConstants.streakResetAfterMissedDays {
                state.streakDays = 0
            }
        }

        return coinsEarned
    }

    // MARK: - UserProfile Baseline Auto-Calculation

    func updateBaselinesIfNeeded(profile: UserProfile, recentLogs: [DailyLog]) {
        let completedLogs = recentLogs.filter { $0.sleepHours > 0 || $0.steps > 0 }
        guard completedLogs.count >= 7 else { return }

        let last7 = Array(completedLogs.suffix(7))
        let avgSleep = last7.map(\.sleepHours).reduce(0, +) / Double(last7.count)
        let avgSteps = last7.map { Double($0.steps) }.reduce(0, +) / Double(last7.count)
        let avgExercise = last7.map { Double($0.exerciseMinutes) }.reduce(0, +) / Double(last7.count)
        let avgSitting = last7.map(\.sittingHours).reduce(0, +) / Double(last7.count)

        if abs(avgSleep - profile.avgSleepHours) / max(1, profile.avgSleepHours) > 0.1 {
            profile.avgSleepHours = avgSleep
        }
        if abs(avgSteps - Double(profile.avgSteps)) / max(1, Double(profile.avgSteps)) > 0.1 {
            profile.avgSteps = Int(avgSteps)
        }
        if abs(avgExercise - Double(profile.avgExerciseMinutes)) / max(1, Double(profile.avgExerciseMinutes)) > 0.1 {
            profile.avgExerciseMinutes = Int(avgExercise)
        }
        if abs(avgSitting - profile.avgSittingHours) / max(1, profile.avgSittingHours) > 0.1 {
            profile.avgSittingHours = avgSitting
        }
    }

    // MARK: - Formula Accessors

    /// Compute healthiness (0–1) from today's DailyLog and UserProfile baselines.
    func computeHealthiness(log: DailyLog, profile: UserProfile) -> Double {
        RewardEngine.computeHealthiness(log: log, profile: profile)
    }

    /// Compute happiness (0–1) from today's DailyLog and current Goals.
    func computeHappiness(log: DailyLog, goals: [Goal]) -> Double {
        RewardEngine.computeHappiness(log: log, goals: goals)
    }

    /// Call this from DistractionOverlay each time distractionMinutes increments.
    func updateDistractMinutes(_ minutes: Int) {
        cachedDistractMinutes = minutes
    }

    // MARK: - Goals Cache

    /// Call this whenever the active goals list changes (onAppear, onChange).
    /// Converts Goal → GoalSummary and caches for the next sync payload.
    func refreshGoals(_ goals: [Goal]) {
        cachedTopGoals = goals.filter(\.isActive).map { $0.toSummary() }
    }

    // MARK: - App Group Sync + Watch Sync

    private func saveStatsToAppGroup(_ payload: GooseSyncPayload) {
        var enrichedPayload = payload
        enrichedPayload.steps = cachedSteps
        enrichedPayload.exerciseMinutes = cachedExerciseMinutes
        enrichedPayload.sleepHours = cachedSleepHours
        enrichedPayload.standHours = cachedStandHours
        enrichedPayload.activeCalories = cachedActiveCalories
        enrichedPayload.outsideMinutes = cachedOutsideMinutes
        enrichedPayload.topGoals = cachedTopGoals

        guard let defaults = UserDefaults(suiteName: GoosieConstants.appGroupID) else { return }
        if let data = try? JSONEncoder().encode(enrichedPayload) {
            defaults.set(data, forKey: GoosieConstants.gooseStatsKey)
        }
        WatchSyncService.shared.sendPayload(enrichedPayload)
        GooseLiveActivityManager.shared.updateStats(payload: enrichedPayload)

        // Sync to Convex (social backend)
        GooseSyncService.shared.syncToConvex(
            happiness: enrichedPayload.happiness,
            healthiness: enrichedPayload.healthiness,
            mood: enrichedPayload.mood,
            gooseName: enrichedPayload.name,
            spriteID: enrichedPayload.spriteID,
            streakDays: enrichedPayload.streakDays
        )
    }
}
