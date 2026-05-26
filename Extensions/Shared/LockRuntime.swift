import Foundation

/// Per-block lock runtime state, derived from UserDefaults timestamps.
enum LockRuntimeState {
    case locked
    case countdown(startedAt: TimeInterval)
    case unlocked(until: TimeInterval)
    case recentlyExpired(expiredAt: TimeInterval)
}

/// Shared helpers for deriving lock state from UserDefaults.
/// Used by ShieldConfigurationProvider, ShieldActionHandler, and ScreenTimeManager.
enum LockRuntime {
    static let countdownSeconds: TimeInterval = 5
    static let countdownTTL: TimeInterval = 10
    static let timesUpWindow: TimeInterval = 120

    static func state(blockID: String, now: TimeInterval, defaults: UserDefaults) -> LockRuntimeState {
        let countdownStarted = defaults.double(forKey: "lockCountdownStartedAt-\(blockID)")
        let unlockExpiry = defaults.double(forKey: "lockUnlockExpiry-\(blockID)")

        // Countdown takes priority
        if countdownStarted > 0 {
            let age = now - countdownStarted
            if age >= 0 && age < countdownTTL {
                return .countdown(startedAt: countdownStarted)
            }
        }

        // Check unlock expiry
        if unlockExpiry > 0 {
            if now < unlockExpiry {
                return .unlocked(until: unlockExpiry)
            }
            if now - unlockExpiry < timesUpWindow {
                return .recentlyExpired(expiredAt: unlockExpiry)
            }
        }

        return .locked
    }

    /// Read-only opens count (no reset side effects — safe for shield renders).
    static func opensUsedToday(blockID: String, defaults: UserDefaults) -> Int {
        let lastResetDate = defaults.object(forKey: "lockLastReset-\(blockID)") as? Date
        if let lastReset = lastResetDate, !Calendar.current.isDateInToday(lastReset) {
            return 0
        }
        return defaults.integer(forKey: "lockOpensUsed-\(blockID)")
    }

    static func opensRemaining(blockID: String, defaults: UserDefaults) -> Int {
        let used = opensUsedToday(blockID: blockID, defaults: defaults)
        let allowed = defaults.integer(forKey: "lockOpensAllowed-\(blockID)")
        return max(0, allowed - used)
    }

    static func unlockDuration(blockID: String, defaults: UserDefaults) -> Int {
        max(1, defaults.integer(forKey: "lockUnlockDuration-\(blockID)"))
    }
}
