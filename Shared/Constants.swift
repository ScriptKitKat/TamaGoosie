import Foundation

public enum GoosieConstants {
    // MARK: - Stat Bounds (0.0 – 1.0)
    public static let statMin: Double = 0.0
    public static let statMax: Double = 1.0

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
    public static let goalScoreWeight: Double = 0.65
    public static let distractionWeight: Double = 0.30
    public static let baseHappinessWeight: Double = 0.05
    public static let distractionMaxMinutes: Double = 120
    public static let maxStreakBonus: Double = 0.1

    // MARK: - Health Data Thresholds
    public static let sleepPenaltyBelow: Double = 5
    public static let sleepBonusMin: Double = 7
    public static let sleepBonusMax: Double = 9
    public static let exerciseThresholdMinutes: Double = 30
    public static let stepsThreshold: Int = 10000

    // MARK: - Streak
    public static let streakResetAfterMissedDays: Int = 2

    // MARK: - Coins
    public static let coinsPerGoalCompletion: Int = 5
    public static let coinsPerAllGoalsDone: Int = 10
    public static let coinsPerStreakMilestone: Int = 20
    public static let streakMilestoneInterval: Int = 7

    // MARK: - Focus
    public static let focusMinMinutes: Int = 5
    public static let focusMaxMinutes: Int = 120
    public static let focusDefaultMinutes: Int = 25

    // MARK: - App Groups
    public static let appGroupID = "group.com.tamagoosie"
    public static let gooseStatsKey = "gooseStats"

    // MARK: - Screen Time
    public static let screenTimeSelectionKey = "screenTimeSelection"
    public static let screenTimeThresholdEventsKey = "distractionHitsToday"
    public static let screenTimeApproxMinutesKey = "distractionApproxMinutes"
    public static let screenTimeLastHitKey = "lastDistractionHit"
    public static let screenTimeLimitKey = "distractionLimitMinutes"
    public static let screenTimeLastPenaltyMinutesKey = "lastPenaltyApproxMinutes"
    public static let screenTimeDefaultLimitMinutes: Int = 30
    public static let screenTimeThresholds: [Int] = [15, 30, 45, 60]
    public static let screenTimeSetupCompleteKey = "screenTimeSetupComplete"
    public static let screenTimePausedKey = "screenTimePaused"
    public static let screenTimeIsAllDayKey = "screenTimeIsAllDay"
    public static let screenTimeStartHourKey = "screenTimeStartHour"
    public static let screenTimeStartMinuteKey = "screenTimeStartMinute"
    public static let screenTimeEndHourKey = "screenTimeEndHour"
    public static let screenTimeEndMinuteKey = "screenTimeEndMinute"
    public static let screenTimeActiveDaysKey = "screenTimeActiveDays"

    // MARK: - Live Activity
    public static let liveActivityMaxHours: Double = 8
}
