import Foundation
import SwiftData
import Observation

@Observable
final class GooseViewModel {
    var gooseState: GooseState?
    var currentReaction: GooseReaction = .none

    private let engine = GooseEngine.shared
    private var updateTimer: Timer?

    // Context kept in sync by the View for use in the periodic timer
    private var currentLog: DailyLog?
    private var currentProfile: UserProfile?
    private var currentGoals: [Goal] = []

    var mood: GooseMood {
        gooseState?.currentMood ?? .content
    }

    var moodText: String {
        mood.displayName
    }

    /// Healthiness as 0–100 for display
    var healthinessPercent: Double {
        (gooseState?.healthiness ?? 0) * 100
    }

    /// Happiness as 0–100 for display
    var happinessPercent: Double {
        (gooseState?.happiness ?? 0) * 100
    }

    var gooseName: String {
        gooseState?.name ?? "Harold"
    }

    var coins: Int {
        gooseState?.coins ?? 0
    }

    var streakDays: Int {
        gooseState?.streakDays ?? 0
    }

    /// Goal completion progress 0.0–1.0
    var goalProgress: Double {
        let active = currentGoals.filter { $0.isActive }
        guard !active.isEmpty else { return 0 }
        let completed = active.filter { $0.isCompleted }.count
        return Double(completed) / Double(active.count)
    }

    var completedGoalsCount: Int {
        currentGoals.filter { $0.isActive && $0.isCompleted }.count
    }

    var totalGoalsCount: Int {
        currentGoals.filter { $0.isActive }.count
    }

    // MARK: - Lifecycle

    func updateState(_ state: GooseState) {
        gooseState = state
    }

    func updateContext(log: DailyLog?, profile: UserProfile?, goals: [Goal]) {
        currentLog = log
        currentProfile = profile
        currentGoals = goals
    }

    func onAppear(state: GooseState, log: DailyLog?, profile: UserProfile?, goals: [Goal]) {
        gooseState = state
        currentLog = log
        currentProfile = profile
        currentGoals = goals
        engine.update(state: state, log: log, profile: profile, goals: goals)
        startPeriodicUpdates()
    }

    func onDisappear() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func startPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self, let state = self.gooseState else { return }
            self.engine.update(state: state, log: self.currentLog, profile: self.currentProfile, goals: self.currentGoals)
        }
    }

    // MARK: - Actions

    func completeGoal(_ goal: Goal) {
        guard let state = gooseState else { return }
        engine.completeGoal(goal, state: state, log: currentLog, goals: currentGoals)
        triggerReaction(.goalComplete)
    }

    private func triggerReaction(_ reaction: GooseReaction) {
        currentReaction = reaction
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.currentReaction = .none
        }
    }
}
