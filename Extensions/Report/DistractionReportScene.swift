import DeviceActivity
import ManagedSettings
import SwiftUI

struct DistractionReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "distraction_summary")

    struct ReportData {
        var totalDuration: TimeInterval = 0
    }

    typealias Configuration = ReportData

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ReportData {
        var total: TimeInterval = 0
        var appEntries: [[String: Any]] = []

        for await activityData in data {
            for await segment in activityData.activitySegments {
                for await category in segment.categories {
                    for await app in category.applications {
                        let duration = app.totalActivityDuration
                        total += duration
                        if duration > 0,
                           let token = app.application.token,
                           let tokenData = try? JSONEncoder().encode(token) {
                            appEntries.append([
                                "token": tokenData.base64EncodedString(),
                                "duration": duration
                            ])
                        }
                    }
                }
            }
        }

        // Merge duplicates (same token across segments)
        var merged: [String: TimeInterval] = [:]
        for entry in appEntries {
            if let key = entry["token"] as? String,
               let dur = entry["duration"] as? TimeInterval {
                merged[key, default: 0] += dur
            }
        }

        // Sort by duration descending and write to App Group
        let sorted = merged.sorted { $0.value > $1.value }.map { key, dur in
            ["token": key, "duration": dur] as [String: Any]
        }

        let defaults = UserDefaults(suiteName: "group.com.tamagoosie")
        if !sorted.isEmpty {
            defaults?.set(sorted, forKey: "appUsageEntries")
        }
        defaults?.set(Int(total / 60), forKey: "distractionApproxMinutes")

        if total == 0 {
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

// MARK: - All Apps Usage Report Scene

struct AllAppsReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "all_apps_usage")

    struct ReportData {
        var totalScreenTime: TimeInterval = 0
        var totalPickups: Int = 0
    }

    typealias Configuration = ReportData

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ReportData {
        let defaults = UserDefaults(suiteName: "group.com.tamagoosie")

        // Read the app category map to determine distracting apps
        // Key: base64-encoded token, Value: "productive" | "neutral" | "distracting"
        let appCategoryMap: [String: String] = defaults?.dictionary(forKey: "appCategoryMap") as? [String: String] ?? [:]

        var totalScreenTime: TimeInterval = 0
        var totalPickups: Int = 0

        // Per-app usage: token (base64) -> duration
        var appDurations: [String: TimeInterval] = [:]

        // Per-hour breakdown: hour (0-23) -> (totalSeconds, distractingSeconds)
        var hourlyTotal: [Int: TimeInterval] = [:]
        var hourlyDistracting: [Int: TimeInterval] = [:]

        for await activityData in data {
            for await segment in activityData.activitySegments {
                let hour = Calendar.current.component(.hour, from: segment.dateInterval.start)

                for await category in segment.categories {
                    for await app in category.applications {
                        let duration = app.totalActivityDuration
                        guard duration > 0 else { continue }

                        totalScreenTime += duration

                        // Accumulate per-hour totals
                        hourlyTotal[hour, default: 0] += duration

                        // Encode token and accumulate per-app
                        if let token = app.application.token,
                           let tokenData = try? JSONEncoder().encode(token) {
                            let tokenKey = tokenData.base64EncodedString()
                            appDurations[tokenKey, default: 0] += duration

                            // Check if this app is distracting
                            let category = appCategoryMap[tokenKey] ?? "neutral"
                            if category == "distracting" {
                                hourlyDistracting[hour, default: 0] += duration
                            }
                        }
                    }
                }
            }
        }

        // Build sorted per-app entries
        let sortedEntries = appDurations.sorted { $0.value > $1.value }.map { key, dur in
            ["token": key, "duration": dur] as [String: Any]
        }

        // Build hourly usage data (all 24 hours)
        var hourlyUsageData: [[String: Any]] = []
        for hour in 0..<24 {
            hourlyUsageData.append([
                "hour": hour,
                "totalSeconds": hourlyTotal[hour, default: 0],
                "distractingSeconds": hourlyDistracting[hour, default: 0]
            ])
        }

        // Write all data to App Group UserDefaults
        if !sortedEntries.isEmpty {
            defaults?.set(sortedEntries, forKey: "allAppsUsageEntries")
        }
        defaults?.set(hourlyUsageData, forKey: "hourlyUsageData")
        defaults?.set(totalScreenTime, forKey: "totalScreenTimeSeconds")
        defaults?.set(totalPickups, forKey: "totalPickups")

        return ReportData(totalScreenTime: totalScreenTime, totalPickups: totalPickups)
    }

    var content: (ReportData) -> AnyView = { (config: ReportData) in
        AnyView(
            VStack(spacing: 8) {
                let hours = Int(config.totalScreenTime) / 3600
                let minutes = (Int(config.totalScreenTime) % 3600) / 60
                if hours > 0 {
                    Text("\(hours)h \(minutes)m total")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.45))
                } else {
                    Text("\(minutes)m total")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.45))
                }
            }
            .frame(maxWidth: .infinity)
        )
    }
}

@main
struct DistractionReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        DistractionReportScene()
        AllAppsReportScene()
    }
}
