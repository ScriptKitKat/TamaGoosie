import Foundation
import SwiftData

@Model
final class HealthSnapshot {
    var id: UUID = UUID()
    var date: Date = Date()
    var steps: Int = 0
    var activeCalories: Double = 0
    var exerciseMinutes: Double = 0
    var sleepHours: Double = 0
    var standHours: Int = 0
    var outsideMinutes: Double = 0
    var restingHeartRate: Double?
    var workoutCount: Int = 0
    var wasProcessed: Bool = false

    // Back-reference to owning DailyLog
    var dailyLog: DailyLog?

    init(
        date: Date = .now,
        steps: Int = 0,
        activeCalories: Double = 0,
        exerciseMinutes: Double = 0,
        sleepHours: Double = 0,
        standHours: Int = 0,
        outsideMinutes: Double = 0,
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
        self.outsideMinutes = outsideMinutes
        self.restingHeartRate = restingHeartRate
        self.workoutCount = workoutCount
        self.wasProcessed = false
    }
}
