import Foundation

// MARK: - Escalation State

struct EscalationState: Codable {
    /// Highest push level that has been scheduled (0 = not started)
    var scheduledThroughLevel: Int = 0
    var lastPushDate: Date? = nil
    var pausedUntil: Date? = nil
    var consecutiveFailures: Int = 0
}

// MARK: - Escalation Tracker

/// Persists per-goal push escalation state in UserDefaults.
/// Has no SwiftData dependency — only needs goal UUIDs.
final class EscalationTracker {
    static let shared = EscalationTracker()
    private let defaults = UserDefaults.standard
    private init() {}

    private func key(for goalID: UUID) -> String { "esc_\(goalID.uuidString)" }

    func state(for goalID: UUID) -> EscalationState {
        guard let data = defaults.data(forKey: key(for: goalID)),
              let state = try? JSONDecoder().decode(EscalationState.self, from: data)
        else { return EscalationState() }
        return state
    }

    func setState(_ s: EscalationState, for goalID: UUID) {
        if let data = try? JSONEncoder().encode(s) {
            defaults.set(data, forKey: key(for: goalID))
        }
    }

    func isPaused(for goalID: UUID) -> Bool {
        guard let until = state(for: goalID).pausedUntil else { return false }
        return until > Date.now
    }

    func advanceScheduledLevel(for goalID: UUID, through level: Int) {
        var s = state(for: goalID)
        s.scheduledThroughLevel = level
        s.lastPushDate = .now
        setState(s, for: goalID)
    }

    func reset(for goalID: UUID) {
        var s = state(for: goalID)
        s.scheduledThroughLevel = 0
        s.pausedUntil = nil
        s.lastPushDate = nil
        setState(s, for: goalID)
    }

    func pause(for goalID: UUID, hours: Int) {
        var s = state(for: goalID)
        s.pausedUntil = Date.now.addingTimeInterval(Double(hours) * 3600)
        setState(s, for: goalID)
    }

    func recordFailure(for goalID: UUID) {
        var s = state(for: goalID)
        s.consecutiveFailures += 1
        setState(s, for: goalID)
    }

    func resetFailures(for goalID: UUID) {
        var s = state(for: goalID)
        s.consecutiveFailures = 0
        setState(s, for: goalID)
    }
}
