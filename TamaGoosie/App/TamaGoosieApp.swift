import SwiftUI
import SwiftData
import UserNotifications
import GoogleSignIn
import BackgroundTasks
import FamilyControls
import ManagedSettings

// MARK: - Notification Delegate

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    @Published var pendingNegotiation: PendingNegotiation? = nil
    @Published var completedGoalID: UUID? = nil

    // Show notifications as banners even while app is foregrounded
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle action button taps
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        guard let goalIDString = info["goalID"] as? String,
              let goalID = UUID(uuidString: goalIDString) else {
            completionHandler()
            return
        }

        switch response.actionIdentifier {
        case "ACK":
            GooseNotificationSystem.shared.markAcknowledged(goalID: goalID)

        case "BUSY":
            let goalTitle = info["goalTitle"] as? String ?? "your goal"
            DispatchQueue.main.async {
                self.pendingNegotiation = PendingNegotiation(
                    goalID: goalID,
                    goalTitle: goalTitle,
                    gooseName: "your goose"
                )
            }

        case "COMPLETE":
            // Mark goal as completed via notification action — post for the view layer to handle
            DispatchQueue.main.async {
                self.completedGoalID = goalID
            }

        case "SNOOZE":
            let goalTitle = info["goalTitle"] as? String ?? "your goal"
            NotificationScheduler.shared.handleSnooze(goalID: goalID, goalTitle: goalTitle)

        case "UPDATE":
            break  // Future: deep link to goal editor

        case "HARDER":
            EscalationTracker.shared.resetFailures(for: goalID)

        default:
            break
        }

        completionHandler()
    }
}

// MARK: - App

@main
struct TamaGoosieApp: App {
    let container: ModelContainer
    @StateObject private var notificationDelegate = AppNotificationDelegate()

    init() {
        let schema = Schema([
            GooseState.self,
            Goal.self,
            GoalProgress.self,
            GoalCompletionEvent.self,
            FocusSession.self,
            DailyLog.self,
            UserProfile.self,
            ScreenBlock.self,
            ChallengeTemplate.self,
            ChallengeRun.self,
        ])

        // Try to open the persistent store. If the schema is incompatible with the
        // on-disk store (e.g. after a model refactor without a migration), SwiftData
        // throws rather than silently returning a broken in-memory container.
        // In that case, delete the store files and start fresh.
        do {
            container = try ModelContainer(for: schema)
        } catch {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let storeURL = config.url
            // Delete the SQLite store and its WAL/SHM companions
            for suffix in ["", "-shm", "-wal"] {
                let url = URL(fileURLWithPath: storeURL.path + suffix)
                try? FileManager.default.removeItem(at: url)
            }
            // Recreate — guaranteed to succeed on a clean store
            container = try! ModelContainer(for: schema)
        }

        GooseNotificationSystem.shared.registerCategories()
        NotificationScheduler.shared.registerCategories()

        // Register background task for shield reconciliation.
        // This fires approximately at scheduled block start times as a backup
        // in case the DeviceActivityMonitor extension doesn't launch.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.tamagoosie.app.block-reconcile",
            using: nil
        ) { [container] task in
            Self.handleBlockReconcileTask(task, container: container)
        }

        // Activate WatchConnectivity early so the session is ready
        // before any GooseEngine updates try to send payloads.
        WatchSyncService.shared.activate()
    }

    /// Background task handler: applies/removes shields for schedule blocks.
    private static func handleBlockReconcileTask(_ task: BGTask, container: ModelContainer) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ScreenBlock>()
        guard let blocks = try? context.fetch(descriptor) else {
            task.setTaskCompleted(success: false)
            return
        }

        let defaults = UserDefaults(suiteName: GoosieConstants.appGroupID)!
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let nowMins = hour * 60 + minute

        for block in blocks where !block.isPast && block.type == "schedule" {
            guard !block.isVacationMode else { continue }
            guard let data = block.selectionData,
                  let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
            else { continue }

            let startMins = block.scheduleStartHour * 60 + block.scheduleStartMinute
            let endMins = block.scheduleEndHour * 60 + block.scheduleEndMinute
            let isActive = block.activeDaysSet.contains(weekday) && nowMins >= startMins && nowMins < endMins
            let blockID = block.id.uuidString
            let store = ManagedSettingsStore(named: .init("block-\(blockID)"))

            if isActive {
                store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
                store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
                store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
            } else {
                store.clearAllSettings()
            }
        }

        // Log that the BGTask ran
        var log = defaults.stringArray(forKey: "managerBreadcrumbs") ?? []
        let ts = ISO8601DateFormatter().string(from: now)
        log.append("[\(ts)] BGTask block-reconcile ran")
        if log.count > 50 { log = Array(log.suffix(50)) }
        defaults.set(log, forKey: "managerBreadcrumbs")
        defaults.synchronize()

        // Schedule the next reconcile for the nearest upcoming block start/end
        scheduleNextBlockReconcile(blocks: blocks)

        task.setTaskCompleted(success: true)
    }

    /// Schedule a BGAppRefreshTask for the next block boundary (start or end).
    static func scheduleNextBlockReconcile(blocks: [ScreenBlock]) {
        let cal = Calendar.current
        let now = Date()

        var nearestDate: Date?

        for block in blocks where !block.isPast && block.type == "schedule" && !block.isVacationMode {
            // Find the next start and end time today or tomorrow
            for dayOffset in 0...1 {
                guard let baseDate = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                let weekday = cal.component(.weekday, from: baseDate)
                guard block.activeDaysSet.contains(weekday) else { continue }

                if var startDate = cal.date(bySettingHour: block.scheduleStartHour, minute: block.scheduleStartMinute, second: 0, of: baseDate),
                   startDate > now {
                    // Add a small buffer so the task runs just after the boundary
                    startDate = startDate.addingTimeInterval(5)
                    if nearestDate == nil || startDate < nearestDate! {
                        nearestDate = startDate
                    }
                }

                if var endDate = cal.date(bySettingHour: block.scheduleEndHour, minute: block.scheduleEndMinute, second: 0, of: baseDate),
                   endDate > now {
                    endDate = endDate.addingTimeInterval(5)
                    if nearestDate == nil || endDate < nearestDate! {
                        nearestDate = endDate
                    }
                }
            }
        }

        guard let targetDate = nearestDate else { return }

        let request = BGAppRefreshTaskRequest(identifier: "com.tamagoosie.app.block-reconcile")
        request.earliestBeginDate = targetDate
        try? BGTaskScheduler.shared.submit(request)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationDelegate)
                .preferredColorScheme(.light)
                .onAppear {
                    UNUserNotificationCenter.current().delegate = notificationDelegate
                    // Restore previous Google session silently
                    AuthService.shared.restoreGoogleSession()
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(container)
    }
}
