import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

struct DistractionReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "distraction_summary")

    struct HourlyBucket {
        let hour: Int
        var totalSeconds: TimeInterval = 0
        var distractingSeconds: TimeInterval = 0
        var neutralSeconds: TimeInterval = 0
        var productiveSeconds: TimeInterval = 0
    }

    struct ReportData {
        var totalScreenTime: TimeInterval = 0
        var totalPickups: Int = 0
        var distractingMinutes: Int = 0
        var topAppTokens: [ApplicationToken] = []
        var hourlyBuckets: [HourlyBucket] = []
        var isToday: Bool = true
    }

    typealias Configuration = ReportData

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ReportData {
        let appCategoryMap = Self.loadCategoryMap()

        var totalScreenTime: TimeInterval = 0
        var totalPickups = 0
        var latestSegmentStart: Date = .distantPast
        var appDurations: [(key: String, token: ApplicationToken, duration: TimeInterval)] = []
        var hourlyTotal: [Int: TimeInterval] = [:]
        var hourlyDistracting: [Int: TimeInterval] = [:]
        var hourlyNeutral: [Int: TimeInterval] = [:]
        var hourlyProductive: [Int: TimeInterval] = [:]

        for await activityData in data {
            for await segment in activityData.activitySegments {
                if segment.dateInterval.start > latestSegmentStart {
                    latestSegmentStart = segment.dateInterval.start
                }
                let hour = Calendar.current.component(.hour, from: segment.dateInterval.start)
                let segmentDuration = segment.totalActivityDuration
                var segmentAppDuration: TimeInterval = 0
                totalPickups += segment.totalPickupsWithoutApplicationActivity

                for await category in segment.categories {
                    for await app in category.applications {
                        let duration = app.totalActivityDuration
                        guard duration > 0 else { continue }
                        segmentAppDuration += duration
                        totalPickups += app.numberOfPickups

                        if let token = app.application.token {
                            let key = (try? JSONEncoder().encode(token))?.base64EncodedString() ?? "\(token.hashValue)"
                            appDurations.append((key: key, token: token, duration: duration))

                            switch appCategoryMap[key] ?? "distracting" {
                            case "productive":
                                hourlyProductive[hour, default: 0] += duration
                            case "neutral":
                                hourlyNeutral[hour, default: 0] += duration
                            default:
                                hourlyDistracting[hour, default: 0] += duration
                            }
                        }
                    }
                }
                let effective = max(segmentDuration, segmentAppDuration)
                totalScreenTime += effective
                hourlyTotal[hour, default: 0] += effective
            }
        }

        // Merge app duplicates
        var merged: [String: (token: ApplicationToken, duration: TimeInterval)] = [:]
        for entry in appDurations {
            if let existing = merged[entry.key] {
                merged[entry.key] = (token: existing.token, duration: existing.duration + entry.duration)
            } else {
                merged[entry.key] = (token: entry.token, duration: entry.duration)
            }
        }

        let sorted = merged.sorted { $0.value.duration > $1.value.duration }
        let topTokens = sorted.prefix(3).map { $0.value.token }

        var distractingSec: TimeInterval = 0
        for (key, value) in merged {
            if (appCategoryMap[key] ?? "distracting") == "distracting" {
                distractingSec += value.duration
            }
        }

        // Build hourly buckets for graph
        let buckets = (0..<24).map { hour in
            HourlyBucket(
                hour: hour,
                totalSeconds: hourlyTotal[hour, default: 0],
                distractingSeconds: hourlyDistracting[hour, default: 0],
                neutralSeconds: hourlyNeutral[hour, default: 0],
                productiveSeconds: hourlyProductive[hour, default: 0]
            )
        }

        let startOfToday = Calendar.current.startOfDay(for: Date())
        let isToday = latestSegmentStart >= startOfToday || latestSegmentStart == .distantPast

        return ReportData(
            totalScreenTime: totalScreenTime,
            totalPickups: totalPickups,
            distractingMinutes: Int(distractingSec / 60),
            topAppTokens: topTokens,
            hourlyBuckets: buckets,
            isToday: isToday
        )
    }

    var content: (ReportData) -> AnyView = { (config: ReportData) in
        let awakeMinutes = 960
        let totalMinutes = Int(config.totalScreenTime / 60)
        let focusScore = max(0, min(100, 100 - Int(round(Double(config.distractingMinutes) / Double(awakeMinutes) * 100))))
        let offlineMinutes = max(0, awakeMinutes - totalMinutes)
        let offlinePct = Int(round(Double(offlineMinutes) / Double(awakeMinutes) * 100))

        let accentGreen = Color(red: 0.29, green: 0.56, blue: 0.29)
        let productiveGreen = Color(red: 0.40, green: 0.73, blue: 0.42)
        let neutralGray = Color(red: 0.62, green: 0.62, blue: 0.62)
        let distractedRed = Color(red: 0.90, green: 0.45, blue: 0.45)
        let offlineGreen = Color(red: 0.70, green: 0.85, blue: 0.72)
        let lightGreen = Color(red: 0.91, green: 0.96, blue: 0.91)
        let charcoal = Color(red: 0.18, green: 0.18, blue: 0.18)
        let mutedFill = charcoal.opacity(0.08)

        let graphHours = Array(9...22)
        let currentHour = Calendar.current.component(.hour, from: Date())
        let elapsedInCurrentHour = TimeInterval(Calendar.current.component(.minute, from: Date()) * 60
            + Calendar.current.component(.second, from: Date()))

        return AnyView(
            VStack(spacing: 14) {
                // Screen time header
                VStack(spacing: 6) {
                    Text(reportFormatTime(totalMinutes))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text(config.isToday ? "SCREEN TIME TODAY" : "SCREEN TIME YESTERDAY")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.vertical, 8)

                // Stats row
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("MOST USED")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        if config.topAppTokens.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Circle().fill(.white.opacity(0.2)).frame(width: 26, height: 26)
                                }
                            }
                        } else {
                            HStack(spacing: 4) {
                                ForEach(Array(config.topAppTokens.enumerated()), id: \.offset) { _, token in
                                    Label(token)
                                        .labelStyle(.iconOnly)
                                        .scaleEffect(1.1)
                                        .frame(width: 26, height: 26)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("FOCUS LEVEL")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("\(focusScore)%")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("PICKUPS")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("\(config.totalPickups)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 4)

                // Timeline graph card
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Spacer()
                        ForEach([
                            (productiveGreen, "Productive"),
                            (neutralGray, "Neutral"),
                            (distractedRed, "Distracting"),
                            (offlineGreen, "Offline")
                        ], id: \.1) { color, label in
                            HStack(spacing: 4) {
                                Circle().fill(color).frame(width: 8, height: 8)
                                Text(label)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(charcoal.opacity(0.5))
                            }
                        }
                    }

                    let barHeight: CGFloat = 60
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(graphHours, id: \.self) { hour in
                            HourBar(
                                bucket: config.hourlyBuckets.first { $0.hour == hour },
                                hour: hour,
                                currentHour: currentHour,
                                elapsedInCurrentHour: elapsedInCurrentHour,
                                isToday: config.isToday,
                                barHeight: barHeight,
                                productive: productiveGreen,
                                neutral: neutralGray,
                                distracting: distractedRed,
                                offline: offlineGreen,
                                muted: mutedFill
                            )
                        }
                    }
                    .frame(height: barHeight)

                    HStack {
                        Text("9 AM"); Spacer()
                        Text("12 PM"); Spacer()
                        Text("3 PM"); Spacer()
                        Text("6 PM"); Spacer()
                        Text("9 PM")
                    }
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(charcoal.opacity(0.4))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                )

                // Time offline card
                HStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(accentGreen)
                        .frame(width: 36, height: 36)
                        .background(lightGreen, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Time Offline")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(charcoal)
                        Text(config.isToday ? "\(offlinePct)% of your day" : "\(offlinePct)% of yesterday")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(accentGreen)
                    }

                    Spacer()

                    Text(reportFormatTime(offlineMinutes))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(accentGreen)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                )
            }
            .frame(maxWidth: .infinity)
        )
    }
}

// MARK: - HourBar

/// One column of the timeline graph. Renders an equal-height stacked bar:
/// distracting (top) → neutral → productive → offline (bottom). For the
/// in-progress hour, the not-yet-elapsed portion is rendered as a muted
/// segment at the top. Future hours and yesterday-only views never have
/// an unmeasured portion.
private struct HourBar: View {
    let bucket: DistractionReportScene.HourlyBucket?
    let hour: Int
    let currentHour: Int
    let elapsedInCurrentHour: TimeInterval
    let isToday: Bool
    let barHeight: CGFloat
    let productive: Color
    let neutral: Color
    let distracting: Color
    let offline: Color
    let muted: Color

    private static let hourSeconds: TimeInterval = 3600
    private static let minSegmentPt: CGFloat = 2

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                Rectangle()
                    .fill(seg.color)
                    .frame(height: seg.height)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private struct Segment { let color: Color; let height: CGFloat }

    /// Segments listed top → bottom.
    private var segments: [Segment] {
        // Future hour (today view only): the whole bar is unmeasured.
        if isToday, hour > currentHour {
            return [Segment(color: muted, height: barHeight)]
        }

        let distractingSec = bucket?.distractingSeconds ?? 0
        let neutralSec = bucket?.neutralSeconds ?? 0
        let productiveSec = bucket?.productiveSeconds ?? 0
        let usedSec = distractingSec + neutralSec + productiveSec

        // Capacity for the in-progress hour shrinks; for completed hours it's a full hour.
        let isCurrentHour = isToday && hour == currentHour
        let capacity: TimeInterval = isCurrentHour
            ? max(0, elapsedInCurrentHour)
            : Self.hourSeconds
        let offlineSec = max(0, capacity - usedSec)
        let unmeasuredSec: TimeInterval = isCurrentHour
            ? max(0, Self.hourSeconds - capacity)
            : 0

        // Each segment's height = seconds / 3600 * barHeight, so all bars
        // share the same vertical scale regardless of completeness.
        func h(_ sec: TimeInterval) -> CGFloat { CGFloat(sec / Self.hourSeconds) * barHeight }

        let raw: [Segment] = [
            Segment(color: muted, height: h(unmeasuredSec)),
            Segment(color: distracting, height: h(distractingSec)),
            Segment(color: neutral, height: h(neutralSec)),
            Segment(color: productive, height: h(productiveSec)),
            Segment(color: offline, height: h(offlineSec))
        ]
        let merged = Self.mergeBelowMinimum(raw)

        // Empty hour (no data at all) → render a thin muted bar so the column is still visible.
        if merged.isEmpty {
            return [Segment(color: muted, height: barHeight)]
        }
        return merged
    }

    /// Drop sub-`minSegmentPt` slices; for slices in `[minSegmentPt, 2*minSegmentPt)`,
    /// promote to the minimum. This is simpler than walking and merging downward
    /// and avoids visually invisible 0.5pt slivers.
    private static func mergeBelowMinimum(_ segments: [Segment]) -> [Segment] {
        segments.compactMap { seg in
            if seg.height <= 0.5 { return nil }
            if seg.height < minSegmentPt { return Segment(color: seg.color, height: minSegmentPt) }
            return seg
        }
    }
}

// MARK: - Shared Category Map Persistence

/// Extension's own UserDefaults is always writable; shared app group may not be.
/// Read from standard first, fall back to shared app group (written by main app).
enum CategoryMapStore {
    private static let key = "appCategoryMap"
    private static var shared: UserDefaults? { UserDefaults(suiteName: "group.com.tamagoosie") }

    static func load() -> [String: String] {
        if let map = UserDefaults.standard.dictionary(forKey: key) as? [String: String], !map.isEmpty {
            return map
        }
        return shared?.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    static func save(_ map: [String: String]) {
        UserDefaults.standard.set(map, forKey: key)
        shared?.set(map, forKey: key)
    }
}

extension DistractionReportScene {
    static func loadCategoryMap() -> [String: String] { CategoryMapStore.load() }
}

// MARK: - All Apps Usage Report Scene

struct AllAppsReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "all_apps_usage")

    struct AppEntry: Identifiable {
        let id: String
        let token: ApplicationToken
        let durationSeconds: TimeInterval
    }

    struct ReportData {
        var totalScreenTime: TimeInterval = 0
        var entries: [AppEntry] = []
        var categoryMap: [String: String] = [:]
    }

    typealias Configuration = ReportData

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ReportData {
        let appCategoryMap = CategoryMapStore.load()

        var totalScreenTime: TimeInterval = 0
        var appData: [String: (token: ApplicationToken, duration: TimeInterval)] = [:]

        for await activityData in data {
            for await segment in activityData.activitySegments {
                let segmentDuration = segment.totalActivityDuration
                var segmentAppDuration: TimeInterval = 0

                for await category in segment.categories {
                    for await app in category.applications {
                        let duration = app.totalActivityDuration
                        guard duration > 0 else { continue }
                        segmentAppDuration += duration

                        if let token = app.application.token,
                           let tokenData = try? JSONEncoder().encode(token) {
                            let tokenKey = tokenData.base64EncodedString()
                            if let existing = appData[tokenKey] {
                                appData[tokenKey] = (token: existing.token, duration: existing.duration + duration)
                            } else {
                                appData[tokenKey] = (token: token, duration: duration)
                            }
                        }
                    }
                }

                totalScreenTime += max(segmentDuration, segmentAppDuration)
            }
        }

        // Limit to top 20 apps
        let sortedEntries = appData.sorted { $0.value.duration > $1.value.duration }
            .prefix(20)
            .map { AppEntry(id: $0.key, token: $0.value.token, durationSeconds: $0.value.duration) }

        return ReportData(
            totalScreenTime: totalScreenTime,
            entries: sortedEntries,
            categoryMap: appCategoryMap
        )
    }

    var content: (ReportData) -> AnyView = { config in
        AnyView(AppUsageContentView(config: config))
    }
}

// MARK: - App Usage Content View (with tappable category tags)

private struct AppUsageContentView: View {
    let config: AllAppsReportScene.ReportData
    @State private var categoryMap: [String: String]

    private let accentGreen = Color(red: 0.29, green: 0.56, blue: 0.29)
    private let charcoal = Color(red: 0.18, green: 0.18, blue: 0.18)
    private let distractedRed = Color(red: 0.90, green: 0.45, blue: 0.45)
    private let neutralGray = Color(red: 0.62, green: 0.62, blue: 0.62)

    init(config: AllAppsReportScene.ReportData) {
        self.config = config
        self._categoryMap = State(initialValue: config.categoryMap)
    }

    private var maxDuration: TimeInterval {
        config.entries.first?.durationSeconds ?? 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentGreen)
                        .frame(width: 4, height: 18)
                    Text("App Usage")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(charcoal)

                    Spacer()

                    Text(reportFormatDuration(config.totalScreenTime))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accentGreen)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                if config.entries.isEmpty {
                    Text("Usage data will appear after some screen time")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(charcoal.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(config.entries.enumerated()), id: \.element.id) { index, entry in
                            appRow(entry: entry)

                            if index < config.entries.count - 1 {
                                Divider()
                                    .padding(.leading, 62)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
            )
        }
    }

    @ViewBuilder
    private func appRow(entry: AllAppsReportScene.AppEntry) -> some View {
        let catRaw = categoryMap[entry.id] ?? "distracting"
        let catColor = colorForCategory(catRaw)
        let catLabel = labelForCategory(catRaw)
        let progress = maxDuration > 0 ? min(1.0, entry.durationSeconds / maxDuration) : 0

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Label(entry.token)
                    .labelStyle(.iconOnly)
                    .scaleEffect(1.6)
                    .frame(width: 40, height: 40)

                Label(entry.token)
                    .labelStyle(.titleOnly)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(charcoal)

                Spacer()

                Text(reportFormatDuration(entry.durationSeconds))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(catColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(charcoal.opacity(0.08))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(catColor)
                        .frame(width: max(4, geo.size.width * progress), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.leading, 52)

            Button {
                cycleCategory(for: entry.id)
            } label: {
                Text(catLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(catColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(catColor.opacity(0.12), in: Capsule())
            }
            .padding(.leading, 52)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func cycleCategory(for appId: String) {
        let current = categoryMap[appId] ?? "distracting"
        let next: String
        switch current {
        case "distracting": next = "neutral"
        case "neutral": next = "productive"
        default: next = "distracting"
        }
        categoryMap[appId] = next
        CategoryMapStore.save(categoryMap)
    }

    private func colorForCategory(_ cat: String) -> Color {
        switch cat {
        case "productive": return accentGreen
        case "neutral": return neutralGray
        default: return distractedRed
        }
    }

    private func labelForCategory(_ cat: String) -> String {
        switch cat {
        case "productive": return "Productive"
        case "neutral": return "Neutral"
        default: return "Distracting"
        }
    }
}

private func reportFormatTime(_ minutes: Int) -> String {
    if minutes >= 60 {
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
    return "\(minutes)m"
}

private func reportFormatDuration(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    if hours > 0 {
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }
    return "\(minutes)m \(secs)s"
}

@main
struct DistractionReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        DistractionReportScene()
        AllAppsReportScene()
        WeeklySummaryReportScene()
        WeeklyAppsReportScene()
    }
}
