import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID
    var title: String
    var type: String            // "deadline" | "recurring" | "builtin"
    var category: String        // GoalCategory raw value
    var frequency: String       // GoalFrequency raw value

    // Deadline goals
    var dueDate: Date?

    // Recurring goals
    var preferredTime: Date?
    var targetCount: Int
    var currentCount: Int

    // Tracking
    var isCompleted: Bool
    var completedAt: Date?
    var currentStreak: Int
    var lastCompletedDate: Date?
    var isActive: Bool
    var sortOrder: Int
    var createdAt: Date

    // Goose impact
    var happinessWeight: Double

    init(
        title: String,
        type: String = "recurring",
        category: GoalCategory = .custom,
        frequency: GoalFrequency = .daily,
        targetCount: Int = 1,
        happinessWeight: Double = 1.0,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.category = category.rawValue
        self.frequency = frequency.rawValue
        self.targetCount = targetCount
        self.currentCount = 0
        self.isCompleted = false
        self.currentStreak = 0
        self.isActive = true
        self.sortOrder = sortOrder
        self.createdAt = .now
        self.happinessWeight = happinessWeight
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
            progress: progress,
            category: category
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
