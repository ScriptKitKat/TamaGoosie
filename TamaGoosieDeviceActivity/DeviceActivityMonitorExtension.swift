import DeviceActivity
import FamilyControls
import ManagedSettings
import UserNotifications

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()
    private let defaults = UserDefaults(suiteName: "group.com.tamagoosie")!

    // MARK: - Interval Lifecycle

    override func intervalDidStart(for activity: DeviceActivityName) {
        if let blockID = extractBlockID(from: activity) {
            applyBlockShield(blockID: blockID)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
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
        // Per-block app limit threshold
        if event.rawValue.hasPrefix("limit-") {
            let blockID = String(event.rawValue.dropFirst("limit-".count))
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
        guard let data = defaults.data(forKey: "blockShield-\(blockID)"),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }

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
