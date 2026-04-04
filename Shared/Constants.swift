import Foundation

public enum GoosieConstants {
    // MARK: - Stat Bounds (0.0 – 1.0)
    public static let statMin: Double = 0.0
    public static let statMax: Double = 1.0
    public static let statFloor: Double = 0.05

    // MARK: - Decay Rates (per hour, on 0.0–1.0 scale)
    public static let healthinessDecayPerHour: Double = 0.008
    public static let happinessDecayPerHour: Double = 0.012
    public static let compoundDecayPerHour: Double = 0.004

    // MARK: - Decay Modifiers
    public static let compoundPenaltyThreshold: Double = 0.2
    public static let gracePeriodHours: Double = 2
    public static let longAbsenceThreshold: Double = 8
    public static let minDecayInterval: Double = 0.5 // hours

    // MARK: - XP & Levels
    public static func xpForLevel(_ level: Int) -> Int {
        100 + (level - 1) * 150
    }

    public static let maxLevel: Int = 50

    // MARK: - Reward Events (on 0.0–1.0 scale)
    public static let goalCompletionHappinessBase: Double = 0.05
    public static let goalCompletionXP: Int = 10
    public static let allGoalsHealthinessBonus: Double = 0.03
    public static let allGoalsHappinessBonus: Double = 0.10
    public static let allGoalsXP: Int = 25

    public static let exerciseHealthinessBonus: Double = 0.08
    public static let exerciseHappinessBonus: Double = 0.05
    public static let exerciseXP: Int = 15
    public static let exerciseThresholdMinutes: Double = 30

    public static let goodSleepHealthinessBonus: Double = 0.05
    public static let goodSleepHappinessBonus: Double = 0.02
    public static let goodSleepXP: Int = 5
    public static let badSleepHealthinessPenalty: Double = 0.10
    public static let badSleepHappinessPenalty: Double = 0.05

    public static let stepsHealthinessBonus: Double = 0.05
    public static let stepsHappinessBonus: Double = 0.03
    public static let stepsXP: Int = 10
    public static let stepsThreshold: Int = 10000

    public static let distractionOpenPenalty: Double = 0.02

    public static let streakMilestoneHealthinessBonus: Double = 0.05
    public static let streakMilestoneHappinessBonus: Double = 0.10
    public static let streakMilestoneXP: Int = 50

    // MARK: - Health Data Thresholds
    public static let sleepPenaltyBelow: Double = 5
    public static let sleepBonusMin: Double = 7
    public static let sleepBonusMax: Double = 9

    // MARK: - Streak
    public static let maxStreakMultiplier: Double = 2.0
    public static let streakMultiplierIncrement: Double = 0.1
    public static let streakResetAfterMissedDays: Int = 2

    // MARK: - Death & Revival
    public static let freeRevivalCount: Int = 1
    public static let revivalCooldownHours: Double = 24
    public static let revivalCooldownAfterDeathCount: Int = 3

    // MARK: - Focus
    public static let focusMinMinutes: Int = 5
    public static let focusMaxMinutes: Int = 120
    public static let focusDefaultMinutes: Int = 25
    public static let focusXPPerMinute: Int = 2
    public static let focusHappinessBonus: Double = 0.002

    // MARK: - Healthiness Formula Weights
    public static let sleepWeight: Double = 0.30
    public static let exerciseWeight: Double = 0.30
    public static let stepsWeight: Double = 0.25
    public static let sittingWeight: Double = 0.15

    public static let sleepWeightWithOutside: Double = 0.25
    public static let exerciseWeightWithOutside: Double = 0.25
    public static let stepsWeightWithOutside: Double = 0.20
    public static let sittingWeightWithOutside: Double = 0.15
    public static let outsideWeightWithOutside: Double = 0.15

    // MARK: - Happiness Formula Weights
    public static let goalScoreWeight: Double = 0.50
    public static let distractionWeight: Double = 0.30
    public static let baseHappinessWeight: Double = 0.20
    public static let distractionMaxMinutes: Double = 120
    public static let maxStreakBonus: Double = 0.1

    // MARK: - App Groups
    public static let appGroupID = "group.com.tamagoosie"
    public static let gooseStatsKey = "gooseStats"

    // MARK: - Live Activity
    public static let liveActivityMaxHours: Double = 8
}
