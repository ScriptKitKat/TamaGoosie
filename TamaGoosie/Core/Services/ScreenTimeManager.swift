import Foundation
import FamilyControls
import DeviceActivity

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
        if isAuthorized && hasSelection && !isPaused {
            startDailyMonitoring()
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            try await authCenter.requestAuthorization(for: .individual)
            authorizationStatus = authCenter.authorizationStatus
            if isAuthorized && hasSelection && !isPaused {
                startDailyMonitoring()
            }
        } catch {
            authorizationStatus = authCenter.authorizationStatus
        }
    }

    // MARK: - Selection

    func saveSelection(_ newSelection: FamilyActivitySelection) {
        selection = newSelection
        if let data = try? PropertyListEncoder().encode(newSelection) {
            defaults.set(data, forKey: GoosieConstants.screenTimeSelectionKey)
        }
        if !isPaused {
            startDailyMonitoring()
        }
    }

    private func loadSelection() {
        guard let data = defaults.data(forKey: GoosieConstants.screenTimeSelectionKey),
              let loaded = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        selection = loaded
    }

    // MARK: - Limit Management

    var userLimitMinutes: Int {
        get {
            let stored = defaults.integer(forKey: GoosieConstants.screenTimeLimitKey)
            return stored > 0 ? stored : GoosieConstants.screenTimeDefaultLimitMinutes
        }
        set {
            defaults.set(newValue, forKey: GoosieConstants.screenTimeLimitKey)
            if !isPaused { startDailyMonitoring() }
        }
    }

    var approxMinutesToday: Int {
        defaults.integer(forKey: GoosieConstants.screenTimeApproxMinutesKey)
    }

    // MARK: - Setup Complete

    var isSetupComplete: Bool {
        get { defaults.bool(forKey: GoosieConstants.screenTimeSetupCompleteKey) }
        set { defaults.set(newValue, forKey: GoosieConstants.screenTimeSetupCompleteKey) }
    }

    // MARK: - Pause

    var isPaused: Bool {
        get { defaults.bool(forKey: GoosieConstants.screenTimePausedKey) }
        set {
            defaults.set(newValue, forKey: GoosieConstants.screenTimePausedKey)
            if newValue {
                stopMonitoring()
            } else if isAuthorized && hasSelection {
                startDailyMonitoring()
            }
        }
    }

    // MARK: - Schedule

    var isAllDay: Bool {
        get {
            if defaults.object(forKey: GoosieConstants.screenTimeIsAllDayKey) == nil { return true }
            return defaults.bool(forKey: GoosieConstants.screenTimeIsAllDayKey)
        }
        set {
            defaults.set(newValue, forKey: GoosieConstants.screenTimeIsAllDayKey)
            if !isPaused { startDailyMonitoring() }
        }
    }

    var scheduleStartHour: Int {
        get { defaults.object(forKey: GoosieConstants.screenTimeStartHourKey) == nil ? 8 : defaults.integer(forKey: GoosieConstants.screenTimeStartHourKey) }
        set { defaults.set(newValue, forKey: GoosieConstants.screenTimeStartHourKey) }
    }

    var scheduleStartMinute: Int {
        get { defaults.integer(forKey: GoosieConstants.screenTimeStartMinuteKey) }
        set { defaults.set(newValue, forKey: GoosieConstants.screenTimeStartMinuteKey) }
    }

    var scheduleEndHour: Int {
        get { defaults.object(forKey: GoosieConstants.screenTimeEndHourKey) == nil ? 22 : defaults.integer(forKey: GoosieConstants.screenTimeEndHourKey) }
        set { defaults.set(newValue, forKey: GoosieConstants.screenTimeEndHourKey) }
    }

    var scheduleEndMinute: Int {
        get { defaults.integer(forKey: GoosieConstants.screenTimeEndMinuteKey) }
        set { defaults.set(newValue, forKey: GoosieConstants.screenTimeEndMinuteKey) }
    }

    var activeDays: Set<Int> {
        get {
            if let array = defaults.array(forKey: GoosieConstants.screenTimeActiveDaysKey) as? [Int] {
                return Set(array)
            }
            return Set(1...7)
        }
        set {
            defaults.set(Array(newValue), forKey: GoosieConstants.screenTimeActiveDaysKey)
            if !isPaused { startDailyMonitoring() }
        }
    }

    // MARK: - Monitoring

    func startDailyMonitoring() {
        guard isAuthorized, hasSelection else { return }

        let weekday = Calendar.current.component(.weekday, from: .now)
        guard activeDays.contains(weekday) else {
            stopMonitoring()
            return
        }

        activityCenter.stopMonitoring()

        let startComps: DateComponents
        let endComps: DateComponents

        if isAllDay {
            startComps = DateComponents(hour: 0, minute: 0)
            endComps = DateComponents(hour: 23, minute: 59)
        } else {
            startComps = DateComponents(hour: scheduleStartHour, minute: scheduleStartMinute)
            endComps = DateComponents(hour: scheduleEndHour, minute: scheduleEndMinute)
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd: endComps,
            repeats: true
        )

        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = Dictionary(
            uniqueKeysWithValues: GoosieConstants.screenTimeThresholds.map { mins in
                let name = DeviceActivityEvent.Name("distraction-\(mins)")
                let event = DeviceActivityEvent(
                    applications: selection.applicationTokens,
                    categories: selection.categoryTokens,
                    webDomains: selection.webDomainTokens,
                    threshold: DateComponents(minute: mins)
                )
                return (name, event)
            }
        )

        do {
            try activityCenter.startMonitoring(
                DeviceActivityName("daily-distraction"),
                during: schedule,
                events: events
            )
        } catch {
            print("[ScreenTimeManager] startMonitoring failed: \(error)")
        }
    }

    func stopMonitoring() {
        activityCenter.stopMonitoring()
    }

    // MARK: - Per-Block Monitoring

    func registerBlock(_ block: ScreenBlock) {
        guard isAuthorized else { return }
        guard let selection = block.selection else { return }

        let blockID = block.id.uuidString
        let activityName = DeviceActivityName("block-\(blockID)")

        // Stop any existing monitor for this block
        activityCenter.stopMonitoring([activityName])

        let startComps: DateComponents
        let endComps: DateComponents

        switch block.type {
        case "blockNow":
            // Block Now: monitor from now until duration expires
            // The timer handles completion; we just need the shield active
            startComps = DateComponents(hour: 0, minute: 0)
            endComps = DateComponents(hour: 23, minute: 59)

        case "schedule":
            guard !block.isVacationMode else { return }
            startComps = DateComponents(hour: block.scheduleStartHour, minute: block.scheduleStartMinute)
            endComps = DateComponents(hour: block.scheduleEndHour, minute: block.scheduleEndMinute)

        case "appLimit":
            // App Limit: monitor all day, with threshold event at the limit
            startComps = DateComponents(hour: 0, minute: 0)
            endComps = DateComponents(hour: 23, minute: 59)

        case "lock":
            // Lock: monitor all day
            startComps = DateComponents(hour: 0, minute: 0)
            endComps = DateComponents(hour: 23, minute: 59)

        default:
            return
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd: endComps,
            repeats: block.type != "blockNow"
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        if block.type == "appLimit" {
            let eventName = DeviceActivityEvent.Name("limit-\(blockID)")
            events[eventName] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: block.timeLimitMinutes)
            )
        }

        do {
            try activityCenter.startMonitoring(activityName, during: schedule, events: events)
        } catch {
            print("[ScreenTimeManager] registerBlock failed for \(block.name): \(error)")
        }
    }

    func unregisterBlock(_ block: ScreenBlock) {
        let activityName = DeviceActivityName("block-\(block.id.uuidString)")
        activityCenter.stopMonitoring([activityName])
    }

    func refreshAllBlocks(_ blocks: [ScreenBlock]) {
        for block in blocks where !block.isPast {
            registerBlock(block)
        }
    }
}
