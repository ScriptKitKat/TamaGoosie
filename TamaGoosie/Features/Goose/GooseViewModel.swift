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
        gooseState?.currentMood ?? .neutral
    }

    var phase: GoosePhase {
        gooseState?.currentPhase ?? .baby
    }

    var moodText: String {
        mood.displayName
    }

    var healthPercent: Double {
        gooseState?.health ?? 0
    }

    var happinessPercent: Double {
        gooseState?.happiness ?? 0
    }

    var energyPercent: Double {
        gooseState?.energy ?? 0
    }

    var hygienePercent: Double {
        gooseState?.hygiene ?? 0
    }

    var gooseName: String {
        gooseState?.name ?? "Harnold"
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

    func feedGoose() {
        guard let state = gooseState, !state.isDead else { return }
        state.health = min(GoosieConstants.statMax, state.health + 10)
        state.hygiene = max(GoosieConstants.statMin, state.hygiene - 3)
        state.clampStats()
        state.updateMood()
        triggerReaction(.feed)
    }

    func cleanGoose() {
        guard let state = gooseState, !state.isDead else { return }
        state.hygiene = min(GoosieConstants.statMax, state.hygiene + 15)
        state.clampStats()
        state.updateMood()
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
