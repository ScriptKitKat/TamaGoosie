import Foundation

enum RewardEngine {

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

    private static func clamp(_ v: Double) -> Double {
        max(0.0, min(1.0, v))
    }
}
