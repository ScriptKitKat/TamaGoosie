import Foundation

/// Lightweight goal representation for Watch sync and widget display
public struct GoalSummary: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID
    public var title: String
    public var progress: Double
    public var category: String

    public init(id: UUID, title: String, progress: Double, category: String) {
        self.id = id
        self.title = title
        self.progress = progress
        self.category = category
    }

    public var goalCategory: GoalCategory {
        GoalCategory(rawValue: category) ?? .custom
    }
}
