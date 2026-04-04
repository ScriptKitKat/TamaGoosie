import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID
    var title: String
    var category: String // GoalCategory raw value
    var frequency: String // GoalFrequency raw value
    var targetCount: Int
    var currentCount: Int
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var streakDays: Int
    var lastCompletedDate: Date?
    var isActive: Bool
    var sortOrder: Int

    init(
        title: String,
        category: GoalCategory = .custom,
        frequency: GoalFrequency = .daily,
        targetCount: Int = 1,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.category = category.rawValue
        self.frequency = frequency.rawValue
        self.targetCount = targetCount
        self.currentCount = 0
        self.isCompleted = false
        self.createdAt = .now
        self.streakDays = 0
        self.isActive = true
        self.sortOrder = sortOrder
    }

    // MARK: - Computed

    var goalCategory: GoalCategory {
        GoalCategory(rawValue: category) ?? .custom
    }

    var goalFrequency: GoalFrequency {
        GoalFrequency(rawValue: frequency) ?? .daily
    }

    var progress: Double {
        guard targetCount > 0 else { return 0 }
        return Double(currentCount) / Double(targetCount)
    }

    func toSummary() -> GoalSummary {
        GoalSummary(
            id: id,
            title: title,
            category: goalCategory,
            currentCount: currentCount,
            targetCount: targetCount,
            isCompleted: isCompleted
        )
    }

    func complete() {
        currentCount = targetCount
        isCompleted = true
        completedAt = .now
        lastCompletedDate = .now
    }

    func incrementProgress() {
        guard !isCompleted else { return }
        currentCount = min(currentCount + 1, targetCount)
        if currentCount >= targetCount {
            complete()
        }
    }

    func resetForNewDay() {
        currentCount = 0
        isCompleted = false
        completedAt = nil
    }
}
