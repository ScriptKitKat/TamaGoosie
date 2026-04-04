import Foundation
import SwiftData
import Observation

@Observable
final class GooseEngine {
    static let shared = GooseEngine()

    private(set) var isUpdating = false

    // Cached health data populated by processHealthData; included in every sync payload
    private(set) var cachedSteps: Int = 0
    private(set) var cachedExerciseMinutes: Int = 0
    private(set) var cachedSleepHours: Double = 0.0
    private(set) var cachedActiveCalories: Double = 0.0
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

    func completeGoal(_ goal: Goal, state: GooseState, log: DailyLog?, goals: [Goal]) {
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
        state.updateMood()
        saveStatsToAppGroup(state.toSyncPayload())
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
        dailyLog: DailyLog? = nil
    ) {
        cachedSteps = steps
        cachedExerciseMinutes = Int(exerciseMinutes)
        cachedSleepHours = sleepHours
        cachedActiveCalories = activeCalories
        cachedStandHours = standHours

        if let log = dailyLog {
            log.steps = steps
            log.exerciseMinutes = Int(exerciseMinutes)
            log.sleepHours = sleepHours
            log.standHours = standHours
        }
    }

    /// Sync built-in goal currentCount from cached HealthKit values so progress
    /// persists across app restarts.
    func syncBuiltinGoalProgress(_ goals: [Goal]) {
        for goal in goals where goal.isHealthKitTracked && !goal.isCompleted {
            if goal.title.localizedCaseInsensitiveContains("steps") {
                goal.currentCount = min(cachedSteps, goal.targetCount)
            } else if goal.title.localizedCaseInsensitiveContains("sleep") {
                goal.currentCount = min(Int(cachedSleepHours), goal.targetCount)
            }
        }
    }

    // MARK: - Reset

    func resetGoose(state: GooseState) {
        state.healthiness = 0.8
        state.happiness = 0.7
        state.streakDays = 0
        state.lastStreakDate = nil
        state.createdAt = .now
        state.lastUpdated = .now
        state.updateMood()
        saveStatsToAppGroup(state.toSyncPayload())
    }

    // MARK: - Streak Management

    func updateDailyStreak(state: GooseState, goalsCompletedToday: Int, totalGoalsToday: Int) {
        let completionRate = totalGoalsToday > 0 ? Double(goalsCompletedToday) / Double(totalGoalsToday) : 0

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
        } else if let lastStreak = state.lastStreakDate {
            let daysSinceStreak = Calendar.current.dateComponents([.day], from: lastStreak, to: .now).day ?? 0
            if daysSinceStreak >= GoosieConstants.streakResetAfterMissedDays {
                state.streakDays = 0
            }
        }
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
        enrichedPayload.topGoals = cachedTopGoals

        guard let defaults = UserDefaults(suiteName: GoosieConstants.appGroupID) else { return }
        if let data = try? JSONEncoder().encode(enrichedPayload) {
            defaults.set(data, forKey: GoosieConstants.gooseStatsKey)
        }
        WatchSyncService.shared.sendPayload(enrichedPayload)
    }
}
