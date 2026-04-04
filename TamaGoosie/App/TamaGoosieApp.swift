import SwiftUI
import SwiftData

@main
struct TamaGoosieApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            GooseState.self,
            Goal.self,
            FocusSession.self,
            HealthSnapshot.self,
            DailyLog.self,
        ])
    }
}
