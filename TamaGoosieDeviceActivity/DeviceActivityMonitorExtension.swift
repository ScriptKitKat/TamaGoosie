import DeviceActivity
import FamilyControls
import ManagedSettings
import UserNotifications

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()
    private let defaults = UserDefaults(suiteName: "group.com.tamagoosie")!

    override init() {
        super.init()
        let ts = ISO8601DateFormatter().string(from: Date())
        let ud = UserDefaults(suiteName: "group.com.tamagoosie")!
        ud.synchronize()
        var log = ud.stringArray(forKey: "extensionBreadcrumbs") ?? []
        log.append("[\(ts)] EXTENSION INIT — process launched")
        if log.count > 50 { log = Array(log.suffix(50)) }
        ud.set(log, forKey: "extensionBreadcrumbs")
        ud.set(Date().timeIntervalSince1970, forKey: "extensionLastCallback")
        ud.synchronize()
    }

    // MARK: - Diagnostic Breadcrumbs

    private func logBreadcrumb(_ message: String) {
        defaults.synchronize()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)"

        var log = defaults.stringArray(forKey: "extensionBreadcrumbs") ?? []
        log.append(entry)
        if log.count > 50 { log = Array(log.suffix(50)) }
        defaults.set(log, forKey: "extensionBreadcrumbs")
        defaults.set(Date().timeIntervalSince1970, forKey: "extensionLastCallback")
        defaults.synchronize()
    }

    // MARK: - Interval Lifecycle

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        logBreadcrumb("intervalWillStartWarning: \(activity.rawValue)")
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        logBreadcrumb("intervalDidStart: \(activity.rawValue)")
        defaults.synchronize()

        // Handle unlock relock: temporary monitor fires at unlock expiry
        // Keep lockUnlockExpiry so the ShieldConfigurationProvider can detect
        // "time's up" state (expired = in the past). The reconciler already
        // handles expired entries correctly (only skips if unexpired).
        if let blockID = extractUnlockBlockID(from: activity) {
            logBreadcrumb("intervalDidStart: unlock-\(blockID) expired — re-shielding")

            // Clear any stale countdown state for this block
            defaults.removeObject(forKey: "lockCountdownStartedAt-\(blockID)")
            defaults.synchronize()

            // lockUnlockExpiry is kept — ShieldConfigurationProvider uses
            // LockRuntime.state() to derive "recentlyExpired" from the
            // now-past expiry timestamp, showing the time's-up UI.
            LockShieldReconciler.reconcile()
            return
        }

        if let blockID = extractBlockID(from: activity) {
            let blockType = defaults.string(forKey: "blockType-\(blockID)") ?? ""

            // Schedule blocks: flag the schedule as active so Rule A precedence
            // checks can see it from this process and from the main app.
            if blockType == "schedule" {
                defaults.set(true, forKey: "scheduleActive-\(blockID)")
                defaults.synchronize()
                logBreadcrumb("intervalDidStart: schedule block \(blockID) — flagged active")
            }

            // App limits: wait for threshold, don't shield now
            if blockType == "appLimit" {
                logBreadcrumb("intervalDidStart: appLimit block \(blockID) — skipping shield (waiting for threshold)")
                return
            }

            // Lock blocks: daily reset + reconcile
            if blockType == "lock" {
                defaults.set(0, forKey: "lockOpensUsed-\(blockID)")
                defaults.set(Date(), forKey: "lockLastReset-\(blockID)")
                defaults.removeObject(forKey: "lockUnlockExpiry-\(blockID)")
                defaults.removeObject(forKey: "lockCountdownStartedAt-\(blockID)")
                defaults.synchronize()
                logBreadcrumb("intervalDidStart: lock block \(blockID) — daily reset")
                // Clear old per-block named store (migration from old approach)
                ManagedSettingsStore(named: .init("block-\(blockID)")).clearAllSettings()
                LockShieldReconciler.reconcile()
                return
            }

            // Schedule / blockNow: use per-block named store
            applyBlockShield(blockID: blockID)
        }
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        logBreadcrumb("intervalWillEndWarning: \(activity.rawValue)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        logBreadcrumb("intervalDidEnd: \(activity.rawValue)")

        // Unlock monitor end-of-day cleanup.
        //
        // iOS also fires intervalDidEnd when an active unlock-<id> monitor is
        // REPLACED by a new startMonitoring call (e.g. user re-unlocks from the
        // time's-up shield, which schedules a new monitor for the new expiry).
        // In that case the new expiry sits in the future — we must NOT clobber it,
        // or the next reconcile() will treat the block as .locked and re-shield
        // the app immediately, burning the unlock the user just spent.
        if let blockID = extractUnlockBlockID(from: activity) {
            let expiry = defaults.double(forKey: "lockUnlockExpiry-\(blockID)")
            let now = Date().timeIntervalSince1970
            let isStaleExpiry = expiry > 0 && now - expiry >= LockRuntime.timesUpWindow
            if isStaleExpiry {
                logBreadcrumb("intervalDidEnd: unlock-\(blockID) clearing stale expiry")
                defaults.removeObject(forKey: "lockUnlockExpiry-\(blockID)")
                defaults.synchronize()
            } else {
                logBreadcrumb("intervalDidEnd: unlock-\(blockID) keep expiry (future or within times-up window)")
            }
            LockShieldReconciler.reconcile()
            return
        }

        if let blockID = extractBlockID(from: activity) {
            let blockType = defaults.string(forKey: "blockType-\(blockID)") ?? ""

            // Schedule blocks: clear active flag so precedence checks stop matching.
            if blockType == "schedule" {
                defaults.set(false, forKey: "scheduleActive-\(blockID)")
                defaults.synchronize()
            }

            // Lock blocks: reconciler handles shield state, just log
            if blockType == "lock" {
                logBreadcrumb("intervalDidEnd: lock block \(blockID) — reconciler manages shield")
                return
            }

            // Non-lock blocks: clear per-block named store
            removeBlockShield(blockID: blockID)
        } else {
            // Global distraction monitor cleanup
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            defaults.set(0, forKey: "distractionHitsToday")
            defaults.set(0, forKey: "distractionApproxMinutes")
            defaults.set(0, forKey: "lastPenaltyApproxMinutes")
            // Re-apply lock shields that may have been on the default store
            LockShieldReconciler.reconcile()
        }
    }

    // MARK: - Threshold Events

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        logBreadcrumb("eventDidReachThreshold: event=\(event.rawValue) activity=\(activity.rawValue)")

        // Per-block app limit threshold
        if event.rawValue.hasPrefix("limit-") {
            let blockID = String(event.rawValue.dropFirst("limit-".count))
            // Rule A v1 simplification: if this limit's tokens are fully covered
            // by an active schedule, skip the redundant shield. The schedule already
            // shields these apps; applying a duplicate appLimit shield complicates
            // teardown.
            if BlockPrecedence.limitFullyCoveredByActiveSchedule(limitID: blockID, in: defaults) {
                logBreadcrumb("limit-\(blockID) shield skipped — fully covered by active schedule")
                return
            }
            applyBlockShield(blockID: blockID)
            return
        }

        // Shield event for schedule/blockNow/lock blocks
        if event.rawValue.hasPrefix("shield-") {
            let blockID = String(event.rawValue.dropFirst("shield-".count))
            let blockType = defaults.string(forKey: "blockType-\(blockID)") ?? ""
            if blockType == "lock" {
                LockShieldReconciler.reconcile()
            } else {
                applyBlockShield(blockID: blockID)
            }
            return
        }

        // Global distraction threshold
        let hits = defaults.integer(forKey: "distractionHitsToday") + 1
        defaults.set(hits, forKey: "distractionHitsToday")
        defaults.set(Date().timeIntervalSince1970, forKey: "lastDistractionHit")

        let approxMinutes = Int(event.rawValue.replacingOccurrences(of: "distraction-", with: "")) ?? 0
        let current = defaults.integer(forKey: "distractionApproxMinutes")
        defaults.set(max(current, approxMinutes), forKey: "distractionApproxMinutes")

        let userLimit = defaults.integer(forKey: "distractionLimitMinutes")
        if userLimit > 0, approxMinutes >= userLimit {
            shieldSelectedApps()
        }

        sendNotification(approxMinutes: approxMinutes)
    }

    // MARK: - Per-Block Shielding (non-lock blocks only)

    private func extractBlockID(from activity: DeviceActivityName) -> String? {
        let raw = activity.rawValue
        guard raw.hasPrefix("block-") else { return nil }
        return String(raw.dropFirst("block-".count))
    }

    private func extractUnlockBlockID(from activity: DeviceActivityName) -> String? {
        let raw = activity.rawValue
        guard raw.hasPrefix("unlock-") else { return nil }
        return String(raw.dropFirst("unlock-".count))
    }

    private func applyBlockShield(blockID: String) {
        guard let data = defaults.data(forKey: "blockShield-\(blockID)") else {
            logBreadcrumb("applyBlockShield FAILED: no data for blockShield-\(blockID)")
            return
        }
        guard let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            logBreadcrumb("applyBlockShield FAILED: decode failed for blockShield-\(blockID)")
            return
        }

        logBreadcrumb("applyBlockShield OK: \(blockID) apps=\(selection.applicationTokens.count) cats=\(selection.categoryTokens.count)")

        let blockStore = ManagedSettingsStore(named: .init("block-\(blockID)"))
        if !selection.applicationTokens.isEmpty {
            blockStore.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            blockStore.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        if !selection.webDomainTokens.isEmpty {
            blockStore.shield.webDomains = selection.webDomainTokens
        }
    }

    private func removeBlockShield(blockID: String) {
        logBreadcrumb("removeBlockShield: \(blockID)")
        let blockStore = ManagedSettingsStore(named: .init("block-\(blockID)"))
        blockStore.clearAllSettings()
    }

    // MARK: - Global Distraction Shielding

    private func shieldSelectedApps() {
        guard let data = defaults.data(forKey: "screenTimeSelection"),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }

        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
    }

    // MARK: - Goose Name

    private var gooseName: String {
        guard let data = defaults.data(forKey: "gooseStats"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else {
            return "Your goose"
        }
        return name
    }

    // MARK: - Notifications

    private func sendNotification(approxMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(gooseName) is worried"
        content.body = approxMinutes >= 60
            ? "You've been on distracting apps for over an hour... \(gooseName) is getting sad"
            : "You've hit \(approxMinutes) minutes on distracting apps today"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "distraction-\(approxMinutes)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
