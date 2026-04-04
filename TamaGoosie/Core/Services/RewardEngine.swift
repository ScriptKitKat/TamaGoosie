import Foundation

enum RewardEngine {
    struct StatDelta {
        var health: Double = 0
        var happiness: Double = 0
        var energy: Double = 0
        var hygiene: Double = 0
        var xp: Int = 0
    }

    // MARK: - Goal Completion Rewards

    static func rewardForGoalCompletion(streakDays: Int) -> StatDelta {
        let multiplier = streakMultiplier(for: streakDays)

        return StatDelta(
            health: GoosieConstants.goalCompletionHealthBonus * multiplier,
            happiness: GoosieConstants.goalCompletionHappinessBonus * multiplier,
            energy: GoosieConstants.goalCompletionEnergyBonus * multiplier,
            hygiene: GoosieConstants.goalCompletionHygieneBonus * multiplier,
            xp: Int(Double(GoosieConstants.goalCompletionXP) * multiplier)
        )
    }

    // MARK: - Health Data Rewards

    static func rewardForHealthData(_ snapshot: HealthSnapshot) -> StatDelta {
        var delta = StatDelta()

        // Steps
        if snapshot.steps >= GoosieConstants.stepsThresholdHigh {
            delta.health += 15
            delta.energy += 10
            delta.happiness += 8
            delta.xp += 50
        } else if snapshot.steps >= GoosieConstants.stepsThresholdMid {
            delta.health += 10
            delta.energy += 6
            delta.happiness += 5
            delta.xp += 30
        } else if snapshot.steps >= GoosieConstants.stepsThresholdLow {
            delta.health += 5
            delta.energy += 3
            delta.happiness += 2
            delta.xp += 15
        }

        // Sleep
        if snapshot.sleepHours < GoosieConstants.sleepPenaltyBelow {
            delta.energy -= 10
            delta.health -= 5
            delta.happiness -= 3
        } else if snapshot.sleepHours >= GoosieConstants.sleepBonusMin &&
                    snapshot.sleepHours <= GoosieConstants.sleepBonusMax {
            delta.energy += 12
            delta.health += 8
            delta.happiness += 5
            delta.xp += 20
        }

        // Exercise
        if snapshot.exerciseMinutes >= GoosieConstants.exerciseBonusMinutes {
            delta.health += 10
            delta.energy += 5
            delta.happiness += 8
            delta.hygiene += 3
            delta.xp += 25
        }

        return delta
    }

    // MARK: - Focus Session Rewards

    static func rewardForFocusSession(minutes: Int) -> StatDelta {
        StatDelta(
            happiness: Double(minutes) * GoosieConstants.focusHappinessBonus,
            energy: Double(minutes) * GoosieConstants.focusEnergyBonus,
            xp: minutes * GoosieConstants.focusXPPerMinute
        )
    }

    // MARK: - Apply Rewards

    static func applyDelta(_ delta: StatDelta, to state: GooseState) {
        state.health += delta.health
        state.happiness += delta.happiness
        state.energy += delta.energy
        state.hygiene += delta.hygiene
        state.xp += delta.xp

        state.clampStats()

        // Check level up
        while state.xp >= GoosieConstants.xpForLevel(state.level) && state.level < GoosieConstants.maxLevel {
            state.xp -= GoosieConstants.xpForLevel(state.level)
            state.level += 1
            state.updatePhase()
        }

        state.updateMood()
    }

    // MARK: - Streak

    static func streakMultiplier(for streakDays: Int) -> Double {
        min(GoosieConstants.maxStreakMultiplier,
            1.0 + Double(streakDays) * GoosieConstants.streakMultiplierIncrement)
    }
}
