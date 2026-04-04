import ActivityKit
import Foundation

@Observable
final class GooseLiveActivityManager {
    static let shared = GooseLiveActivityManager()

    private(set) var currentActivity: Activity<GoosePetActivity>?
    private(set) var isActive = false

    private init() {}

    // MARK: - Start

    func startPetActivity(gooseName: String, state: GooseState, currentGoal: Goal? = nil) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = GoosePetActivity(gooseName: gooseName)
        let contentState = makeContentState(from: state, currentGoal: currentGoal)

        let content = ActivityContent(state: contentState, staleDate: Date.now.addingTimeInterval(GoosieConstants.liveActivityMaxHours * 3600))

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            isActive = true
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update

    func updateStats(state: GooseState, currentGoal: Goal? = nil) {
        guard let activity = currentActivity else { return }

        let contentState = makeContentState(from: state, currentGoal: currentGoal)
        let content = ActivityContent(state: contentState, staleDate: nil)

        Task {
            await activity.update(content)
        }
    }

    func startFocusMode(state: GooseState, minutesRemaining: Int) {
        guard let activity = currentActivity else { return }

        var contentState = makeContentState(from: state)
        contentState.isFocusing = true
        contentState.focusMinutesRemaining = minutesRemaining

        let content = ActivityContent(state: contentState, staleDate: nil)

        Task {
            await activity.update(content)
        }
    }

    func endFocusMode(state: GooseState, currentGoal: Goal? = nil) {
        updateStats(state: state, currentGoal: currentGoal)
    }

    // MARK: - End

    func endActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
            self.isActive = false
        }
    }

    // MARK: - Helpers

    private func makeContentState(from state: GooseState, currentGoal: Goal? = nil) -> GoosePetActivity.ContentState {
        GoosePetActivity.ContentState(
            healthiness: state.healthiness,
            happiness: state.happiness,
            mood: state.mood,
            level: state.level,
            streakDays: state.streakDays,
            currentGoalTitle: currentGoal?.title,
            currentGoalProgress: currentGoal?.progress,
            isFocusing: false,
            focusMinutesRemaining: nil
        )
    }
}
