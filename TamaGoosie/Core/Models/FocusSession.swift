import Foundation
import SwiftData

@Model
final class FocusSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var targetMinutes: Int
    var actualMinutes: Int
    var wasCompleted: Bool
    var xpEarned: Int
    var happinessBonus: Double

    init(targetMinutes: Int = GoosieConstants.focusDefaultMinutes) {
        self.id = UUID()
        self.startedAt = .now
        self.targetMinutes = targetMinutes
        self.actualMinutes = 0
        self.wasCompleted = false
        self.xpEarned = 0
        self.happinessBonus = 0
    }

    func finish(completed: Bool) {
        endedAt = .now

        if let end = endedAt {
            actualMinutes = Int(end.timeIntervalSince(startedAt) / 60)
        }

        wasCompleted = completed
        if completed {
            xpEarned = actualMinutes * GoosieConstants.focusXPPerMinute
            happinessBonus = Double(actualMinutes) * GoosieConstants.focusHappinessBonus
        }
    }
}
