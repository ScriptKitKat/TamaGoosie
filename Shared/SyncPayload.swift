import Foundation

/// Lightweight goal representation for Watch
public struct GoalSummary: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID
    public var title: String
    public var category: GoalCategory
    public var currentCount: Int
    public var targetCount: Int
    public var isCompleted: Bool

    public init(id: UUID, title: String, category: GoalCategory, currentCount: Int, targetCount: Int, isCompleted: Bool) {
        self.id = id
        self.title = title
        self.category = category
        self.currentCount = currentCount
        self.targetCount = targetCount
        self.isCompleted = isCompleted
    }

    public var progress: Double {
        guard targetCount > 0 else { return 0 }
        return Double(currentCount) / Double(targetCount)
    }
}
