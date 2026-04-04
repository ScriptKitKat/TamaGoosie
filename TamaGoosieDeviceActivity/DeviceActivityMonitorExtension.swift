import DeviceActivity
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let defaults = UserDefaults(suiteName: "group.com.tamagoosie")!

    // Called each time a monitored app's usage crosses the configured threshold.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        let current = defaults.integer(forKey: "screenTimeThresholdEvents")
        defaults.set(current + 1, forKey: "screenTimeThresholdEvents")
    }

    // Called at the end of the daily monitoring window (midnight). Reset the counter.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        defaults.set(0, forKey: "screenTimeThresholdEvents")
    }
}
