import Foundation
import SwiftData
import Observation

@Observable
final class GoalViewModel {
    var showEditor = false
    var editingGoal: Goal?

    func deleteGoal(_ goal: Goal, in context: ModelContext) {
        GooseNotificationSystem.shared.cancelPushes(for: goal.id)
        context.delete(goal)
    }

    /// Seeds 4 built-in goals if none of type "builtin" exist yet.
    func seedBuiltinGoalsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<Goal>(predicate: #Predicate { $0.type == "builtin" })
        guard (try? context.fetch(descriptor))?.isEmpty != false else { return }

        let builtin: [(String, GoalCategory, GoalFrequency, Double)] = [
            ("Daily walk (10,000 steps)", .health, .daily, 1.2),
            ("8 hours of sleep", .health, .daily, 1.2),
            ("Drink 8 glasses of water", .health, .daily, 1.0),
            ("No screens after 9pm", .mindfulness, .daily, 1.0),
        ]

        for (index, (title, category, frequency, weight)) in builtin.enumerated() {
            let goal = Goal(
                title: title,
                type: "builtin",
                category: category,
                frequency: frequency,
                targetCount: 1,
                happinessWeight: weight,
                sortOrder: index
            )
            context.insert(goal)
        }
    }

    func completeGoal(_ goal: Goal, gooseState: GooseState, log: DailyLog?, goals: [Goal]) {
        GooseEngine.shared.completeGoal(goal, state: gooseState, log: log, goals: goals)
    }

    func incrementGoal(_ goal: Goal, gooseState: GooseState, log: DailyLog?, goals: [Goal]) {
        goal.incrementProgress()
        if goal.isCompleted {
            GooseEngine.shared.completeGoal(goal, state: gooseState, log: log, goals: goals)
        }
    }

    func incrementDeadlinePercentage(_ goal: Goal, gooseState: GooseState, log: DailyLog?, goals: [Goal], amount: Double = 0.01) {
        let wasCompleted = goal.isCompleted
        goal.incrementPercentage(by: amount)
        if goal.isCompleted && !wasCompleted {
            GooseEngine.shared.completeGoal(goal, state: gooseState, log: log, goals: goals)
        }
    }

    func setDeadlinePercentage(_ goal: Goal, gooseState: GooseState, log: DailyLog?, goals: [Goal], to value: Double) {
        let wasCompleted = goal.isCompleted
        goal.setPercentage(value)
        if goal.isCompleted && !wasCompleted {
            GooseEngine.shared.completeGoal(goal, state: gooseState, log: log, goals: goals)
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

    func uncompleteGoal(_ goal: Goal, gooseState: GooseState, log: DailyLog?, goals: [Goal]) {
        GooseEngine.shared.uncompleteGoal(goal, state: gooseState, log: log, goals: goals)
    }

    func startEditing(_ goal: Goal) {
        editingGoal = goal
        showEditor  = true
    }

    func startCreating() {
        editingGoal = nil
        showEditor = true
    }
}
