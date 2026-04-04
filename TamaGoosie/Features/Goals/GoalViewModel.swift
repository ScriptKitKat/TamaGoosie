import Foundation
import SwiftData
import Observation

@Observable
final class GoalViewModel {
    var showEditor = false
    var editingGoal: Goal?

    func deleteGoal(_ goal: Goal, in context: ModelContext) {
        context.delete(goal)
    }

    func completeGoal(_ goal: Goal, gooseState: GooseState) {
        GooseEngine.shared.completeGoal(goal, state: gooseState)
    }

    func incrementGoal(_ goal: Goal, gooseState: GooseState) {
        goal.incrementProgress()
        if goal.isCompleted {
            GooseEngine.shared.completeGoal(goal, state: gooseState)
        }
    }

    func resetDailyGoals(_ goals: [Goal]) {
        let calendar = Calendar.current
        for goal in goals where goal.isCompleted {
            if let completedAt = goal.completedAt, !calendar.isDateInToday(completedAt) {
                goal.resetForNewDay()
            }
        }
    }

    func startCreating() {
        editingGoal = nil
        showEditor = true
    }
}
