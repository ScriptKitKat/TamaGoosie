import Foundation
import SwiftData

@Model
final class DailyLog {
    var id: UUID
    var date: Date
    var goalsCompleted: Int
    var goalsTotal: Int
    var focusMinutes: Int
    var steps: Int
    var sleepHours: Double
    var exerciseMinutes: Double
    var healthStart: Double
    var healthEnd: Double
    var happinessStart: Double
    var happinessEnd: Double
    var energyStart: Double
    var energyEnd: Double
    var hygieneStart: Double
    var hygieneEnd: Double
    var xpEarned: Int

    init(date: Date = .now) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.goalsCompleted = 0
        self.goalsTotal = 0
        self.focusMinutes = 0
        self.steps = 0
        self.sleepHours = 0
        self.exerciseMinutes = 0
        self.healthStart = 0
        self.healthEnd = 0
        self.happinessStart = 0
        self.happinessEnd = 0
        self.energyStart = 0
        self.energyEnd = 0
        self.hygieneStart = 0
        self.hygieneEnd = 0
        self.xpEarned = 0
    }
}
