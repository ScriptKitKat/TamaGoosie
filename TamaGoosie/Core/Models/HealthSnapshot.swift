import Foundation
import SwiftData

@Model
final class HealthSnapshot {
    var id: UUID
    var date: Date
    var steps: Int
    var activeCalories: Double
    var exerciseMinutes: Double
    var sleepHours: Double
    var standHours: Int
    var restingHeartRate: Double?
    var workoutCount: Int
    var wasProcessed: Bool

    // Back-reference to owning DailyLog
    var dailyLog: DailyLog?

    init(
        date: Date = .now,
        steps: Int = 0,
        activeCalories: Double = 0,
        exerciseMinutes: Double = 0,
        sleepHours: Double = 0,
        standHours: Int = 0,
        restingHeartRate: Double? = nil,
        workoutCount: Int = 0
    ) {
        self.id = UUID()
        self.date = date
        self.steps = steps
        self.activeCalories = activeCalories
        self.exerciseMinutes = exerciseMinutes
        self.sleepHours = sleepHours
        self.standHours = standHours
        self.restingHeartRate = restingHeartRate
        self.workoutCount = workoutCount
        self.wasProcessed = false
    }
}
