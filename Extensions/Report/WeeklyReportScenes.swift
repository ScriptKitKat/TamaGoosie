import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

// MARK: - Weekly Summary Report Scene

struct WeeklySummaryReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "weekly_summary")

    struct DailyBucket {
        let date: Date
        var totalSeconds: TimeInterval = 0
        var distractingSeconds: TimeInterval = 0
    }

    struct ReportData {
        var totalScreenTime: TimeInterval = 0
        var totalPickups: Int = 0
        var distractingMinutes: Int = 0
        var topAppTokens: [ApplicationToken] = []
        var dailyBuckets: [DailyBucket] = []
        var dayCount: Int = 0
    }

    typealias Configuration = ReportData

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ReportData {
        let appCategoryMap = DistractionReportScene.loadCategoryMap()
        let calendar = Calendar.current

        var totalScreenTime: TimeInterval = 0
        var totalPickups = 0
        var appDurations: [String: (token: ApplicationToken, duration: TimeInterval)] = [:]
        var dailyTotals: [DateComponents: (total: TimeInterval, distracting: TimeInterval)] = [:]
        var datesSet: Set<DateComponents> = []

        for await activityData in data {
            for await segment in activityData.activitySegments {
                let dayComponents = calendar.dateComponents([.year, .month, .day], from: segment.dateInterval.start)
                datesSet.insert(dayComponents)

                let segmentDuration = segment.totalActivityDuration
                var segmentAppDuration: TimeInterval = 0
                var segmentDistractingSec: TimeInterval = 0
                totalPickups += segment.totalPickupsWithoutApplicationActivity

                for await category in segment.categories {
                    for await app in category.applications {
                        let duration = app.totalActivityDuration
                        guard duration > 0 else { continue }
                        segmentAppDuration += duration
                        totalPickups += app.numberOfPickups

                        if let token = app.application.token {
                            let key = (try? JSONEncoder().encode(token))?.base64EncodedString() ?? "\(token.hashValue)"

                            if let existing = appDurations[key] {
                                appDurations[key] = (token: existing.token, duration: existing.duration + duration)
                            } else {
                                appDurations[key] = (token: token, duration: duration)
                            }

                            let cat = appCategoryMap[key] ?? "distracting"
                            if cat == "distracting" {
                                segmentDistractingSec += duration
                            }
                        }
                    }
                }

                let effective = max(segmentDuration, segmentAppDuration)
                totalScreenTime += effective

                let existing = dailyTotals[dayComponents] ?? (total: 0, distracting: 0)
                dailyTotals[dayComponents] = (
                    total: existing.total + effective,
                    distracting: existing.distracting + segmentDistractingSec
                )
            }
        }

        // Build sorted daily buckets for the last 7 days
        let startOfToday = calendar.startOfDay(for: Date())
        var buckets: [DailyBucket] = []
        for dayOffset in (-6...0) {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday)!
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            let entry = dailyTotals[components]
            buckets.append(DailyBucket(
                date: date,
                totalSeconds: entry?.total ?? 0,
                distractingSeconds: entry?.distracting ?? 0
            ))
        }

        // Top 3 apps by aggregate duration
        let sorted = appDurations.sorted { $0.value.duration > $1.value.duration }
        let topTokens = sorted.prefix(3).map { $0.value.token }

        var distractingSec: TimeInterval = 0
        for (key, value) in appDurations {
            if (appCategoryMap[key] ?? "distracting") == "distracting" {
                distractingSec += value.duration
            }
        }

        return ReportData(
            totalScreenTime: totalScreenTime,
            totalPickups: totalPickups,
            distractingMinutes: Int(distractingSec / 60),
            topAppTokens: topTokens,
            dailyBuckets: buckets,
            dayCount: max(1, datesSet.count)
        )
    }

    var content: (ReportData) -> AnyView = { config in
        let awakeMinutesTotal = 960 * max(1, config.dayCount)
        let totalMinutes = Int(config.totalScreenTime / 60)
        let avgFocusScore = max(0, min(100, 100 - Int(round(Double(config.distractingMinutes) / Double(awakeMinutesTotal) * 100))))
        let totalOfflineMinutes = max(0, awakeMinutesTotal - totalMinutes)
        let avgOfflineMinutes = totalOfflineMinutes / max(1, config.dayCount)
        let avgOfflinePct = Int(round(Double(totalOfflineMinutes) / Double(awakeMinutesTotal) * 100))

        let accentGreen = Color(red: 0.29, green: 0.56, blue: 0.29)
        let focusGreen = Color(red: 0.40, green: 0.73, blue: 0.42)
        let distractedRed = Color(red: 0.90, green: 0.45, blue: 0.45)
        let lightGreen = Color(red: 0.91, green: 0.96, blue: 0.91)
        let charcoal = Color(red: 0.18, green: 0.18, blue: 0.18)

        let dayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f
        }()

        return AnyView(
            VStack(spacing: 14) {
                // Screen time header
                VStack(spacing: 6) {
                    Text(weeklyFormatTime(totalMinutes))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text("SCREEN TIME THIS WEEK")
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
                        Text("AVG FOCUS")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("\(avgFocusScore)%")
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

                // Daily bar graph card
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(focusGreen).frame(width: 8, height: 8)
                            Text("Focused")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(charcoal.opacity(0.5))
                        }
                        HStack(spacing: 4) {
                            Circle().fill(distractedRed).frame(width: 8, height: 8)
                            Text("Distracted")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(charcoal.opacity(0.5))
                        }
                    }

                    WeeklyBarGraphView(buckets: config.dailyBuckets, dayFormatter: dayFormatter, focusGreen: focusGreen, distractedRed: distractedRed, charcoal: charcoal)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                )

                // Avg time offline card
                HStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(accentGreen)
                        .frame(width: 36, height: 36)
                        .background(lightGreen, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avg Time Offline")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(charcoal)
                        Text("\(avgOfflinePct)% of your day")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(accentGreen)
                    }

                    Spacer()

                    Text(weeklyFormatTime(avgOfflineMinutes))
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

// MARK: - Weekly Bar Graph (extracted to avoid closure complexity)

private struct WeeklyBarGraphView: View {
    let buckets: [WeeklySummaryReportScene.DailyBucket]
    let dayFormatter: DateFormatter
    let focusGreen: Color
    let distractedRed: Color
    let charcoal: Color

    private var maxDailySeconds: TimeInterval {
        buckets.map(\.totalSeconds).max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(buckets.enumerated()), id: \.offset) { _, bucket in
                let distractSec = bucket.distractingSeconds
                let focusedSec = max(0, bucket.totalSeconds - distractSec)
                let maxH: CGFloat = 80
                let scale = maxDailySeconds > 0 ? maxH / maxDailySeconds : 0
                let focusedH = focusedSec * scale
                let distractH = distractSec * scale

                VStack(spacing: 2) {
                    if focusedH > 1 || distractH > 1 {
                        if focusedH > 1 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(focusGreen)
                                .frame(height: max(4, focusedH))
                        }
                        if distractH > 1 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(distractedRed)
                                .frame(height: max(4, distractH))
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(charcoal.opacity(0.08))
                            .frame(height: 4)
                    }

                    Text(dayFormatter.string(from: bucket.date))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(charcoal.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 100)
    }
}

// MARK: - Weekly Apps Usage Report Scene

struct WeeklyAppsReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "weekly_apps_usage")

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
        let appCategoryMap = DistractionReportScene.loadCategoryMap()

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
        AnyView(WeeklyAppUsageContentView(config: config))
    }
}

private struct WeeklyAppUsageContentView: View {
    let config: WeeklyAppsReportScene.ReportData
    @State private var categoryMap: [String: String]

    private let accentGreen = Color(red: 0.29, green: 0.56, blue: 0.29)
    private let charcoal = Color(red: 0.18, green: 0.18, blue: 0.18)
    private let distractedRed = Color(red: 0.90, green: 0.45, blue: 0.45)
    private let neutralGray = Color(red: 0.62, green: 0.62, blue: 0.62)

    init(config: WeeklyAppsReportScene.ReportData) {
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
                    Text("App Usage This Week")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(charcoal)

                    Spacer()

                    Text(weeklyFormatDuration(config.totalScreenTime))
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
                            weeklyAppRow(entry: entry)

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
    private func weeklyAppRow(entry: WeeklyAppsReportScene.AppEntry) -> some View {
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

                Text(weeklyFormatDuration(entry.durationSeconds))
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

// MARK: - Weekly Formatting Helpers

private func weeklyFormatTime(_ minutes: Int) -> String {
    if minutes >= 60 {
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
    return "\(minutes)m"
}

private func weeklyFormatDuration(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    if hours > 0 {
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }
    return "\(minutes)m"
}
