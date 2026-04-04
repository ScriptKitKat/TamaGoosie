import Foundation
import SwiftData
import Observation

@Observable
final class GooseEngine {
    static let shared = GooseEngine()

    private(set) var isUpdating = false

    private init() {}

    // MARK: - Core Update Loop

    /// Main update: apply decay, recalculate mood, check death
    func update(state: GooseState) {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        guard !state.isVacationMode else { return }

        // Apply time-based decay
        DecayEngine.applyDecay(to: state)

        // Update days alive
        state.daysAlive = Calendar.current.dateComponents(
            [.day], from: state.birthDate, to: .now
        ).day ?? 0

        // Check death
        if state.health <= 0 && !state.isDead {
            triggerDeath(state: state)
        }

        // Update mood
        state.updateMood()

        // Sync to shared UserDefaults for widgets
        saveStatsToAppGroup(state.toStats())
    }

    // MARK: - Goal Completion

    func completeGoal(_ goal: Goal, state: GooseState) {
        guard !state.isDead else { return }

        goal.complete()
        state.totalGoalsCompleted += 1

        // Update goal streak
        if let lastDate = goal.lastCompletedDate,
           Calendar.current.isDateInYesterday(lastDate) || Calendar.current.isDateInToday(lastDate) {
            goal.streakDays += 1
        } else {
            goal.streakDays = 1
        }

        // Apply rewards
        let reward = RewardEngine.rewardForGoalCompletion(streakDays: state.streakDays)
        RewardEngine.applyDelta(reward, to: state)

        state.updateMood()
        saveStatsToAppGroup(state.toStats())
    }

    // MARK: - Health Data Processing

    func processHealthData(_ snapshot: HealthSnapshot, state: GooseState) {
        guard !state.isDead, !snapshot.wasProcessed else { return }

        let reward = RewardEngine.rewardForHealthData(snapshot)
        RewardEngine.applyDelta(reward, to: state)

        snapshot.wasProcessed = true
        state.updateMood()
        saveStatsToAppGroup(state.toStats())
    }

    // MARK: - Focus Session

    func completeFocusSession(minutes: Int, state: GooseState) {
        guard !state.isDead else { return }

        let reward = RewardEngine.rewardForFocusSession(minutes: minutes)
        RewardEngine.applyDelta(reward, to: state)

        state.updateMood()
        saveStatsToAppGroup(state.toStats())
    }

    // MARK: - Death & Revival

    private func triggerDeath(state: GooseState) {
        state.isDead = true
        state.health = 0
        state.mood = GooseMood.dead.rawValue
        state.deathCount += 1
        state.lastDeathDate = .now
    }

    func revive(state: GooseState) -> Bool {
        guard state.isDead else { return false }

        // Check cooldown after 3+ deaths
        if state.deathCount >= GoosieConstants.revivalCooldownAfterDeathCount,
           let lastDeath = state.lastDeathDate {
            let hoursSinceDeath = Date.now.timeIntervalSince(lastDeath) / 3600
            if hoursSinceDeath < GoosieConstants.revivalCooldownHours {
                return false
            }
        }

        state.isDead = false
        state.health = 50
        state.happiness = 50
        state.energy = 50
        state.hygiene = 50
        state.lastUpdated = .now
        state.updateMood()
        saveStatsToAppGroup(state.toStats())
        return true
    }

    func hatchNewEgg(state: GooseState) {
        state.isDead = false
        state.health = 100
        state.happiness = 100
        state.energy = 100
        state.hygiene = 100
        state.xp = 0
        state.level = 1
        state.phase = GoosePhase.baby.rawValue
        state.birthDate = .now
        state.lastUpdated = .now
        state.daysAlive = 0
        state.streakDays = 0
        // Keep: name, deathCount, longestStreak, totalGoalsCompleted
        state.updateMood()
        saveStatsToAppGroup(state.toStats())
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

    // MARK: - App Group Sync

    private func saveStatsToAppGroup(_ stats: GooseStats) {
        guard let defaults = UserDefaults(suiteName: GoosieConstants.appGroupID) else { return }
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: GoosieConstants.gooseStatsKey)
        }
    }
}
