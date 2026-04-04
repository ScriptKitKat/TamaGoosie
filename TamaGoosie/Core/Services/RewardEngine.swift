import Foundation

enum RewardEngine {
    struct StatDelta {
        var healthiness: Double = 0
        var happiness: Double = 0
        var xp: Int = 0
    }

    // MARK: - Goal Completion

    static func rewardForGoalCompletion(weight: Double, streakDays: Int) -> StatDelta {
        let xpMultiplier = streakMultiplier(for: streakDays)
        return StatDelta(
            happiness: GoosieConstants.goalCompletionHappinessBase * weight,
            xp: Int(Double(GoosieConstants.goalCompletionXP) * xpMultiplier)
        )
    }

    static func rewardForAllGoalsCompleted() -> StatDelta {
        StatDelta(
            healthiness: GoosieConstants.allGoalsHealthinessBonus,
            happiness: GoosieConstants.allGoalsHappinessBonus,
            xp: GoosieConstants.allGoalsXP
        )
    }

    // MARK: - Health Data Rewards

    static func rewardForExercise(minutes: Double) -> StatDelta {
        guard minutes >= GoosieConstants.exerciseThresholdMinutes else { return StatDelta() }
        return StatDelta(
            healthiness: GoosieConstants.exerciseHealthinessBonus,
            happiness: GoosieConstants.exerciseHappinessBonus,
            xp: GoosieConstants.exerciseXP
        )
    }

    static func rewardForSleep(hours: Double) -> StatDelta {
        if hours < GoosieConstants.sleepPenaltyBelow {
            return StatDelta(
                healthiness: -GoosieConstants.badSleepHealthinessPenalty,
                happiness: -GoosieConstants.badSleepHappinessPenalty
            )
        } else if hours >= GoosieConstants.sleepBonusMin && hours <= GoosieConstants.sleepBonusMax {
            return StatDelta(
                healthiness: GoosieConstants.goodSleepHealthinessBonus,
                happiness: GoosieConstants.goodSleepHappinessBonus,
                xp: GoosieConstants.goodSleepXP
            )
        }
        return StatDelta()
    }

    static func rewardForSteps(_ steps: Int) -> StatDelta {
        guard steps >= GoosieConstants.stepsThreshold else { return StatDelta() }
        return StatDelta(
            healthiness: GoosieConstants.stepsHealthinessBonus,
            happiness: GoosieConstants.stepsHappinessBonus,
            xp: GoosieConstants.stepsXP
        )
    }

    static func penaltyForDistractionOpen() -> StatDelta {
        StatDelta(happiness: -GoosieConstants.distractionOpenPenalty)
    }

    static func rewardForStreakMilestone() -> StatDelta {
        StatDelta(
            healthiness: GoosieConstants.streakMilestoneHealthinessBonus,
            happiness: GoosieConstants.streakMilestoneHappinessBonus,
            xp: GoosieConstants.streakMilestoneXP
        )
    }

    // MARK: - Focus Session

    static func rewardForFocusSession(minutes: Int) -> StatDelta {
        StatDelta(
            happiness: Double(minutes) * GoosieConstants.focusHappinessBonus,
            xp: minutes * GoosieConstants.focusXPPerMinute
        )
    }

    // MARK: - Apply

    static func applyDelta(_ delta: StatDelta, to state: GooseState) {
        state.healthiness += delta.healthiness
        state.happiness += delta.happiness
        state.xp += delta.xp
        state.clampStats()

        // Level up
        while state.xp >= GoosieConstants.xpForLevel(state.level) && state.level < GoosieConstants.maxLevel {
            state.xp -= GoosieConstants.xpForLevel(state.level)
            state.level += 1
            state.updatePhase()
        }

        state.updateMood()
    }

    // MARK: - Healthiness Formula

    static func computeHealthiness(log: DailyLog, profile: UserProfile) -> Double {
        let sleepScore = clamp(log.sleepHours / profile.avgSleepHours)
        let exerciseScore = clamp(Double(log.exerciseMinutes) / Double(max(1, profile.avgExerciseMinutes)))
        let stepsScore = clamp(Double(log.steps) / Double(max(1, profile.avgSteps)))
        let sittingScore = clamp(1.0 - (log.sittingHours / 16.0))
        let outsideScore = clamp(Double(log.outsideMinutes) / 60.0)

        if profile.watchPaired && log.outsideMinutes > 0 {
            return (GoosieConstants.sleepWeightWithOutside * sleepScore)
                 + (GoosieConstants.exerciseWeightWithOutside * exerciseScore)
                 + (GoosieConstants.stepsWeightWithOutside * stepsScore)
                 + (GoosieConstants.sittingWeightWithOutside * sittingScore)
                 + (GoosieConstants.outsideWeightWithOutside * outsideScore)
        } else {
            return (GoosieConstants.sleepWeight * sleepScore)
                 + (GoosieConstants.exerciseWeight * exerciseScore)
                 + (GoosieConstants.stepsWeight * stepsScore)
                 + (GoosieConstants.sittingWeight * sittingScore)
        }
    }

    // MARK: - Happiness Formula

    static func computeHappiness(log: DailyLog, goals: [Goal]) -> Double {
        let goalScore: Double = log.goalsTotal > 0
            ? Double(log.goalsCompleted) / Double(log.goalsTotal)
            : 0.5

        let distractionPenalty = clamp(Double(log.distractionMinutes) / GoosieConstants.distractionMaxMinutes)

        let maxStreak = goals.map(\.currentStreak).max() ?? 0
        let streakBonus = min(GoosieConstants.maxStreakBonus, Double(maxStreak) * 0.01)

        let raw = (GoosieConstants.goalScoreWeight * goalScore)
                + (GoosieConstants.distractionWeight * (1.0 - distractionPenalty))
                + (GoosieConstants.baseHappinessWeight * 1.0)
                + streakBonus

        return clamp(raw)
    }

    // MARK: - Helpers

    static func streakMultiplier(for streakDays: Int) -> Double {
        min(GoosieConstants.maxStreakMultiplier,
            1.0 + Double(streakDays) * GoosieConstants.streakMultiplierIncrement)
    }

    static func isStreakMilestone(_ days: Int) -> Bool {
        [7, 14, 30, 60, 90, 180, 365].contains(days)
    }

    private static func clamp(_ v: Double) -> Double {
        max(0.0, min(1.0, v))
    }
}
