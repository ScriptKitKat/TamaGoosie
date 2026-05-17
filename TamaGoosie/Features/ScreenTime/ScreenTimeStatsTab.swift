import SwiftUI
import SwiftData
import DeviceActivity

struct ScreenTimeStatsTab: View {
    @State private var manager = ScreenTimeManager.shared

    @Query(sort: \DailyLog.date, order: .reverse) private var allLogs: [DailyLog]

    private let chartBlue = Color(hex: 0x5BA3D9)
    private let chartBlueDark = Color(hex: 0x3B7CC0)
    private let distractedColor = Color(hex: 0xE87461)
    private let focusedColor = Color(hex: 0xFFFFFF)

    private var todayLog: DailyLog? {
        allLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var currentMinutes: Int {
        todayLog?.distractionMinutes ?? manager.approxMinutesToday
    }

    private var limitMinutes: Int {
        manager.userLimitMinutes
    }

    /// Focus score: % of limit NOT used (higher = better)
    private var focusScore: Int {
        guard limitMinutes > 0 else { return 100 }
        let used = min(currentMinutes, limitMinutes)
        return max(0, Int(round(Double(limitMinutes - used) / Double(limitMinutes) * 100)))
    }

    /// Last 7 days of logs for the weekly bar chart
    private var weekLogs: [DailyLog] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: .now)
        guard let weekAgo = cal.date(byAdding: .day, value: -6, to: startOfToday) else { return [] }
        return allLogs
            .filter { $0.date >= weekAgo }
            .sorted { $0.date < $1.date }
    }

    /// Average daily distraction time over the week
    private var weekAverageMinutes: Int {
        let logs = weekLogs
        guard !logs.isEmpty else { return currentMinutes }
        let total = logs.reduce(0) { $0 + $1.distractionMinutes }
        return total / logs.count
    }

    // Assume ~16 awake hours
    private let awakeMinutes = 960

    var body: some View {
        VStack(spacing: 14) {
            weeklyChartCard
            statsCards
            timeOfflineCard
            appUsageCard
        }
    }

    // MARK: - Weekly Chart Card (Pokemon Sleep style blue gradient)

    private var weeklyChartCard: some View {
        VStack(spacing: 0) {
            // Chart area
            VStack(spacing: 12) {
                // Y-axis labels + bars
                HStack(alignment: .top, spacing: 0) {
                    // Y-axis
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(formatTime(yAxisMax))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                        Spacer()
                        Text(formatTime(yAxisMax / 2))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                        Spacer()
                        Text("0")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 120)
                    .padding(.trailing, 6)

                    // Grid + bars
                    ZStack(alignment: .bottom) {
                        // Horizontal grid lines
                        VStack(spacing: 0) {
                            Rectangle().fill(.white.opacity(0.2)).frame(height: 1)
                            Spacer()
                            Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
                            Spacer()
                            Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
                        }
                        .frame(height: 120)

                        // Bars
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(0..<7, id: \.self) { dayOffset in
                                weekBar(dayOffset: dayOffset)
                            }
                        }
                        .frame(height: 120)
                    }
                }

                // Day labels
                HStack(spacing: 0) {
                    Spacer().frame(width: 42) // align with chart area
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { dayOffset in
                            let cal = Calendar.current
                            let day = cal.date(byAdding: .day, value: dayOffset - 6, to: cal.startOfDay(for: .now)) ?? .now
                            let isToday = cal.isDateInToday(day)

                            VStack(spacing: 1) {
                                Text(shortDayName(for: day))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                Text(dayNumber(for: day))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(isToday ? .white : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.top, 4)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [chartBlue, chartBlueDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )

            // Summary row below chart
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Average Screen Time")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                    Text("This Week")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                }

                Text(formatTime(weekAverageMinutes))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Spacer()

                // Legend
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(distractedColor).frame(width: 10, height: 10)
                        Text("Distracted")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(chartBlue.opacity(0.3)).frame(width: 10, height: 10)
                        Text("Focused")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            )
            .offset(y: -8)
        }
    }

    @ViewBuilder
    private func weekBar(dayOffset: Int) -> some View {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: dayOffset - 6, to: cal.startOfDay(for: .now)) ?? .now
        let log = weekLogs.first { cal.isDate($0.date, inSameDayAs: day) }
        let distractMins = log?.distractionMinutes ?? (cal.isDateInToday(day) ? currentMinutes : 0)
        let totalAwake = awakeMinutes
        let focusMins = max(0, totalAwake - distractMins)

        let distractHeight = barHeight(for: distractMins)
        let focusHeight = barHeight(for: focusMins)

        VStack(spacing: 2) {
            // Focused (white, top portion)
            RoundedRectangle(cornerRadius: 3)
                .fill(focusedColor.opacity(0.35))
                .frame(height: focusHeight)

            // Distracted (coral, bottom portion)
            RoundedRectangle(cornerRadius: 3)
                .fill(distractMins > limitMinutes ? distractedColor : distractedColor.opacity(0.7))
                .frame(height: distractHeight)
        }
        .frame(maxWidth: .infinity)
    }

    private var yAxisMax: Int {
        awakeMinutes
    }

    private func barHeight(for minutes: Int) -> CGFloat {
        let maxHeight: CGFloat = 110
        let ratio = Double(minutes) / Double(awakeMinutes)
        return max(2, CGFloat(ratio) * maxHeight)
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        HStack(spacing: 10) {
            statCard(
                icon: "clock.fill",
                iconColor: chartBlue,
                title: "Screen Time",
                value: formatTime(currentMinutes)
            )

            statCard(
                icon: "star.fill",
                iconColor: Color(hex: 0xFFB74D),
                title: "Focus Score",
                value: "\(focusScore)%"
            )

            statCard(
                icon: "hand.tap.fill",
                iconColor: GoosieTheme.coralAccent,
                title: "Pickups",
                value: "\(todayLog?.distractionOpens ?? 0)"
            )
        }
    }

    private func statCard(icon: String, iconColor: Color, title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)

            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }

    // MARK: - Time Offline Card

    private var timeOfflineCard: some View {
        let offlineMinutes = max(0, awakeMinutes - currentMinutes)
        let offlinePct = Int(round(Double(offlineMinutes) / Double(awakeMinutes) * 100))

        return HStack(spacing: 12) {
            Image(systemName: "moon.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: 0x7E57C2))

            VStack(alignment: .leading, spacing: 2) {
                Text("Time Offline")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                Text("\(offlinePct)% of your day")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
            }

            Spacer()

            Text(formatTime(offlineMinutes))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }

    // MARK: - App Usage Report

    private var appUsageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("App Usage")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)

            DeviceActivityReport(.init(rawValue: "distraction_summary"))
                .frame(height: 250)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }

    // MARK: - Helpers

    private func formatTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    private func shortDayName(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func dayNumber(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
