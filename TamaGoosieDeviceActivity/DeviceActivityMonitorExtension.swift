import DeviceActivity
import FamilyControls
import ManagedSettings
import UserNotifications

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()
    private let defaults = UserDefaults(suiteName: "group.com.tamagoosie")!

    override init() {
        super.init()
        // Log that the extension process was launched by the system
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
        // Keep last 50 entries
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
        if let blockID = extractBlockID(from: activity) {
            applyBlockShield(blockID: blockID)
        }
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        logBreadcrumb("intervalWillEndWarning: \(activity.rawValue)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        logBreadcrumb("intervalDidEnd: \(activity.rawValue)")
        if let blockID = extractBlockID(from: activity) {
            removeBlockShield(blockID: blockID)
        } else {
            // Global distraction monitor cleanup
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            defaults.set(0, forKey: "distractionHitsToday")
            defaults.set(0, forKey: "distractionApproxMinutes")
            defaults.set(0, forKey: "lastPenaltyApproxMinutes")
        }
    }

    // MARK: - Threshold Events

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        logBreadcrumb("eventDidReachThreshold: event=\(event.rawValue) activity=\(activity.rawValue)")

        // Per-block app limit threshold
        if event.rawValue.hasPrefix("limit-") {
            let blockID = String(event.rawValue.dropFirst("limit-".count))
            applyBlockShield(blockID: blockID)
            return
        }

        // Backup shield event for schedule/blockNow/lock blocks
        if event.rawValue.hasPrefix("shield-") {
            let blockID = String(event.rawValue.dropFirst("shield-".count))
            applyBlockShield(blockID: blockID)
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

    // MARK: - Per-Block Shielding

    private func extractBlockID(from activity: DeviceActivityName) -> String? {
        let raw = activity.rawValue
        guard raw.hasPrefix("block-") else { return nil }
        return String(raw.dropFirst("block-".count))
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
