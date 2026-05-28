import Foundation
import FamilyControls

/// Cross-process precedence rules for ScreenTime blocks (Rule A + Rule B).
///
/// All inputs come from the app-group UserDefaults shared between the main app
/// and the DeviceActivity / Shield / ShieldAction extensions — none of which
/// can read SwiftData. Keep this module pure: no side effects, just queries.
///
/// Keys read:
/// - `blockType-<id>` — `"schedule" | "appLimit" | "lock" | ...`
/// - `blockShield-<id>` — encoded `FamilyActivitySelection`
/// - `scheduleActive-<id>` — `Bool`, written by `DeviceActivityMonitorExtension`
/// - `appLimitMinutes-<id>` — `Int`, written by `ScreenTimeManager.registerBlock`
/// - `lockUnlockDuration-<id>` — `Int`, already written
enum BlockPrecedence {

    /// Base64 application-token keys for a stored selection.
    static func tokenKeys(forBlock blockID: String, in defaults: UserDefaults) -> Set<String> {
        guard let data = defaults.data(forKey: "blockShield-\(blockID)"),
              let sel = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return [] }
        return Set(sel.applicationTokens.compactMap {
            (try? JSONEncoder().encode($0))?.base64EncodedString()
        })
    }

    /// Union of application-token keys from every schedule whose `scheduleActive` flag is true.
    static func activeScheduleTokenKeys(in defaults: UserDefaults) -> Set<String> {
        var result = Set<String>()
        for (key, value) in defaults.dictionaryRepresentation()
        where key.hasPrefix("blockType-") && (value as? String) == "schedule" {
            let blockID = String(key.dropFirst("blockType-".count))
            guard defaults.bool(forKey: "scheduleActive-\(blockID)") else { continue }
            result.formUnion(tokenKeys(forBlock: blockID, in: defaults))
        }
        return result
    }

    /// First appLimit block whose tokens intersect this lock's tokens.
    /// Returns the appLimit block's id and its configured minute cap.
    static func intersectingAppLimit(
        lockID: String,
        in defaults: UserDefaults
    ) -> (id: String, limitMinutes: Int)? {
        let lockKeys = tokenKeys(forBlock: lockID, in: defaults)
        guard !lockKeys.isEmpty else { return nil }
        for (key, value) in defaults.dictionaryRepresentation()
        where key.hasPrefix("blockType-") && (value as? String) == "appLimit" {
            let otherID = String(key.dropFirst("blockType-".count))
            let otherKeys = tokenKeys(forBlock: otherID, in: defaults)
            if !lockKeys.isDisjoint(with: otherKeys) {
                let limit = defaults.integer(forKey: "appLimitMinutes-\(otherID)")
                if limit > 0 { return (otherID, limit) }
            }
        }
        return nil
    }

    enum Suppression {
        case allow
        case schedulePreempts        // Rule A
        case appLimitPrecedence(limit: Int)  // Rule B
    }

    /// Decide whether a new unlock for `lockID` should be allowed.
    /// `opensUsed` is the count BEFORE this attempt.
    static func evaluateUnlock(
        lockID: String,
        opensUsed: Int,
        in defaults: UserDefaults
    ) -> Suppression {
        let lockKeys = tokenKeys(forBlock: lockID, in: defaults)

        // Rule A: schedule preempts.
        if !lockKeys.isDisjoint(with: activeScheduleTokenKeys(in: defaults)) {
            return .schedulePreempts
        }

        // Rule B: appLimit overrides lock when the next unlock would push implied
        // minutes used past the cap (v1 proxy = opensUsed * unlockDurationMinutes).
        if let limit = intersectingAppLimit(lockID: lockID, in: defaults) {
            let d = LockRuntime.unlockDuration(blockID: lockID, defaults: defaults)
            if (opensUsed + 1) * d > limit.limitMinutes {
                return .appLimitPrecedence(limit: limit.limitMinutes)
            }
        }

        return .allow
    }

    /// True iff every application token of `limitID` is also owned by some active schedule.
    /// Used by `DeviceActivityMonitorExtension.eventDidReachThreshold` to skip the
    /// redundant appLimit shield while a schedule is already shielding the same apps.
    static func limitFullyCoveredByActiveSchedule(
        limitID: String,
        in defaults: UserDefaults
    ) -> Bool {
        let limitKeys = tokenKeys(forBlock: limitID, in: defaults)
        guard !limitKeys.isEmpty else { return false }
        return limitKeys.isSubset(of: activeScheduleTokenKeys(in: defaults))
    }
}
