import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Notification Delegate

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    @Published var pendingNegotiation: PendingNegotiation? = nil

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
            FocusSession.self,
            HealthSnapshot.self,
            DailyLog.self,
            DistractionApp.self,
            UserProfile.self,
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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationDelegate)
                .onAppear {
                    UNUserNotificationCenter.current().delegate = notificationDelegate
                }
        }
        .modelContainer(container)
    }
}
