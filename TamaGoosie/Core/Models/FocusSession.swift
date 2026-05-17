import Foundation
import SwiftData

@Model
final class FocusSession {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var targetMinutes: Int = 25
    var actualMinutes: Int = 0
    var wasCompleted: Bool = false

    init(targetMinutes: Int = GoosieConstants.focusDefaultMinutes) {
        self.id = UUID()
        self.startedAt = .now
        self.targetMinutes = targetMinutes
        self.actualMinutes = 0
        self.wasCompleted = false
    }

    func finish(completed: Bool) {
        endedAt = .now

        if let end = endedAt {
            actualMinutes = Int(end.timeIntervalSince(startedAt) / 60)
        }

        wasCompleted = completed
    }
}
