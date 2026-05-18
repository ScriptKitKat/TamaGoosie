import SwiftUI
import SwiftData
import FamilyControls
import ManagedSettings
import DeviceActivity

struct ScreenTimeStatsTab: View {
    var period: ScreenTimePeriod = .today
    @State private var manager = ScreenTimeManager.shared

    private var summaryFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        switch period {
        case .today:
            return DeviceActivityFilter(
                segment: .hourly(during: DateInterval(start: startOfToday, end: now)),
                users: .all,
                devices: .all
            )
        case .yesterday:
            let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
            return DeviceActivityFilter(
                segment: .hourly(during: DateInterval(start: startOfYesterday, end: startOfToday)),
                users: .all,
                devices: .all
            )
        case .week:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday)!
            return DeviceActivityFilter(
                segment: .daily(during: DateInterval(start: sevenDaysAgo, end: now)),
                users: .all,
                devices: .all
            )
        }
    }

    private var summaryContext: DeviceActivityReport.Context {
        period == .week ? .init(rawValue: "weekly_summary") : .init(rawValue: "distraction_summary")
    }

    private var appsContext: DeviceActivityReport.Context {
        period == .week ? .init(rawValue: "weekly_apps_usage") : .init(rawValue: "all_apps_usage")
    }

    var body: some View {
        VStack(spacing: 14) {
            DeviceActivityReport(summaryContext, filter: summaryFilter)
                .frame(height: 470)

            DeviceActivityReport(appsContext, filter: summaryFilter)
                .frame(height: 420)
        }
        .id(period)
        .task {
            manager.refreshAuthorizationStatus()
        }
    }
}
