import ActivityKit
import Foundation

@Observable
final class GooseLiveActivityManager {
    static let shared = GooseLiveActivityManager()

    private(set) var currentActivity: Activity<GoosePetActivity>?
    private(set) var isActive = false

    // MARK: - Wandering state
    private var gooseX: Double = 0.3
    private var isMovingRight: Bool = true
    private var wanderTimer: Timer?

    // Last known ContentState — wander timer updates just the position fields
    private var cachedContentState: GoosePetActivity.ContentState?

    private init() {}

    // MARK: - Start

    func startPetActivity(gooseName: String, state: GooseState, currentGoal: Goal? = nil) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = GoosePetActivity(gooseName: gooseName)
        let contentState = makeContentState(from: state, currentGoal: currentGoal)

        let content = ActivityContent(
            state: contentState,
            staleDate: Date.now.addingTimeInterval(GoosieConstants.liveActivityMaxHours * 3600)
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            cachedContentState = contentState
            isActive = true
            startWandering()
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update

    func updateStats(state: GooseState, currentGoal: Goal? = nil) {
        cachedContentState = makeContentState(from: state, currentGoal: currentGoal)
        updateCurrentActivity()
    }

    func startFocusMode(state: GooseState, minutesRemaining: Int) {
        guard let activity = currentActivity else { return }

        var contentState = makeContentState(from: state)
        contentState.isFocusing = true
        contentState.focusMinutesRemaining = minutesRemaining
        cachedContentState = contentState

        let content = ActivityContent(state: contentState, staleDate: nil)
        Task { await activity.update(content) }
    }

    func endFocusMode(state: GooseState, currentGoal: Goal? = nil) {
        updateStats(state: state, currentGoal: currentGoal)
    }

    // MARK: - End

    func endActivity() {
        stopWandering()
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
            self.isActive = false
        }
    }

    // MARK: - Wandering

    private func startWandering() {
        wanderTimer?.invalidate()
        wanderTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            advanceGoose()
            updateCurrentActivity()
        }
    }

    private func stopWandering() {
        wanderTimer?.invalidate()
        wanderTimer = nil
    }

    private func advanceGoose() {
        let step = Double.random(in: 0.10...0.20)
        if isMovingRight {
            gooseX = min(0.85, gooseX + step)
            if gooseX >= 0.85 { isMovingRight = false }
        } else {
            gooseX = max(0.15, gooseX - step)
            if gooseX <= 0.15 { isMovingRight = true }
        }
    }

    // MARK: - Helpers

    private func updateCurrentActivity() {
        guard let activity = currentActivity, var cs = cachedContentState else { return }
        cs.gooseX = gooseX
        cs.isMovingRight = isMovingRight
        cachedContentState = cs
        let content = ActivityContent(state: cs, staleDate: nil)
        Task { await activity.update(content) }
    }

    private func makeContentState(from state: GooseState, currentGoal: Goal? = nil) -> GoosePetActivity.ContentState {
        GoosePetActivity.ContentState(
            healthiness: state.healthiness,
            happiness: state.happiness,
            mood: state.mood,
            streakDays: state.streakDays,
            currentGoalTitle: currentGoal?.title,
            currentGoalProgress: currentGoal?.progress,
            isFocusing: false,
            focusMinutesRemaining: nil,
            gooseX: gooseX,
            isMovingRight: isMovingRight,
            spriteKey: spriteKey(for: state)
        )
    }

    private func spriteKey(for state: GooseState) -> String {
        switch state.currentMood {
        case .ecstatic, .happy:   return "happy"
        case .content, .bored:    return "neutral"
        case .sad:                return "sad"
        case .sick:               return "sick"
        }
    }
}
