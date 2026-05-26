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
        isSetupComplete = defaults.bool(forKey: GoosieConstants.screenTimeSetupCompleteKey)
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

    var isSetupComplete: Bool = false {
        didSet { defaults.set(isSetupComplete, forKey: GoosieConstants.screenTimeSetupCompleteKey) }
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

        // Persist selection data and block type to app group so the extension can apply shields
        if let data = block.selectionData {
            defaults.set(data, forKey: "blockShield-\(blockID)")
            defaults.set(block.type, forKey: "blockType-\(blockID)")
            if block.type == "lock" {
                defaults.set(block.opensAllowed, forKey: "lockOpensAllowed-\(blockID)")
                defaults.set(block.unlockDurationMinutes, forKey: "lockUnlockDuration-\(blockID)")
                updateActiveLockBlockIDs(add: blockID)
            }
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
        if block.type == "schedule" || block.type == "blockNow" {
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
        if block.type == "lock" {
            // Clear old per-block named store (migration from old approach)
            ManagedSettingsStore(named: .init("block-\(blockID)")).clearAllSettings()
            LockShieldReconciler.reconcile()
        } else if block.type == "blockNow" {
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
        activityCenter.stopMonitoring([
            DeviceActivityName("block-\(blockID)"),
            DeviceActivityName("unlock-\(blockID)")
        ])

        if block.type == "lock" {
            // Clear old per-block named store (migration)
            ManagedSettingsStore(named: .init("block-\(blockID)")).clearAllSettings()
            updateActiveLockBlockIDs(remove: blockID)
        } else {
            removeShield(blockID: blockID)
        }

        clearLockBlockDefaults(blockID: blockID)

        if block.type == "lock" {
            LockShieldReconciler.reconcile()
        }
    }

    private func clearLockBlockDefaults(blockID: String) {
        defaults.removeObject(forKey: "blockShield-\(blockID)")
        defaults.removeObject(forKey: "blockType-\(blockID)")
        defaults.removeObject(forKey: "lockCountdownStartedAt-\(blockID)")
        defaults.removeObject(forKey: "lockUnlockExpiry-\(blockID)")
        defaults.removeObject(forKey: "lockOpensUsed-\(blockID)")
        defaults.removeObject(forKey: "lockLastReset-\(blockID)")
        defaults.removeObject(forKey: "lockOpensAllowed-\(blockID)")
        defaults.removeObject(forKey: "lockUnlockDuration-\(blockID)")
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

            // Ensure lock config is always in UserDefaults for the ShieldAction extension
            if block.type == "lock", let data = block.selectionData {
                defaults.set(data, forKey: "blockShield-\(blockID)")
                defaults.set(block.type, forKey: "blockType-\(blockID)")
                defaults.set(block.opensAllowed, forKey: "lockOpensAllowed-\(blockID)")
                defaults.set(block.unlockDurationMinutes, forKey: "lockUnlockDuration-\(blockID)")
                updateActiveLockBlockIDs(add: blockID)
                // Clear old per-block named store (migration)
                ManagedSettingsStore(named: .init("block-\(blockID)")).clearAllSettings()
                defaults.synchronize()
            }

            // Skip re-registration for actively unlocked lock blocks
            let isUnlockedLock = block.type == "lock" && isBlockUnlocked(blockID: blockID)

            // Only re-register if the system lost the monitor
            if !monitoredActivities.contains(activityName) && !isUnlockedLock {
                registerBlock(block)
            }

            guard let selection = block.selection else { continue }

            // Reconcile shield state for non-lock blocks
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
                let now = Date().timeIntervalSince1970
                // Clean up stale countdowns (past TTL)
                let countdownStart = defaults.double(forKey: "lockCountdownStartedAt-\(blockID)")
                if countdownStart > 0 && now - countdownStart >= LockRuntime.countdownTTL + LockRuntime.countdownSeconds {
                    defaults.removeObject(forKey: "lockCountdownStartedAt-\(blockID)")
                    defaults.synchronize()
                }
                // Clean up expired unlocks past time's-up window
                let expiry = defaults.double(forKey: "lockUnlockExpiry-\(blockID)")
                if expiry > 0 && now - expiry >= LockRuntime.timesUpWindow {
                    defaults.removeObject(forKey: "lockUnlockExpiry-\(blockID)")
                    activityCenter.stopMonitoring([DeviceActivityName("unlock-\(blockID)")])
                    defaults.synchronize()
                    logDiagnostic("reconcile: lock \(block.name) expiry cleaned (past time's-up window)")
                }
                // Reconciler handles all lock shields below
            default:
                break // appLimit handled by threshold events
            }
        }

        // Rebuild activeLockBlockIDs from live blocks to remove stale entries
        let liveLockIDs = Set(blocks.filter { $0.type == "lock" && !$0.isPast }.map { $0.id.uuidString })
        let storedLockIDs = defaults.stringArray(forKey: "activeLockBlockIDs") ?? []
        let staleIDs = storedLockIDs.filter { !liveLockIDs.contains($0) }
        if !staleIDs.isEmpty {
            for staleID in staleIDs {
                clearLockBlockDefaults(blockID: staleID)
            }
            defaults.set(Array(liveLockIDs), forKey: "activeLockBlockIDs")
            defaults.synchronize()
            logDiagnostic("reconcile: cleaned \(staleIDs.count) stale lock IDs")
        }

        // Single reconcile call handles ALL lock blocks at once
        LockShieldReconciler.reconcile()
        triggerRefresh()
    }

    // MARK: - Shield Management

    /// Apply shield for non-lock blocks using per-block named store.
    /// Lock blocks use LockShieldReconciler instead.
    func applyShield(blockID: String, selection: FamilyActivitySelection) {
        let store = ManagedSettingsStore(named: .init("block-\(blockID)"))
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    /// Remove shield for non-lock blocks.
    func removeShield(blockID: String) {
        let store = ManagedSettingsStore(named: .init("block-\(blockID)"))
        store.clearAllSettings()
    }

    // MARK: - Lock Unlock Management

    func unlockBlock(_ block: ScreenBlock) {
        guard block.type == "lock" else { return }
        let blockID = block.id.uuidString
        guard block.selection != nil else { return }

        let used = lockOpensUsedToday(blockID: blockID)
        guard used < block.opensAllowed else { return }

        // Clear any stale countdown, save unlock state — reconciler reads this to skip shielding
        defaults.removeObject(forKey: "lockCountdownStartedAt-\(blockID)")
        let expiry = Date().addingTimeInterval(TimeInterval(block.unlockDurationMinutes * 60))
        defaults.set(expiry.timeIntervalSince1970, forKey: "lockUnlockExpiry-\(blockID)")
        defaults.set(used + 1, forKey: "lockOpensUsed-\(blockID)")
        defaults.synchronize()

        // Reconciler removes shield for this block immediately
        LockShieldReconciler.reconcile()

        // Start temporary monitor — its intervalDidStart fires at expiry to re-shield
        startUnlockMonitor(blockID: blockID, expiryDate: expiry)

        triggerRefresh()
        logDiagnostic("unlockBlock: \(block.name) opens=\(used + 1)/\(block.opensAllowed)")
    }

    func relockBlock(_ block: ScreenBlock) {
        guard block.type == "lock" else { return }
        let blockID = block.id.uuidString

        // Stop unlock monitor if running
        activityCenter.stopMonitoring([DeviceActivityName("unlock-\(blockID)")])

        defaults.removeObject(forKey: "lockUnlockExpiry-\(blockID)")
        defaults.synchronize()

        // Reconciler re-applies shield for this block
        LockShieldReconciler.reconcile()

        // Re-register monitor for daily callbacks
        registerBlock(block)
        triggerRefresh()
        logDiagnostic("relockBlock: \(block.name)")
    }

    private func startUnlockMonitor(blockID: String, expiryDate: Date) {
        let cal = Calendar.current
        // Add 60 seconds so the monitor fires AFTER the actual expiry.
        // DeviceActivitySchedule uses DateComponents(hour:minute:) which
        // truncates seconds — without this offset the monitor can fire
        // before the expiry and the reconciler sees the block as still unlocked.
        let relockTime = expiryDate.addingTimeInterval(60)
        let endHour = cal.component(.hour, from: relockTime)
        let endMinute = cal.component(.minute, from: relockTime)

        // Skip if too close to midnight
        if endHour == 23 && endMinute >= 58 { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: endHour, minute: endMinute),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: false
        )

        do {
            try activityCenter.startMonitoring(
                DeviceActivityName("unlock-\(blockID)"),
                during: schedule
            )
            logDiagnostic("startUnlockMonitor: \(blockID) relock at \(endHour):\(String(format: "%02d", endMinute))")
        } catch {
            logDiagnostic("startUnlockMonitor FAILED: \(blockID) error=\(error)")
        }
    }

    func isBlockUnlocked(_ block: ScreenBlock) -> Bool {
        _ = refreshTick
        return isBlockUnlocked(blockID: block.id.uuidString)
    }

    private func isBlockUnlocked(blockID: String) -> Bool {
        defaults.synchronize()
        let expiryTS = defaults.double(forKey: "lockUnlockExpiry-\(blockID)")
        guard expiryTS > 0 else { return false }
        return Date().timeIntervalSince1970 < expiryTS
    }

    func lockUnlockExpiryDate(_ block: ScreenBlock) -> Date? {
        _ = refreshTick
        let expiryTS = defaults.double(forKey: "lockUnlockExpiry-\(block.id.uuidString)")
        guard expiryTS > 0 else { return nil }
        let date = Date(timeIntervalSince1970: expiryTS)
        return date > Date() ? date : nil
    }

    func lockOpensRemaining(_ block: ScreenBlock) -> Int {
        _ = refreshTick
        let used = lockOpensUsedToday(blockID: block.id.uuidString)
        return max(0, block.opensAllowed - used)
    }

    private func updateActiveLockBlockIDs(add blockID: String) {
        var ids = defaults.stringArray(forKey: "activeLockBlockIDs") ?? []
        if !ids.contains(blockID) { ids.append(blockID) }
        defaults.set(ids, forKey: "activeLockBlockIDs")
        defaults.synchronize()
    }

    private func updateActiveLockBlockIDs(remove blockID: String) {
        var ids = defaults.stringArray(forKey: "activeLockBlockIDs") ?? []
        ids.removeAll { $0 == blockID }
        defaults.set(ids, forKey: "activeLockBlockIDs")
        defaults.synchronize()
    }

    private func lockOpensUsedToday(blockID: String) -> Int {
        let lastResetDate = defaults.object(forKey: "lockLastReset-\(blockID)") as? Date
        if let lastReset = lastResetDate, !Calendar.current.isDateInToday(lastReset) {
            defaults.set(0, forKey: "lockOpensUsed-\(blockID)")
            defaults.set(Date(), forKey: "lockLastReset-\(blockID)")
            defaults.synchronize()
            return 0
        }
        if lastResetDate == nil {
            defaults.set(Date(), forKey: "lockLastReset-\(blockID)")
            defaults.synchronize()
        }
        return defaults.integer(forKey: "lockOpensUsed-\(blockID)")
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

    /// Check ShieldAction extension embedding
    var shieldActionBundleStatus: String {
        guard let plugInsURL = Bundle.main.builtInPlugInsURL else {
            return "NO PlugIns directory"
        }
        let extURL = plugInsURL.appendingPathComponent("TamaGoosieShieldAction.appex")
        let exists = FileManager.default.fileExists(atPath: extURL.path)
        if exists {
            if let bundle = Bundle(url: extURL) {
                let nsExt = bundle.infoDictionary?["NSExtension"] as? [String: Any]
                let pointID = (nsExt?["NSExtensionPointIdentifier"] as? String) ?? "unknown"
                let className = (nsExt?["NSExtensionPrincipalClass"] as? String) ?? "unknown"
                let bundleID = bundle.bundleIdentifier ?? "unknown"
                return "EMBEDDED. ID: \(bundleID) Point: \(pointID) Principal: \(className)"
            }
            return "EMBEDDED but bundle unreadable"
        }
        return "MISSING from PlugIns"
    }

    /// Check ShieldConfig extension embedding
    var shieldConfigBundleStatus: String {
        guard let plugInsURL = Bundle.main.builtInPlugInsURL else {
            return "NO PlugIns directory"
        }
        let extURL = plugInsURL.appendingPathComponent("TamaGoosieShield.appex")
        let exists = FileManager.default.fileExists(atPath: extURL.path)
        if exists {
            if let bundle = Bundle(url: extURL) {
                let nsExt = bundle.infoDictionary?["NSExtension"] as? [String: Any]
                let pointID = (nsExt?["NSExtensionPointIdentifier"] as? String) ?? "unknown"
                let className = (nsExt?["NSExtensionPrincipalClass"] as? String) ?? "unknown"
                let bundleID = bundle.bundleIdentifier ?? "unknown"
                return "EMBEDDED. ID: \(bundleID) Point: \(pointID) Principal: \(className)"
            }
            return "EMBEDDED but bundle unreadable"
        }
        return "MISSING from PlugIns"
    }

    /// Per-lock-block debug info for the diagnostics screen
    func lockDebugInfo(for block: ScreenBlock) -> [String: String] {
        defaults.synchronize()
        let blockID = block.id.uuidString
        var info: [String: String] = [:]

        let opensUsed = lockOpensUsedToday(blockID: blockID)
        info["opensUsed"] = "\(opensUsed)"
        info["opensAllowed"] = "\(block.opensAllowed)"
        info["remaining"] = "\(max(0, block.opensAllowed - opensUsed))"

        // Raw UserDefaults values (what the extension reads)
        let udOpensAllowed = defaults.integer(forKey: "lockOpensAllowed-\(blockID)")
        info["ud_opensAllowed"] = "\(udOpensAllowed)"
        let udDuration = defaults.integer(forKey: "lockUnlockDuration-\(blockID)")
        info["ud_unlockDuration"] = "\(udDuration)m"

        let expiryTS = defaults.double(forKey: "lockUnlockExpiry-\(blockID)")
        if expiryTS > 0 {
            let expiry = Date(timeIntervalSince1970: expiryTS)
            let isActive = Date() < expiry
            info["unlockExpiry"] = "\(expiry.formatted(date: .omitted, time: .standard)) (\(isActive ? "ACTIVE" : "EXPIRED"))"
        } else {
            info["unlockExpiry"] = "(none)"
        }

        info["isUnlocked"] = "\(isBlockUnlocked(blockID: blockID))"

        let countdownTS = defaults.double(forKey: "lockCountdownStartedAt-\(blockID)")
        info["countdownStartedAt"] = countdownTS > 0 ? Date(timeIntervalSince1970: countdownTS).formatted(date: .omitted, time: .standard) : "(none)"

        let now = Date().timeIntervalSince1970
        let state = LockRuntime.state(blockID: blockID, now: now, defaults: defaults)
        switch state {
        case .locked: info["runtimeState"] = "locked"
        case .countdown: info["runtimeState"] = "countdown"
        case .unlocked(let until): info["runtimeState"] = "unlocked (until \(Date(timeIntervalSince1970: until).formatted(date: .omitted, time: .standard)))"
        case .recentlyExpired: info["runtimeState"] = "recentlyExpired"
        }

        let hasShieldData = defaults.data(forKey: "blockShield-\(blockID)") != nil
        info["shieldDataStored"] = "\(hasShieldData)"
        info["blockType_ud"] = defaults.string(forKey: "blockType-\(blockID)") ?? "(missing)"

        return info
    }

    /// Global lock debug info
    var lockGlobalDebugInfo: [String: String] {
        defaults.synchronize()
        var info: [String: String] = [:]
        let active = defaults.stringArray(forKey: "activeLockBlockIDs") ?? []
        let now = Date().timeIntervalSince1970
        let countdownIDs = active.filter { defaults.double(forKey: "lockCountdownStartedAt-\($0)") > 0 && now - defaults.double(forKey: "lockCountdownStartedAt-\($0)") < LockRuntime.countdownTTL }
        info["activeCountdowns"] = countdownIDs.isEmpty ? "(none)" : countdownIDs.map { String($0.prefix(8)) }.joined(separator: ", ")
        info["activeLockBlockIDs"] = active.isEmpty ? "(none)" : active.joined(separator: "\n")

        // Count ShieldAction breadcrumbs to verify extension is being invoked
        let breadcrumbs = defaults.stringArray(forKey: "extensionBreadcrumbs") ?? []
        let shieldActionEntries = breadcrumbs.filter { $0.contains("ShieldAction") || $0.contains("SHIELD ACTION") }
        info["shieldActionCrumbs"] = "\(shieldActionEntries.count) of \(breadcrumbs.count) total"
        if let last = shieldActionEntries.last {
            info["lastShieldAction"] = String(last.suffix(80))
        }

        // Probe: did ShieldActionHandler even init?
        let probe = defaults.stringArray(forKey: "shieldActionProbe") ?? []
        info["shieldActionProbe"] = probe.isEmpty ? "NEVER LOADED" : probe.first ?? "?"

        return info
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
