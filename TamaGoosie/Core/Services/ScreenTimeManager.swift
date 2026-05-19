import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import BackgroundTasks

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

        // Only stop the daily-distraction monitor, NOT per-block monitors
        activityCenter.stopMonitoring([DeviceActivityName("daily-distraction")])

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
                    threshold: DateComponents(minute: mins),
                    includesPastActivity: true
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
        // Only stop the daily-distraction monitor, NOT per-block monitors
        activityCenter.stopMonitoring([DeviceActivityName("daily-distraction")])
    }

    // MARK: - Refresh Trigger

    /// Incrementing this forces @Observable to re-notify views that read usage data.
    var refreshTick: Int = 0

    func triggerRefresh() {
        defaults.synchronize()
        refreshTick += 1
    }

    // MARK: - All Apps Usage Data

    struct AppUsageEntry: Identifiable {
        let id: String // base64 token key
        let token: ApplicationToken
        let durationSeconds: TimeInterval

        var durationMinutes: Int { Int(durationSeconds / 60) }
    }

    struct HourlyUsage {
        let hour: Int
        let totalSeconds: TimeInterval
        let distractingSeconds: TimeInterval
    }

    private struct HourlyAppUsage {
        let hour: Int
        let tokenKey: String
        let durationSeconds: TimeInterval
    }

    /// All apps sorted by duration (from AllAppsReportScene)
    var allAppsUsageEntries: [AppUsageEntry] {
        _ = refreshTick
        guard let entries = defaults.array(forKey: "allAppsUsageEntries") as? [[String: Any]] else {
            return []
        }
        return entries.compactMap { dict in
            guard let tokenBase64 = dict["token"] as? String,
                  let duration = doubleValue(dict["duration"]),
                  let tokenData = Data(base64Encoded: tokenBase64),
                  let token = try? JSONDecoder().decode(ApplicationToken.self, from: tokenData)
            else { return nil }
            return AppUsageEntry(id: tokenBase64, token: token, durationSeconds: duration)
        }
    }

    /// Total screen time across all apps (seconds)
    var totalScreenTimeSeconds: TimeInterval {
        _ = refreshTick
        return defaults.double(forKey: "totalScreenTimeSeconds")
    }

    var totalScreenTimeMinutes: Int {
        Int(totalScreenTimeSeconds / 60)
    }

    /// Pickups today
    var totalPickups: Int {
        _ = refreshTick
        return defaults.integer(forKey: "totalPickups")
    }

    /// Per-hour breakdown for the timeline graph
    var hourlyUsageData: [HourlyUsage] {
        _ = refreshTick
        guard let entries = defaults.array(forKey: "hourlyUsageData") as? [[String: Any]] else {
            return []
        }
        let storedEntries: [HourlyUsage] = entries.compactMap { dict in
            guard let hour = intValue(dict["hour"]),
                  let total = doubleValue(dict["totalSeconds"]),
                  let distracting = doubleValue(dict["distractingSeconds"])
            else { return nil }
            return HourlyUsage(hour: hour, totalSeconds: total, distractingSeconds: distracting)
        }

        let rawAppUsage = hourlyAppUsageData
        guard !rawAppUsage.isEmpty else { return storedEntries }

        let distractingByHour = Dictionary(grouping: rawAppUsage, by: \.hour)
            .mapValues { entries in
                entries.reduce(0) { total, entry in
                    category(forKey: entry.tokenKey) == .distracting
                        ? total + entry.durationSeconds
                        : total
                }
            }

        return storedEntries.map { entry in
            HourlyUsage(
                hour: entry.hour,
                totalSeconds: entry.totalSeconds,
                distractingSeconds: distractingByHour[entry.hour] ?? entry.distractingSeconds
            )
        }
    }

    /// Distracting minutes today (sum of all apps categorized as distracting)
    var distractingMinutesToday: Int {
        let entries = allAppsUsageEntries
        var total: TimeInterval = 0
        for entry in entries {
            if category(for: entry.token) == .distracting {
                total += entry.durationSeconds
            }
        }
        return Int(total / 60)
    }

    // MARK: - App Category

    private var categoryMap: [String: String] {
        get {
            defaults.dictionary(forKey: "appCategoryMap") as? [String: String] ?? [:]
        }
        set {
            defaults.set(newValue, forKey: "appCategoryMap")
        }
    }

    func category(for token: ApplicationToken) -> AppCategory {
        category(forKey: tokenKey(token))
    }

    private func category(forKey key: String) -> AppCategory {
        if let raw = categoryMap[key], let cat = AppCategory(rawValue: raw) {
            return cat
        }
        return .distracting
    }

    func cycleCategory(for token: ApplicationToken) {
        let current = category(for: token)
        let next: AppCategory
        switch current {
        case .productive: next = .neutral
        case .neutral: next = .distracting
        case .distracting: next = .productive
        }
        var map = categoryMap
        map[tokenKey(token)] = next.rawValue
        categoryMap = map
        defaults.synchronize()
        triggerRefresh()
    }

    private func tokenKey(_ token: ApplicationToken) -> String {
        if let data = try? JSONEncoder().encode(token) {
            return data.base64EncodedString()
        }
        return "\(token.hashValue)"
    }

    private var hourlyAppUsageData: [HourlyAppUsage] {
        guard let entries = defaults.array(forKey: "hourlyAppUsageData") as? [[String: Any]] else {
            return []
        }
        return entries.compactMap { dict in
            guard let hour = intValue(dict["hour"]),
                  let tokenKey = dict["token"] as? String,
                  let duration = doubleValue(dict["duration"]),
                  !tokenKey.isEmpty
            else { return nil }
            return HourlyAppUsage(hour: hour, tokenKey: tokenKey, durationSeconds: duration)
        }
    }

    var allAppsUsageLastRun: Date? {
        _ = refreshTick
        return defaults.object(forKey: "allAppsUsageLastRun") as? Date
    }

    var allAppsUsageDataCount: Int {
        _ = refreshTick
        return defaults.integer(forKey: "allAppsUsageDataCount")
    }

    var allAppsUsageSegmentCount: Int {
        _ = refreshTick
        return defaults.integer(forKey: "allAppsUsageSegmentCount")
    }

    var allAppsUsageRawSegmentSeconds: TimeInterval {
        _ = refreshTick
        return defaults.double(forKey: "allAppsUsageRawSegmentSeconds")
    }

    var allAppsUsageRawApplicationSeconds: TimeInterval {
        _ = refreshTick
        return defaults.double(forKey: "allAppsUsageRawApplicationSeconds")
    }

    var debugSnapshot: String {
        "auth=\(authorizationStatus) setup=\(isSetupComplete) paused=\(isPaused) selectionApps=\(selection.applicationTokens.count) selectionCategories=\(selection.categoryTokens.count) selectionWeb=\(selection.webDomainTokens.count) lastRun=\(allAppsUsageLastRun?.formatted(date: .omitted, time: .standard) ?? "never") data=\(allAppsUsageDataCount) segments=\(allAppsUsageSegmentCount) storedSeconds=\(Int(totalScreenTimeSeconds)) rawSegment=\(Int(allAppsUsageRawSegmentSeconds)) rawApps=\(Int(allAppsUsageRawApplicationSeconds)) apps=\(allAppsUsageEntries.count) approx=\(approxMinutesToday)"
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = authCenter.authorizationStatus
        triggerRefresh()
        print("[ScreenTimeManager] refreshAuthorizationStatus status=\(authorizationStatus)")
    }

    private func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let number as Double:
            return number
        case let number as Float:
            return Double(number)
        case let number as Int:
            return Double(number)
        case let number as NSNumber:
            return number.doubleValue
        default:
            return nil
        }
    }

    private func intValue(_ value: Any?) -> Int? {
        switch value {
        case let number as Int:
            return number
        case let number as Double:
            return Int(number)
        case let number as Float:
            return Int(number)
        case let number as NSNumber:
            return number.intValue
        default:
            return nil
        }
    }

    // MARK: - Per-Block Monitoring & Shielding

    /// Register a DeviceActivity monitor for a block. The system will call
    /// the DeviceActivityMonitor extension's intervalDidStart / intervalDidEnd
    /// at the scheduled times — no polling required.
    func registerBlock(_ block: ScreenBlock) {
        guard isAuthorized else { return }
        guard let selection = block.selection else { return }

        let blockID = block.id.uuidString
        let activityName = DeviceActivityName("block-\(blockID)")

        // Persist selection data to app group so the extension can apply shields
        if let data = block.selectionData {
            defaults.set(data, forKey: "blockShield-\(blockID)")
            defaults.synchronize()
        }

        let startComps: DateComponents
        let endComps: DateComponents

        switch block.type {
        case "blockNow":
            startComps = DateComponents(hour: 0, minute: 0)
            endComps = DateComponents(hour: 23, minute: 59)

        case "schedule":
            guard !block.isVacationMode else { return }
            let startMins = block.scheduleStartHour * 60 + block.scheduleStartMinute
            let endMins = block.scheduleEndHour * 60 + block.scheduleEndMinute
            let interval = endMins > startMins ? endMins - startMins : endMins + 1440 - startMins
            if interval < 15 {
                logDiagnostic("registerBlock SKIPPED: \(block.name) interval \(interval)m < 15m minimum")
                // Still apply shield if currently active (foreground safety net)
                if isScheduleCurrentlyActive(block) {
                    applyShield(blockID: blockID, selection: selection)
                }
                return
            }
            startComps = DateComponents(hour: block.scheduleStartHour, minute: block.scheduleStartMinute)
            endComps = DateComponents(hour: block.scheduleEndHour, minute: block.scheduleEndMinute)

        case "appLimit":
            startComps = DateComponents(hour: 0, minute: 0)
            endComps = DateComponents(hour: 23, minute: 59)

        case "lock":
            startComps = DateComponents(hour: 0, minute: 0)
            endComps = DateComponents(hour: 23, minute: 59)

        default:
            return
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd: endComps,
            repeats: block.type != "blockNow",
            warningTime: DateComponents(minute: 1)
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

        // Backup event: fires after 1 minute of use on the selected apps.
        // includesPastActivity: if the user was already on a blocked app when the
        // interval started, that prior usage counts toward the threshold — so the
        // event fires almost immediately instead of waiting for 1 fresh minute.
        if block.type == "schedule" || block.type == "blockNow" || block.type == "lock" {
            let eventName = DeviceActivityEvent.Name("shield-\(blockID)")
            events[eventName] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: 1),
                includesPastActivity: true
            )
        }

        // startMonitoring replaces any existing monitor with the same name —
        // no need to call stopMonitoring first.
        do {
            try activityCenter.startMonitoring(activityName, during: schedule, events: events)
            // Verify registration succeeded
            let registered = activityCenter.activities.map(\.rawValue)
            let isRegistered = registered.contains(activityName.rawValue)
            logDiagnostic("registerBlock OK: \(block.name) type=\(block.type) schedule=\(startComps.hour ?? 0):\(startComps.minute ?? 0)-\(endComps.hour ?? 0):\(endComps.minute ?? 0) registered=\(isRegistered) events=\(events.keys.map(\.rawValue))")
        } catch {
            logDiagnostic("registerBlock FAILED: \(block.name) error=\(error)")
            print("[ScreenTimeManager] registerBlock failed for \(block.name): \(error)")
        }

        // Apply shield immediately for blockNow, lock, and currently-active schedules.
        // For future schedules, the extension's intervalDidStart handles it.
        if block.type == "blockNow" || block.type == "lock" {
            applyShield(blockID: blockID, selection: selection)
        } else if block.type == "schedule" {
            if isScheduleCurrentlyActive(block) {
                logDiagnostic("registerBlock: schedule currently active, applying shield now")
                applyShield(blockID: blockID, selection: selection)
            } else {
                logDiagnostic("registerBlock: schedule NOT active, deferring to extension. start=\(block.scheduleStartHour):\(block.scheduleStartMinute) end=\(block.scheduleEndHour):\(block.scheduleEndMinute)")
            }
            // Schedule a BGTask as backup in case the extension doesn't fire
            scheduleBackgroundReconcile(for: block)
        }
    }

    /// Schedule a BGAppRefreshTask to apply/remove shields at block boundaries.
    private func scheduleBackgroundReconcile(for block: ScreenBlock) {
        let cal = Calendar.current
        let now = Date()

        // Find the next start or end time for this block
        for dayOffset in 0...1 {
            guard let baseDate = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let weekday = cal.component(.weekday, from: baseDate)
            guard block.activeDaysSet.contains(weekday) else { continue }

            if let startDate = cal.date(bySettingHour: block.scheduleStartHour, minute: block.scheduleStartMinute, second: 0, of: baseDate),
               startDate > now {
                let request = BGAppRefreshTaskRequest(identifier: "com.tamagoosie.app.block-reconcile")
                request.earliestBeginDate = startDate.addingTimeInterval(5)
                do {
                    try BGTaskScheduler.shared.submit(request)
                    logDiagnostic("BGTask scheduled for \(startDate.formatted(date: .omitted, time: .standard))")
                } catch {
                    logDiagnostic("BGTask schedule failed: \(error)")
                }
                return
            }

            if let endDate = cal.date(bySettingHour: block.scheduleEndHour, minute: block.scheduleEndMinute, second: 0, of: baseDate),
               endDate > now {
                let request = BGAppRefreshTaskRequest(identifier: "com.tamagoosie.app.block-reconcile")
                request.earliestBeginDate = endDate.addingTimeInterval(5)
                do {
                    try BGTaskScheduler.shared.submit(request)
                    logDiagnostic("BGTask scheduled for \(endDate.formatted(date: .omitted, time: .standard))")
                } catch {
                    logDiagnostic("BGTask schedule failed: \(error)")
                }
                return
            }
        }
    }

    func unregisterBlock(_ block: ScreenBlock) {
        let blockID = block.id.uuidString
        let activityName = DeviceActivityName("block-\(blockID)")
        activityCenter.stopMonitoring([activityName])
        removeShield(blockID: blockID)
        defaults.removeObject(forKey: "blockShield-\(blockID)")
    }

    /// Called on foreground as a safety net. Reconciles shield state based on
    /// current time and re-registers only monitors the system has dropped
    /// (e.g. after a reboot). Does NOT stop/restart existing monitors so the
    /// system can fire extension callbacks reliably.
    func reconcileBlocks(_ blocks: [ScreenBlock]) {
        let monitoredActivities = Set(activityCenter.activities.map(\.rawValue))

        for block in blocks where !block.isPast {
            let blockID = block.id.uuidString
            let activityName = "block-\(blockID)"

            // Only re-register if the system lost the monitor
            if !monitoredActivities.contains(activityName) {
                registerBlock(block)
            }

            guard let selection = block.selection else { continue }

            // Reconcile shield state based on current time
            switch block.type {
            case "blockNow":
                if block.startedAt != nil && block.endedAt == nil {
                    applyShield(blockID: blockID, selection: selection)
                } else if block.endedAt != nil {
                    removeShield(blockID: blockID)
                }
            case "schedule":
                if !block.isVacationMode && isScheduleCurrentlyActive(block) {
                    applyShield(blockID: blockID, selection: selection)
                } else {
                    removeShield(blockID: blockID)
                }
            case "lock":
                applyShield(blockID: blockID, selection: selection)
            default:
                break // appLimit handled by threshold events
            }
        }
    }

    // MARK: - Shield Management

    func applyShield(blockID: String, selection: FamilyActivitySelection) {
        let store = ManagedSettingsStore(named: .init("block-\(blockID)"))
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    func removeShield(blockID: String) {
        let store = ManagedSettingsStore(named: .init("block-\(blockID)"))
        store.clearAllSettings()
    }

    // MARK: - Diagnostics

    private func logDiagnostic(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)"
        var log = defaults.stringArray(forKey: "managerBreadcrumbs") ?? []
        log.append(entry)
        if log.count > 50 { log = Array(log.suffix(50)) }
        defaults.set(log, forKey: "managerBreadcrumbs")
        defaults.synchronize()
        print("[ScreenTimeManager] \(message)")
    }

    /// Extension breadcrumbs written by the DeviceActivityMonitor extension
    var extensionBreadcrumbs: [String] {
        defaults.synchronize()
        return defaults.stringArray(forKey: "extensionBreadcrumbs") ?? []
    }

    /// Manager breadcrumbs written by ScreenTimeManager
    var managerBreadcrumbs: [String] {
        defaults.synchronize()
        return defaults.stringArray(forKey: "managerBreadcrumbs") ?? []
    }

    /// Last time any extension callback fired
    var extensionLastCallback: Date? {
        defaults.synchronize()
        let ts = defaults.double(forKey: "extensionLastCallback")
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    /// Currently registered activity names
    var registeredActivities: [String] {
        activityCenter.activities.map(\.rawValue)
    }

    /// Check if the extension appex is embedded in the app bundle
    var extensionBundleStatus: String {
        guard let plugInsURL = Bundle.main.builtInPlugInsURL else {
            return "NO PlugIns directory"
        }
        let extURL = plugInsURL.appendingPathComponent("TamaGoosieDeviceActivity.appex")
        let exists = FileManager.default.fileExists(atPath: extURL.path)
        if exists {
            if let bundle = Bundle(url: extURL) {
                let nsExt = bundle.infoDictionary?["NSExtension"] as? [String: Any]
                let pointID = (nsExt?["NSExtensionPointIdentifier"] as? String) ?? "unknown"
                let className = (nsExt?["NSExtensionPrincipalClass"] as? String) ?? "unknown"
                return "EMBEDDED. Point: \(pointID) Principal: \(className)"
            }
            return "EMBEDDED but bundle unreadable"
        }
        return "MISSING from PlugIns"
    }

    /// Clear all diagnostic breadcrumbs
    func clearDiagnostics() {
        defaults.removeObject(forKey: "extensionBreadcrumbs")
        defaults.removeObject(forKey: "managerBreadcrumbs")
        defaults.removeObject(forKey: "extensionLastCallback")
        defaults.synchronize()
    }

    private func isScheduleCurrentlyActive(_ block: ScreenBlock) -> Bool {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        guard block.activeDaysSet.contains(weekday) else { return false }
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let nowMins = hour * 60 + minute
        let startMins = block.scheduleStartHour * 60 + block.scheduleStartMinute
        let endMins = block.scheduleEndHour * 60 + block.scheduleEndMinute
        return nowMins >= startMins && nowMins < endMins
    }
}
