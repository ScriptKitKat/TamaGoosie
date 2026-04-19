import Foundation
import SwiftData

@Model
final class GoalCompletionEvent {
    var id: UUID = UUID()
    var goalID: UUID
    var completedAt: Date = Date()
    var hourOfDay: Int = 0         // 0-23
    var dayOfWeek: Int = 1         // 1=Sunday, 7=Saturday

    init(goalID: UUID, completedAt: Date = .now) {
        self.id = UUID()
        self.goalID = goalID
        self.completedAt = completedAt
        self.hourOfDay = Calendar.current.component(.hour, from: completedAt)
        self.dayOfWeek = Calendar.current.component(.weekday, from: completedAt)
    }
}
