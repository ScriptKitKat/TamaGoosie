import SwiftUI
import SwiftData
import FamilyControls
import ManagedSettings
import DeviceActivity

struct ScreenTimeStatsTab: View {
    @State private var manager = ScreenTimeManager.shared

    @Query(sort: \DailyLog.date, order: .reverse) private var allLogs: [DailyLog]

    private let accentGreen = Color(hex: 0x4A8F4A)
    private let focusGreen = Color(hex: 0x66BB6A)
    private let distractedRed = Color(hex: 0xE57373)
    private let lightGreen = Color(hex: 0xE8F5E9)

    private let awakeMinutes = 960

    private var totalScreenMinutes: Int {
        let reported = manager.totalScreenTimeMinutes
        if reported > 0 { return reported }
        // Fallback to DailyLog
        let log = allLogs.first { Calendar.current.isDateInToday($0.date) }
        return log?.distractionMinutes ?? manager.approxMinutesToday
    }

    private var distractingMinutes: Int {
        manager.distractingMinutesToday
    }

    private var focusScore: Int {
        guard awakeMinutes > 0 else { return 100 }
        let distractPct = Double(distractingMinutes) / Double(awakeMinutes) * 100
        return max(0, min(100, Int(round(100 - distractPct))))
    }

    private var pickups: Int {
        let reported = manager.totalPickups
        if reported > 0 { return reported }
        let log = allLogs.first { Calendar.current.isDateInToday($0.date) }
        return log?.distractionOpens ?? 0
    }

    private var offlineMinutes: Int {
        max(0, awakeMinutes - totalScreenMinutes)
    }

    private var offlinePct: Int {
        Int(round(Double(offlineMinutes) / Double(awakeMinutes) * 100))
    }

    var body: some View {
        VStack(spacing: 14) {
            screenTimeLabel
            statsRow
            timelineCard
            timeOfflineCard
            appUsageCards

            // Hidden report views to trigger data collection
            DeviceActivityReport(.init(rawValue: "distraction_summary"))
                .frame(height: 0)
                .clipped()
            DeviceActivityReport(.init(rawValue: "all_apps_usage"))
                .frame(height: 0)
                .clipped()
        }
    }

    // MARK: - Screen Time Label

    private var screenTimeLabel: some View {
        VStack(spacing: 6) {
            Text(formatTime(totalScreenMinutes))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("SCREEN TIME TODAY")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 12)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            // Most Used — real app icons
            VStack(spacing: 6) {
                Text("MOST USED")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                mostUsedIcons
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 6) {
                Text("FOCUS LEVEL")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(focusScore)%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 6) {
                Text("PICKUPS")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(pickups)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var mostUsedIcons: some View {
        let topApps = Array(manager.allAppsUsageEntries.prefix(3))
        if topApps.isEmpty {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 26, height: 26)
                }
            }
        } else {
            HStack(spacing: 4) {
                ForEach(topApps) { entry in
                    Label(entry.token)
                        .labelStyle(.iconOnly)
                        .scaleEffect(1.1)
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Timeline Chart Card

    private var timelineCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(focusGreen).frame(width: 8, height: 8)
                    Text("Focused")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                }
                HStack(spacing: 4) {
                    Circle().fill(distractedRed).frame(width: 8, height: 8)
                    Text("Distracted")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                }
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(graphHours, id: \.self) { hour in
                    timelineBlock(hour: hour)
                }
            }
            .frame(height: 80)

            HStack {
                Text("9 AM")
                Spacer()
                Text("12 PM")
                Spacer()
                Text("3 PM")
                Spacer()
                Text("6 PM")
                Spacer()
                Text("9 PM")
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
        }
        .padding(16)
        .background(whiteCard)
    }

    /// Hours displayed in the graph (9 AM to 10 PM)
    private var graphHours: [Int] { Array(9...22) }

    @ViewBuilder
    private func timelineBlock(hour: Int) -> some View {
        let hourly = manager.hourlyUsageData
        let entry = hourly.first { $0.hour == hour }
        let totalSec = entry?.totalSeconds ?? 0
        let distractSec = entry?.distractingSeconds ?? 0
        let focusedSec = max(0, totalSec - distractSec)

        // Max possible is 3600 seconds (1 hour)
        let maxHeight: CGFloat = 60
        let focusedHeight = max(0, CGFloat(focusedSec / 3600) * maxHeight)
        let distractHeight = max(0, CGFloat(distractSec / 3600) * maxHeight)

        VStack(spacing: 2) {
            if focusedHeight > 0 || distractHeight > 0 {
                if focusedHeight > 1 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(focusGreen)
                        .frame(height: max(4, focusedHeight))
                }
                if distractHeight > 1 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(distractedRed)
                        .frame(height: max(4, distractHeight))
                }
            } else {
                // Empty hour — show minimal placeholder
                RoundedRectangle(cornerRadius: 3)
                    .fill(GoosieTheme.charcoalOutline.opacity(0.08))
                    .frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Time Offline Card

    private var timeOfflineCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 18))
                .foregroundStyle(accentGreen)
                .frame(width: 36, height: 36)
                .background(lightGreen, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Time Offline")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                Text("\(offlinePct)% of your day")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(accentGreen)
            }

            Spacer()

            Text(formatTime(offlineMinutes))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(accentGreen)
        }
        .padding(14)
        .background(whiteCard)
    }

    // MARK: - App Usage Card

    private var appUsageCards: some View {
        let entries = manager.allAppsUsageEntries

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentGreen)
                    .frame(width: 4, height: 18)

                Text("App Usage")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            if entries.isEmpty {
                Text("Usage data will appear after some screen time")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                let maxDuration = entries.first?.durationSeconds ?? 1

                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        appUsageRow(entry: entry, maxDuration: maxDuration)

                        if index < entries.count - 1 {
                            Divider()
                                .padding(.leading, 62)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
        .background(whiteCard)
    }

    private func appUsageRow(entry: ScreenTimeManager.AppUsageEntry, maxDuration: TimeInterval) -> some View {
        let category = manager.category(for: entry.token)
        let catColor = categoryColor(for: category)
        let catLabel = categoryLabel(for: category)
        let progress = maxDuration > 0 ? min(1.0, entry.durationSeconds / maxDuration) : 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Label(entry.token)
                    .labelStyle(.iconOnly)
                    .scaleEffect(1.6)
                    .frame(width: 40, height: 40)

                Label(entry.token)
                    .labelStyle(.titleOnly)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Spacer()

                Text(formatDuration(entry.durationSeconds))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(catColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(GoosieTheme.charcoalOutline.opacity(0.08))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(catColor)
                        .frame(width: max(4, geo.size.width * progress), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.leading, 52)

            Button {
                manager.cycleCategory(for: entry.token)
            } label: {
                Text("\(catLabel) >")
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

    // MARK: - Helpers

    private func categoryColor(for category: AppCategory) -> Color {
        switch category {
        case .productive: return accentGreen
        case .neutral: return Color(hex: 0x9E9E9E)
        case .distracting: return distractedRed
        }
    }

    private func categoryLabel(for category: AppCategory) -> String {
        switch category {
        case .productive: return "Productive"
        case .neutral: return "Neutral"
        case .distracting: return "Distracting"
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m \(secs)s"
    }

    private var whiteCard: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(.white)
            .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    private func formatTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
}
