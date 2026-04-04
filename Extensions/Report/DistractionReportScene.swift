import DeviceActivity
import SwiftUI

struct DistractionReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "distraction_summary")

    struct ReportData {
        var totalDuration: TimeInterval = 0
    }

    typealias Configuration = ReportData

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ReportData {
        // The DeviceActivityResults sequence provides per-segment data on device.
        // On simulator this will be empty. On device, the system populates it
        // with the user's actual screen time for the selected apps.
        var total: TimeInterval = 0
        for await _ in data {
            // DeviceActivityData itself surfaces user/device metadata;
            // the actual duration comes from the report filter's aggregate.
            // Read approximate minutes from App Group as a fallback.
        }
        if total == 0 {
            let defaults = UserDefaults(suiteName: "group.com.tamagoosie")
            total = Double(defaults?.integer(forKey: "distractionApproxMinutes") ?? 0) * 60
        }
        return ReportData(totalDuration: total)
    }

    var content: (ReportData) -> AnyView = { (config: ReportData) in
        AnyView(
            VStack(spacing: 12) {
                Text("Screen Time Today")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Color(red: 0.18, green: 0.18, blue: 0.18))

                if config.totalDuration > 0 {
                    let hours = Int(config.totalDuration) / 3600
                    let minutes = (Int(config.totalDuration) % 3600) / 60
                    if hours > 0 {
                        Text("\(hours)h \(minutes)m")
                            .font(.system(.title, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.49))
                    } else {
                        Text("\(minutes)m")
                            .font(.system(.title, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.49))
                    }
                } else {
                    Text("No data yet")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.45))
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(red: 1.0, green: 0.97, blue: 0.94))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        )
    }
}

@main
struct DistractionReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        DistractionReportScene()
    }
}
