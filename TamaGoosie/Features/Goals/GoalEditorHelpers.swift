import Foundation

/// Maps title keywords to a GoalCategory.
func suggestCategory(from title: String) -> GoalCategory {
    let t = title.lowercased()
    let mapping: [(keywords: [String], category: GoalCategory)] = [
        (["water", "drink", "glass", "hydra"], .water),
        (["exercise", "run", "walk", "gym", "workout", "jog"], .exercise),
        (["study", "homework", "learn", "class"], .study),
        (["screen", "phone", "social media", "app", "tiktok", "instagram"], .screentime),
        (["sleep", "bed", "rest", "wake"], .health),
        (["read", "book", "chapter", "page"], .learning),
        (["meditate", "breathe", "journal", "mindful", "yoga"], .mindfulness),
        (["friend", "call", "family", "social"], .social),
        (["focus", "productive", "deep work", "task"], .productivity),
        (["stretch", "lift", "weight", "pushup", "plank"], .fitness),
    ]
    for entry in mapping {
        if entry.keywords.contains(where: { t.contains($0) }) {
            return entry.category
        }
    }
    return .custom
}

/// Returns context-aware target metadata for a category.
struct TargetUnitInfo {
    let label: String
    let defaultValue: Int
    let range: ClosedRange<Int>
    let step: Int
}

func targetUnit(for category: GoalCategory) -> TargetUnitInfo {
    switch category {
    case .water:        TargetUnitInfo(label: "glasses", defaultValue: 8, range: 1...20, step: 1)
    case .exercise:     TargetUnitInfo(label: "minutes", defaultValue: 30, range: 5...180, step: 5)
    case .fitness:      TargetUnitInfo(label: "minutes", defaultValue: 30, range: 5...180, step: 5)
    case .screentime:   TargetUnitInfo(label: "minutes", defaultValue: 120, range: 15...480, step: 15)
    case .study:        TargetUnitInfo(label: "minutes", defaultValue: 60, range: 10...300, step: 10)
    case .health:       TargetUnitInfo(label: "hours", defaultValue: 8, range: 4...12, step: 1)
    case .learning:     TargetUnitInfo(label: "minutes", defaultValue: 30, range: 10...180, step: 10)
    case .mindfulness:  TargetUnitInfo(label: "minutes", defaultValue: 15, range: 5...60, step: 5)
    case .productivity: TargetUnitInfo(label: "tasks", defaultValue: 3, range: 1...20, step: 1)
    case .social:       TargetUnitInfo(label: "times", defaultValue: 1, range: 1...10, step: 1)
    case .custom:       TargetUnitInfo(label: "times", defaultValue: 1, range: 1...99, step: 1)
    }
}
