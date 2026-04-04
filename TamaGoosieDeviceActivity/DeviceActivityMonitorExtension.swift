import DeviceActivity
import FamilyControls
import ManagedSettings
import UserNotifications

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()
    private let defaults = UserDefaults(suiteName: "group.com.tamagoosie")!

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
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

    override func intervalDidEnd(for activity: DeviceActivityName) {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        defaults.set(0, forKey: "distractionHitsToday")
        defaults.set(0, forKey: "distractionApproxMinutes")
        defaults.set(0, forKey: "lastPenaltyApproxMinutes")
    }

    // MARK: - Shielding

    private func shieldSelectedApps() {
        guard let data = defaults.data(forKey: "screenTimeSelection"),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }

        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
    }

    // MARK: - Notifications

    private func sendNotification(approxMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Harold is worried"
        content.body = approxMinutes >= 60
            ? "You've been on distracting apps for over an hour... I'm getting sad"
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
