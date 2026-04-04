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

    /// Seeds built-in goals if they don't already exist.
    /// Sleep goal is only seeded when a Watch is paired (sleep data comes from Watch).
    func seedBuiltinGoalsIfNeeded(in context: ModelContext, isWatchPaired: Bool) {
        // (title, category, frequency, happinessWeight, targetCount, sortOrder)
        let alwaysGoals: [(String, GoalCategory, GoalFrequency, Double, Int, Int)] = [
            ("Daily walk (10,000 steps)", .health,     .daily, 1.2, 10_000, 0),
            // Screen time tracking disabled — will re-enable later
            // ("Limit screen time to 2 hrs", .screentime, .daily, 1.0, 120,   1),
        ]
        let watchGoals: [(String, GoalCategory, GoalFrequency, Double, Int, Int)] = [
            ("8 hours of sleep", .health, .daily, 1.2, 8, 2),
        ]

        for (title, category, frequency, weight, count, order) in alwaysGoals {
            guard !goalExists(title: title, in: context) else { continue }
            context.insert(Goal(
                title: title, type: "builtin",
                category: category, frequency: frequency,
                targetCount: count, happinessWeight: weight, sortOrder: order
            ))
        }

        if isWatchPaired {
            for (title, category, frequency, weight, count, order) in watchGoals {
                guard !goalExists(title: title, in: context) else { continue }
                context.insert(Goal(
                    title: title, type: "builtin",
                    category: category, frequency: frequency,
                    targetCount: count, happinessWeight: weight, sortOrder: order
                ))
            }
        }
    }

    private func goalExists(title: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Goal>(predicate: #Predicate { $0.title == title })
        return (try? context.fetch(descriptor))?.isEmpty == false
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
            if goal.title.localizedCaseInsensitiveContains("steps"), steps >= goal.targetCount {
                completeGoal(goal, gooseState: state)
            } else if goal.title.localizedCaseInsensitiveContains("sleep"), sleepHours >= Double(goal.targetCount) {
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

    func uncompleteGoal(_ goal: Goal, gooseState: GooseState) {
        GooseEngine.shared.uncompleteGoal(goal, state: gooseState)
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
