import Foundation
import SwiftData
import Observation

@Observable
final class GooseViewModel {
    var gooseState: GooseState?
    var currentReaction: GooseReaction = .none
    var showDeathScreen = false

    private let engine = GooseEngine.shared
    private var updateTimer: Timer?

    var mood: GooseMood {
        gooseState?.currentMood ?? .content
    }

    var phase: GoosePhase {
        gooseState?.currentPhase ?? .baby
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

    var level: Int {
        gooseState?.level ?? 1
    }

    var streakDays: Int {
        gooseState?.streakDays ?? 0
    }

    var isDead: Bool {
        gooseState?.isDead ?? false
    }

    // MARK: - Lifecycle

    /// Called by GooseView.onChange(of: gooseStates) to keep the viewModel
    /// in sync with the persistent GooseState (avoids stale-reference issues
    /// when @Query delivers the real state after onAppear fires).
    func updateState(_ state: GooseState) {
        gooseState = state
        if state.isDead && !showDeathScreen { showDeathScreen = true }
    }

    func onAppear(state: GooseState) {
        gooseState = state
        engine.update(state: state)
        startPeriodicUpdates()

        if state.isDead {
            showDeathScreen = true
        }
    }

    func onDisappear() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func startPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self, let state = self.gooseState else { return }
            self.engine.update(state: state)
            if state.isDead && !self.showDeathScreen {
                self.showDeathScreen = true
            }
        }
    }

    // MARK: - Actions

    func completeGoal(_ goal: Goal) {
        guard let state = gooseState else { return }
        engine.completeGoal(goal, state: state)
        triggerReaction(.goalComplete)
    }

    func reviveGoose() -> Bool {
        guard let state = gooseState else { return false }
        let success = engine.revive(state: state)
        if success {
            showDeathScreen = false
        }
        return success
    }

    func hatchNewGoose() {
        guard let state = gooseState else { return }
        engine.hatchNewEgg(state: state)
        showDeathScreen = false
    }

    private func triggerReaction(_ reaction: GooseReaction) {
        currentReaction = reaction
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.currentReaction = .none
        }
    }
}
