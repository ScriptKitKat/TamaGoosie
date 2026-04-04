import Foundation
import FamilyControls
import DeviceActivity

// MARK: - DeviceActivity name constants

extension DeviceActivityName {
    static let daily = Self("daily")
}

extension DeviceActivityEvent.Name {
    static let distractionThreshold = Self("distractionThreshold")
}

// MARK: - ScreenTimeManager

/// Manages FamilyControls authorization, app selection, and DeviceActivity monitoring.
/// Communicates threshold events to the main app via App Group UserDefaults.
///
/// - Note: Requires the `com.apple.developer.family-controls` entitlement.
///   For App Store distribution, request approval at developer.apple.com.
@Observable
@MainActor
final class ScreenTimeManager {

    static let shared = ScreenTimeManager()

    var authorizationStatus: AuthorizationStatus = .notDetermined
    var selection = FamilyActivitySelection()

    var isAuthorized: Bool { authorizationStatus == .approved }
    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    private let authCenter = AuthorizationCenter.shared
    private let activityCenter = DeviceActivityCenter()
    private let defaults = UserDefaults(suiteName: GoosieConstants.appGroupID)!

    private init() {
        authorizationStatus = authCenter.authorizationStatus
        loadSelection()
        if isAuthorized && hasSelection {
            startDailyMonitoring()
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            try await authCenter.requestAuthorization(for: .individual)
            authorizationStatus = authCenter.authorizationStatus
            if isAuthorized && hasSelection {
                startDailyMonitoring()
            }
        } catch {
            // Authorization may be denied or already in a terminal state.
            authorizationStatus = authCenter.authorizationStatus
        }
    }

    // MARK: - Selection

    func saveSelection(_ newSelection: FamilyActivitySelection) {
        selection = newSelection
        if let data = try? PropertyListEncoder().encode(newSelection) {
            defaults.set(data, forKey: GoosieConstants.screenTimeSelectionKey)
        }
        startDailyMonitoring()
    }

    private func loadSelection() {
        guard let data = defaults.data(forKey: GoosieConstants.screenTimeSelectionKey),
              let loaded = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        selection = loaded
    }

    // MARK: - Monitoring

    func startDailyMonitoring() {
        guard isAuthorized, hasSelection else { return }

        activityCenter.stopMonitoring()

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: GoosieConstants.screenTimeThresholdMinutes)
        )

        do {
            try activityCenter.startMonitoring(
                .daily,
                during: schedule,
                events: [.distractionThreshold: event]
            )
        } catch {
            // Monitoring may fail if entitlement is missing or selection is invalid.
            print("[ScreenTimeManager] startMonitoring failed: \(error)")
        }
    }

    func stopMonitoring() {
        activityCenter.stopMonitoring()
    }

    // MARK: - Threshold Event Consumption

    /// Returns the number of threshold events that fired since last call, then clears the counter.
    /// Each event represents `GoosieConstants.screenTimeThresholdMinutes` of tracked app usage.
    func consumePendingThresholdEvents() -> Int {
        let count = defaults.integer(forKey: GoosieConstants.screenTimeThresholdEventsKey)
        if count > 0 {
            defaults.set(0, forKey: GoosieConstants.screenTimeThresholdEventsKey)
        }
        return count
    }
}
