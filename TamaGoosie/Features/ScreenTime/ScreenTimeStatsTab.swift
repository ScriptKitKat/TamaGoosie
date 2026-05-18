import SwiftUI
import SwiftData
import FamilyControls
import ManagedSettings
import DeviceActivity

struct ScreenTimeStatsTab: View {
    @State private var manager = ScreenTimeManager.shared

    private var allActivityFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return DeviceActivityFilter(
            segment: .hourly(during: DateInterval(start: startOfDay, end: Date())),
            users: .all,
            devices: .all
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header stats + timeline graph + time offline — all rendered by the report extension
            DeviceActivityReport(.init(rawValue: "distraction_summary"), filter: allActivityFilter)
                .frame(height: 470)

            // App usage breakdown — scrollable within the report extension
            DeviceActivityReport(.init(rawValue: "all_apps_usage"), filter: allActivityFilter)
                .frame(height: 420)
        }
        .task {
            manager.refreshAuthorizationStatus()
        }
    }
}
