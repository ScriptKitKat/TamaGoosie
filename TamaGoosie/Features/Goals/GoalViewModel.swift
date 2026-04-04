import Foundation
import SwiftData
import Observation

@Observable
final class GoalViewModel {
    var showEditor = false
    var editingGoal: Goal?

    func deleteGoal(_ goal: Goal, in context: ModelContext) {
        NotificationManager.shared.cancelGoalReminder(goalID: goal.id)
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

    func completeGoal(_ goal: Goal, gooseState: GooseState) {
        GooseEngine.shared.completeGoal(goal, state: gooseState)
    }

    func incrementGoal(_ goal: Goal, gooseState: GooseState) {
        goal.incrementProgress()
        if goal.isCompleted {
            GooseEngine.shared.completeGoal(goal, state: gooseState)
        }
    }

    func incrementDeadlinePercentage(_ goal: Goal, gooseState: GooseState, amount: Double = 0.01) {
        let wasCompleted = goal.isCompleted
        goal.incrementPercentage(by: amount)
        if goal.isCompleted && !wasCompleted {
            GooseEngine.shared.completeGoal(goal, state: gooseState)
        }
    }

    func setDeadlinePercentage(_ goal: Goal, gooseState: GooseState, to value: Double) {
        let wasCompleted = goal.isCompleted
        goal.setPercentage(value)
        if goal.isCompleted && !wasCompleted {
            GooseEngine.shared.completeGoal(goal, state: gooseState)
        }
    }

    /// Call when fresh HealthKit values arrive. Completes walk/sleep goals if threshold met.
    func autoCompleteHealthKitGoals(goals: [Goal], steps: Int, sleepHours: Double, state: GooseState) {
        for goal in goals where goal.isHealthKitTracked && !goal.isCompleted {
            if goal.title.localizedCaseInsensitiveContains("steps"), steps >= 10_000 {
                completeGoal(goal, gooseState: state)
            } else if goal.title.localizedCaseInsensitiveContains("sleep"), sleepHours >= 8.0 {
                completeGoal(goal, gooseState: state)
            }
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
