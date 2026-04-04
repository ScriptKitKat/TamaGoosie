import Foundation
import SwiftData
import Observation

@Observable
final class GooseEngine {
    static let shared = GooseEngine()

    private(set) var isUpdating = false

    private init() {}

    // MARK: - Core Update Loop

    func update(state: GooseState) {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        guard !state.isVacationMode else { return }

        DecayEngine.applyDecay(to: state)
        state.updateMood()
        saveStatsToAppGroup(state.toSyncPayload())
    }

    // MARK: - Goal Completion

    func completeGoal(_ goal: Goal, state: GooseState) {
        guard !state.isDead else { return }

        goal.complete()

        // Update goal streak
        if let lastDate = goal.lastCompletedDate,
           Calendar.current.isDateInYesterday(lastDate) || Calendar.current.isDateInToday(lastDate) {
            goal.currentStreak += 1
        } else {
            goal.currentStreak = 1
        }

        let reward = RewardEngine.rewardForGoalCompletion(
            weight: goal.happinessWeight,
            streakDays: state.streakDays
        )
        RewardEngine.applyDelta(reward, to: state)
        saveStatsToAppGroup(state.toSyncPayload())
    }

    /// Check and reward if all daily goals are completed
    func checkAllGoalsCompleted(goals: [Goal], state: GooseState) {
        guard !state.isDead else { return }
        let activeGoals = goals.filter { $0.isActive }
        guard !activeGoals.isEmpty else { return }

        let allCompleted = activeGoals.allSatisfy { $0.isCompleted }
        if allCompleted {
            let reward = RewardEngine.rewardForAllGoalsCompleted()
            RewardEngine.applyDelta(reward, to: state)
            saveStatsToAppGroup(state.toSyncPayload())
        }
    }

    // MARK: - Health Data Processing

    func processHealthData(steps: Int, exerciseMinutes: Double, sleepHours: Double, state: GooseState) {
        guard !state.isDead else { return }

        var combined = RewardEngine.StatDelta()

        let stepsReward = RewardEngine.rewardForSteps(steps)
        combined.healthiness += stepsReward.healthiness
        combined.happiness += stepsReward.happiness
        combined.xp += stepsReward.xp

        let exerciseReward = RewardEngine.rewardForExercise(minutes: exerciseMinutes)
        combined.healthiness += exerciseReward.healthiness
        combined.happiness += exerciseReward.happiness
        combined.xp += exerciseReward.xp

        let sleepReward = RewardEngine.rewardForSleep(hours: sleepHours)
        combined.healthiness += sleepReward.healthiness
        combined.happiness += sleepReward.happiness
        combined.xp += sleepReward.xp

        RewardEngine.applyDelta(combined, to: state)
        saveStatsToAppGroup(state.toSyncPayload())
    }

    // MARK: - Focus Session

    func completeFocusSession(minutes: Int, state: GooseState) {
        guard !state.isDead else { return }

        let reward = RewardEngine.rewardForFocusSession(minutes: minutes)
        RewardEngine.applyDelta(reward, to: state)
        saveStatsToAppGroup(state.toSyncPayload())
    }

    // MARK: - Death & Revival

    func revive(state: GooseState) -> Bool {
        guard state.isDead else { return false }

        // Check cooldown after 3+ deaths
        if state.reviveCount >= GoosieConstants.revivalCooldownAfterDeathCount,
           let lastDeath = state.deathDate {
            let hoursSinceDeath = Date.now.timeIntervalSince(lastDeath) / 3600
            if hoursSinceDeath < GoosieConstants.revivalCooldownHours {
                return false
            }
        }

        state.isDead = false
        state.healthiness = 0.5
        state.happiness = 0.5
        state.reviveCount += 1
        state.deathDate = nil
        state.deathCause = nil
        state.lastUpdated = .now
        state.updateMood()
        saveStatsToAppGroup(state.toSyncPayload())
        return true
    }

    func hatchNewEgg(state: GooseState) {
        state.isDead = false
        state.healthiness = 0.8
        state.happiness = 0.7
        state.xp = 0
        state.level = 1
        state.phase = GoosePhase.baby.rawValue
        state.createdAt = .now
        state.lastUpdated = .now
        state.streakDays = 0
        state.deathDate = nil
        state.deathCause = nil
        // Preserve: name, reviveCount, longestStreak
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

            // Streak milestone rewards
            if RewardEngine.isStreakMilestone(state.streakDays) {
                let reward = RewardEngine.rewardForStreakMilestone()
                RewardEngine.applyDelta(reward, to: state)
            }
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

        // Only update if significantly different (>10% change) to avoid noise
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
