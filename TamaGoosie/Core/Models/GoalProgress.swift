import Foundation
import SwiftData

/// Records one day's progress toward a Goal (one row per goal per calendar day).
@Model
final class GoalProgress {
    var id: UUID = UUID()
    var date: Date = Date()
    var completedCount: Int = 0
    var targetCount: Int = 1
    var isCompleted: Bool = false
    var completedAt: Date?

    // Back-reference to owning Goal
    var goal: Goal?

    init(date: Date = .now, targetCount: Int = 1) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.completedCount = 0
        self.targetCount = targetCount
        self.isCompleted = false
    }

    // MARK: - Computed

    var progress: Double {
        guard targetCount > 0 else { return 0 }
        return Double(completedCount) / Double(targetCount)
    }

    func markCompleted() {
        completedCount = targetCount
        isCompleted = true
        completedAt = .now
    }

    func increment() {
        guard !isCompleted else { return }
        completedCount = min(completedCount + 1, targetCount)
        if completedCount >= targetCount {
            markCompleted()
        }
    }
}
