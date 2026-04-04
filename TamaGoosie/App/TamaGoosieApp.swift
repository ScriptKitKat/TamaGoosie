import SwiftUI
import SwiftData

@main
struct TamaGoosieApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            GooseState.self,
            Goal.self,
            GoalProgress.self,
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

        // Activate WatchConnectivity early so the session is ready
        // before any GooseEngine updates try to send payloads.
        WatchSyncService.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
