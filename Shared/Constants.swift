import Foundation

public enum GoosieConstants {
    // MARK: - Stat Bounds
    public static let statMin: Double = 0
    public static let statMax: Double = 100
    public static let statFloor: Double = 5 // Decay never drops below this

    // MARK: - Decay Rates (per hour)
    public static let healthDecayPerHour: Double = 1.5
    public static let happinessDecayPerHour: Double = 2.0
    public static let energyDecayPerHour: Double = 1.8
    public static let hygieneDecayPerHour: Double = 1.2

    // MARK: - Decay Modifiers
    public static let compoundPenaltyThreshold: Double = 20 // Stat below this triggers compound decay
    public static let gracePeriodHours: Double = 2 // No decay for first N hours after long absence
    public static let longAbsenceThreshold: Double = 8 // Hours before grace period kicks in

    // MARK: - XP & Levels
    public static func xpForLevel(_ level: Int) -> Int {
        // Quadratic scaling: 100, 250, 450, 700, 1000...
        return 100 + (level - 1) * 150
    }

    public static let maxLevel: Int = 50

    // MARK: - Goals
    public static let goalCompletionXP: Int = 25
    public static let goalCompletionHealthBonus: Double = 5
    public static let goalCompletionHappinessBonus: Double = 8
    public static let goalCompletionEnergyBonus: Double = 3
    public static let goalCompletionHygieneBonus: Double = 2

    // MARK: - Streak
    public static let maxStreakMultiplier: Double = 2.0
    public static let streakMultiplierIncrement: Double = 0.1
    public static let streakGraceDays: Int = 1 // Miss 1 day without losing streak
    public static let streakResetAfterMissedDays: Int = 2

    // MARK: - Health Data Thresholds
    public static let stepsThresholdLow: Int = 2000
    public static let stepsThresholdMid: Int = 5000
    public static let stepsThresholdHigh: Int = 10000
    public static let sleepPenaltyBelow: Double = 5 // hours
    public static let sleepBonusMin: Double = 7
    public static let sleepBonusMax: Double = 9
    public static let exerciseBonusMinutes: Double = 30

    // MARK: - Death & Revival
    public static let freeRevivalCount: Int = 1
    public static let revivalCooldownHours: Double = 24
    public static let revivalCooldownAfterDeathCount: Int = 3

    // MARK: - Focus
    public static let focusMinMinutes: Int = 5
    public static let focusMaxMinutes: Int = 120
    public static let focusDefaultMinutes: Int = 25
    public static let focusXPPerMinute: Int = 2
    public static let focusEnergyBonus: Double = 0.3 // per minute
    public static let focusHappinessBonus: Double = 0.2 // per minute

    // MARK: - App Groups
    public static let appGroupID = "group.com.tamagoosie"
    public static let gooseStatsKey = "gooseStats"

    // MARK: - Live Activity
    public static let liveActivityMaxHours: Double = 8
}
