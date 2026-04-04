import Foundation
import SwiftData
import Observation

@Observable
final class GooseEngine {
    static let shared = GooseEngine()

    private(set) var isUpdating = false

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

        // Update goal streak
        if let lastDate = goal.lastCompletedDate,
           Calendar.current.isDateInYesterday(lastDate) || Calendar.current.isDateInToday(lastDate) {
            goal.currentStreak += 1
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

    // MARK: - App Group Sync + Watch Sync

    private func saveStatsToAppGroup(_ payload: GooseSyncPayload) {
        guard let defaults = UserDefaults(suiteName: GoosieConstants.appGroupID) else { return }
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: GoosieConstants.gooseStatsKey)
        }
        WatchSyncService.shared.sendPayload(payload)
    }
}
