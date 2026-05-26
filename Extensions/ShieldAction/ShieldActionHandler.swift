import Foundation
import ManagedSettings
import ManagedSettingsUI
import DeviceActivity
import FamilyControls

final class ShieldActionHandler: ShieldActionDelegate {

    private let defaults = UserDefaults(suiteName: "group.com.tamagoosie")!

    // MARK: - ShieldActionDelegate

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        logBreadcrumb("handle app: \(action == .primaryButtonPressed ? "primary" : "secondary")")
        switch action {
        case .primaryButtonPressed:
            cancelCountdowns(forApp: application)
            completionHandler(.close)
        case .secondaryButtonPressed:
            handleUnlockTap(forApp: application, completionHandler: completionHandler)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        logBreadcrumb("handle category: \(action == .primaryButtonPressed ? "primary" : "secondary")")
        switch action {
        case .primaryButtonPressed:
            cancelCountdowns(forCategory: category)
            completionHandler(.close)
        case .secondaryButtonPressed:
            handleUnlockTap(forCategory: category, completionHandler: completionHandler)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        logBreadcrumb("handle web: \(action == .primaryButtonPressed ? "primary" : "secondary")")
        completionHandler(.close)
    }

    // MARK: - Unlock Flow

    private func handleUnlockTap(forApp token: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        defaults.synchronize()
        let matchIDs = findLockBlockIDs(forApp: token)
        logBreadcrumb("unlock tap app matchedIDs=\(shortIDs(matchIDs))")
        handleUnlock(matchIDs: matchIDs, completionHandler: completionHandler)
    }

    private func handleUnlockTap(forCategory token: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        defaults.synchronize()
        let matchIDs = findLockBlockIDs(forCategory: token)
        logBreadcrumb("unlock tap category matchedIDs=\(shortIDs(matchIDs))")
        handleUnlock(matchIDs: matchIDs, completionHandler: completionHandler)
    }

    private func handleUnlock(matchIDs: [String], completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard !matchIDs.isEmpty else {
            completionHandler(.none)
            return
        }

        let now = Date().timeIntervalSince1970

        // If any are in countdown, this tap cancels them
        let countdownIDs = matchIDs.filter {
            if case .countdown = LockRuntime.state(blockID: $0, now: now, defaults: defaults) { return true }
            return false
        }
        if !countdownIDs.isEmpty {
            for id in countdownIDs {
                defaults.removeObject(forKey: "lockCountdownStartedAt-\(id)")
            }
            defaults.synchronize()
            logBreadcrumb("cancel countdown: \(shortIDs(countdownIDs))")
            completionHandler(.defer)
            return
        }

        // Find blocks that can be unlocked (not currently unlocked + has opens remaining)
        let unlockableIDs = matchIDs.filter { id in
            let state = LockRuntime.state(blockID: id, now: now, defaults: defaults)
            if case .unlocked = state { return false }
            return LockRuntime.opensRemaining(blockID: id, defaults: defaults) > 0
        }

        guard !unlockableIDs.isEmpty else {
            logBreadcrumb("unlock denied: no unlockable locks")
            completionHandler(.none)
            return
        }

        // Unlock immediately (countdown disabled for debugging)
        for id in unlockableIDs {
            let durationMinutes = LockRuntime.unlockDuration(blockID: id, defaults: defaults)
            let expiry = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
            let used = lockOpensUsedToday(blockID: id)
            defaults.set(used + 1, forKey: "lockOpensUsed-\(id)")
            defaults.set(expiry.timeIntervalSince1970, forKey: "lockUnlockExpiry-\(id)")
        }
        defaults.synchronize()
        logBreadcrumb("immediate unlock: \(shortIDs(unlockableIDs))")

        LockShieldReconciler.reconcile()

        if let expiry = unlockableIDs.compactMap({ id -> Date? in
            let ts = defaults.double(forKey: "lockUnlockExpiry-\(id)")
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }).min() {
            startRelockMonitor(expiry: expiry, primaryBlockID: unlockableIDs[0])
        }

        completionHandler(.defer)
    }

    private func completeCountdownUnlock(blockIDs: [String]) {
        defaults.synchronize()
        let now = Date().timeIntervalSince1970
        var unlockedIDs: [String] = []
        var earliestExpiry: Date?

        for id in blockIDs {
            let started = defaults.double(forKey: "lockCountdownStartedAt-\(id)")
            guard started > 0,
                  now - started >= LockRuntime.countdownSeconds,
                  now - started < LockRuntime.countdownTTL + LockRuntime.countdownSeconds
            else {
                defaults.removeObject(forKey: "lockCountdownStartedAt-\(id)")
                continue
            }

            guard LockRuntime.opensRemaining(blockID: id, defaults: defaults) > 0 else {
                defaults.removeObject(forKey: "lockCountdownStartedAt-\(id)")
                continue
            }

            let durationMinutes = LockRuntime.unlockDuration(blockID: id, defaults: defaults)
            let expiry = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))

            let used = lockOpensUsedToday(blockID: id)
            defaults.set(used + 1, forKey: "lockOpensUsed-\(id)")
            defaults.set(expiry.timeIntervalSince1970, forKey: "lockUnlockExpiry-\(id)")
            defaults.removeObject(forKey: "lockCountdownStartedAt-\(id)")

            unlockedIDs.append(id)
            if earliestExpiry == nil || expiry < earliestExpiry! {
                earliestExpiry = expiry
            }
        }

        defaults.synchronize()

        guard !unlockedIDs.isEmpty else {
            logBreadcrumb("unlock completion: no blocks unlocked")
            return
        }

        LockShieldReconciler.reconcile()
        logBreadcrumb("unlock completed: \(shortIDs(unlockedIDs))")

        // Best-effort wake-up at earliest expiry
        if let expiry = earliestExpiry {
            startRelockMonitor(expiry: expiry, primaryBlockID: unlockedIDs[0])
        }
    }

    // MARK: - Cancel Countdowns

    private func cancelCountdowns(forApp token: ApplicationToken) {
        defaults.synchronize()
        let matchIDs = findLockBlockIDs(forApp: token)
        cancelCountdowns(blockIDs: matchIDs)
    }

    private func cancelCountdowns(forCategory token: ActivityCategoryToken) {
        defaults.synchronize()
        let matchIDs = findLockBlockIDs(forCategory: token)
        cancelCountdowns(blockIDs: matchIDs)
    }

    private func cancelCountdowns(blockIDs: [String]) {
        let now = Date().timeIntervalSince1970
        var cancelled = false
        for id in blockIDs {
            if case .countdown = LockRuntime.state(blockID: id, now: now, defaults: defaults) {
                defaults.removeObject(forKey: "lockCountdownStartedAt-\(id)")
                cancelled = true
            }
        }
        if cancelled { defaults.synchronize() }
    }

    // MARK: - Lock Block Lookup

    private func findLockBlockIDs(forApp token: ApplicationToken) -> [String] {
        let blockIDs = defaults.stringArray(forKey: "activeLockBlockIDs") ?? []
        let decoder = PropertyListDecoder()
        return blockIDs.compactMap { blockID in
            guard let data = defaults.data(forKey: "blockShield-\(blockID)"),
                  let sel = try? decoder.decode(FamilyActivitySelection.self, from: data)
            else { return nil }
            return sel.applicationTokens.contains(token) ? blockID : nil
        }
    }

    private func findLockBlockIDs(forCategory token: ActivityCategoryToken) -> [String] {
        let blockIDs = defaults.stringArray(forKey: "activeLockBlockIDs") ?? []
        let decoder = PropertyListDecoder()
        return blockIDs.compactMap { blockID in
            guard let data = defaults.data(forKey: "blockShield-\(blockID)"),
                  let sel = try? decoder.decode(FamilyActivitySelection.self, from: data)
            else { return nil }
            return sel.categoryTokens.contains(token) ? blockID : nil
        }
    }

    // MARK: - Relock Monitor

    private func startRelockMonitor(expiry: Date, primaryBlockID: String) {
        let cal = Calendar.current
        // Add 1 minute so the monitor fires AFTER the second-precise expiry.
        let relockTime = expiry.addingTimeInterval(60)
        let endHour = cal.component(.hour, from: relockTime)
        let endMinute = cal.component(.minute, from: relockTime)
        if endHour == 23 && endMinute >= 58 { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: endHour, minute: endMinute),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: false
        )

        do {
            try DeviceActivityCenter().startMonitoring(
                DeviceActivityName("unlock-\(primaryBlockID)"),
                during: schedule
            )
            logBreadcrumb("relockMonitor: \(String(primaryBlockID.prefix(8))) at \(endHour):\(String(format: "%02d", endMinute))")
        } catch {
            logBreadcrumb("relockMonitor FAILED: \(error)")
        }
    }

    // MARK: - Helpers

    /// Opens used today with reset side effect (appropriate for action handler).
    private func lockOpensUsedToday(blockID: String) -> Int {
        let lastResetDate = defaults.object(forKey: "lockLastReset-\(blockID)") as? Date
        if let lastReset = lastResetDate, !Calendar.current.isDateInToday(lastReset) {
            defaults.set(0, forKey: "lockOpensUsed-\(blockID)")
            defaults.set(Date(), forKey: "lockLastReset-\(blockID)")
            return 0
        }
        if lastResetDate == nil {
            defaults.set(Date(), forKey: "lockLastReset-\(blockID)")
        }
        return defaults.integer(forKey: "lockOpensUsed-\(blockID)")
    }

    private func shortIDs(_ ids: [String]) -> [String] {
        ids.map { String($0.prefix(8)) }
    }

    private static let isoFormatter = ISO8601DateFormatter()

    private func logBreadcrumb(_ message: String) {
        let ts = Self.isoFormatter.string(from: Date())
        var log = defaults.stringArray(forKey: "extensionBreadcrumbs") ?? []
        log.append("[\(ts)] ShieldAction: \(message)")
        if log.count > 50 { log = Array(log.suffix(50)) }
        defaults.set(log, forKey: "extensionBreadcrumbs")
        defaults.set(Date().timeIntervalSince1970, forKey: "extensionLastCallback")
        defaults.synchronize()
    }
}
