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
    var percentageProgress: Double = 0.0  // 0.0–1.0; default required for SwiftData migration

    // Recurring goals
    var preferredTime: Date?
    var targetCount: Int
    var currentCount: Int

    // Custom frequency: comma-separated Calendar weekday numbers (1=Sun … 7=Sat)
    var customDays: String = ""           // default required for SwiftData migration

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

    // Back-reference to owning UserProfile
    var userProfile: UserProfile?

    // 1:many — one GoalProgress row per calendar day
    @Relationship(deleteRule: .cascade, inverse: \GoalProgress.goal)
    var progressRecords: [GoalProgress] = []

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
        self.percentageProgress = 0.0
        self.customDays = ""
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
        if type == "deadline" {
            return percentageProgress
        }
        guard targetCount > 0 else { return 0 }
        return Double(currentCount) / Double(targetCount)
    }

    /// Parsed custom days as a Set of Calendar weekday integers (1=Sun … 7=Sat).
    var customDaysSet: Set<Int> {
        get {
            Set(customDays.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) })
        }
        set {
            customDays = newValue.sorted().map(String.init).joined(separator: ",")
        }
    }

    /// True for built-in goals that are auto-tracked (HealthKit or internal screen time).
    var isHealthKitTracked: Bool {
        guard type == "builtin" else { return false }
        return title.localizedCaseInsensitiveContains("steps") ||
               title.localizedCaseInsensitiveContains("sleep") ||
               title.localizedCaseInsensitiveContains("screen time")
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

    func incrementPercentage(by amount: Double = 0.01) {
        guard type == "deadline", !isCompleted else { return }
        percentageProgress = min(1.0, percentageProgress + amount)
        if percentageProgress >= 1.0 {
            isCompleted = true
            completedAt = .now
            lastCompletedDate = .now
        }
    }

    func setPercentage(_ value: Double) {
        guard type == "deadline" else { return }
        percentageProgress = min(1.0, max(0.0, value))
        if percentageProgress >= 1.0 {
            isCompleted = true
            completedAt = .now
            lastCompletedDate = .now
        } else {
            isCompleted = false
            completedAt = nil
        }
    }

    func resetForNewDay() {
        currentCount = 0
        isCompleted = false
        completedAt = nil
    }
}
