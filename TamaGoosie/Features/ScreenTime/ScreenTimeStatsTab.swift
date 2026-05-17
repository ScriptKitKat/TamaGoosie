import SwiftUI
import SwiftData

struct ScreenTimeStatsTab: View {
    @State private var manager = ScreenTimeManager.shared

    @Query(sort: \DailyLog.date, order: .reverse) private var allLogs: [DailyLog]
    @Query private var distractionApps: [DistractionApp]
    // Green palette
    private let accentGreen = Color(hex: 0x4A8F4A)
    private let focusGreen = Color(hex: 0x66BB6A)
    private let distractedRed = Color(hex: 0xE57373)
    private let lightGreen = Color(hex: 0xE8F5E9)

    private var todayLog: DailyLog? {
        allLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var currentMinutes: Int {
        todayLog?.distractionMinutes ?? manager.approxMinutesToday
    }

    private var limitMinutes: Int {
        manager.userLimitMinutes
    }

    private var focusScore: Int {
        guard limitMinutes > 0 else { return 100 }
        let used = min(currentMinutes, limitMinutes)
        return max(0, Int(round(Double(limitMinutes - used) / Double(limitMinutes) * 100)))
    }

    private let awakeMinutes = 960

    private var offlineMinutes: Int {
        max(0, awakeMinutes - currentMinutes)
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
        }
    }

    // MARK: - Screen Time Label (on green bg, white text)

    private var screenTimeLabel: some View {
        VStack(spacing: 6) {
            Text(formatTime(currentMinutes))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("SCREEN TIME TODAY")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 12)
    }

    // MARK: - Stats Row (on green bg, white text)

    private var statsRow: some View {
        HStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("MOST USED")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 4) {
                    appCircle(letter: "1", color: Color(hex: 0x5BA3D9))
                    appCircle(letter: "2", color: Color(hex: 0xFFB74D))
                    appCircle(letter: "3", color: Color(hex: 0xE87461))
                }
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
                Text("\(todayLog?.distractionOpens ?? 0)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 4)
    }

    private func appCircle(letter: String, color: Color) -> some View {
        Text(letter)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(color, in: Circle())
    }

    // MARK: - Timeline Chart Card (white)

    private var timelineCard: some View {
        VStack(spacing: 12) {
            // Legend
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
                ForEach(0..<14, id: \.self) { hourIndex in
                    timelineBlock(hourIndex: hourIndex)
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

    @ViewBuilder
    private func timelineBlock(hourIndex: Int) -> some View {
        let focusFraction = timelineFocusFraction(for: hourIndex)
        let distractFraction = 1.0 - focusFraction

        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3)
                .fill(focusGreen)
                .frame(height: max(4, CGFloat(focusFraction) * 60))

            if distractFraction > 0.1 {
                RoundedRectangle(cornerRadius: 3)
                    .fill(distractedRed)
                    .frame(height: max(4, CGFloat(distractFraction) * 20))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func timelineFocusFraction(for hourIndex: Int) -> Double {
        guard awakeMinutes > 0 else { return 1.0 }
        let overallFocus = Double(max(0, awakeMinutes - currentMinutes)) / Double(awakeMinutes)
        let variation = sin(Double(hourIndex) * 1.3) * 0.15
        return min(1.0, max(0.1, overallFocus + variation))
    }

    // MARK: - Time Offline Card (white)

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

    // MARK: - App Usage Cards (white)

    private var appUsageCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
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

            // App rows
            VStack(spacing: 0) {
                ForEach(distractionApps, id: \.id) { app in
                    appUsageRow(app: app)

                    if app.id != distractionApps.last?.id {
                        Divider()
                            .padding(.leading, 62)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
        .background(whiteCard)
    }

    private func appUsageRow(app: DistractionApp) -> some View {
        let usedMinutes = estimatedUsage(for: app)
        let limitMins = app.dailyLimitMinutes
        let progress = limitMins > 0 ? min(1.0, Double(usedMinutes) / Double(limitMins)) : 0
        let iconColor = appIconColor(for: app.bundleID)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(appAbbreviation(for: app.displayName))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(iconColor, in: RoundedRectangle(cornerRadius: 10))

                Text(app.displayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Spacer()

                Text(formatTime(usedMinutes))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(distractedRed)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(GoosieTheme.charcoalOutline.opacity(0.08))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(progress > 0.8 ? distractedRed : focusGreen)
                        .frame(width: max(4, geo.size.width * progress), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.leading, 48)

            Text("Distracting >")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(distractedRed)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(distractedRed.opacity(0.12), in: Capsule())
                .padding(.leading, 48)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func estimatedUsage(for app: DistractionApp) -> Int {
        guard !distractionApps.isEmpty else { return 0 }
        let totalDistraction = currentMinutes
        let totalWeight = distractionApps.reduce(0.0) { $0 + 1.0 / max(1.0, Double($1.dailyLimitMinutes)) }
        let appWeight = 1.0 / max(1.0, Double(app.dailyLimitMinutes))
        return Int(Double(totalDistraction) * (appWeight / max(0.001, totalWeight)))
    }

    private func appAbbreviation(for name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func appIconColor(for bundleID: String) -> Color {
        let hash = abs(bundleID.hashValue)
        let colors: [Color] = [
            Color(hex: 0xE87461),
            Color(hex: 0x5BA3D9),
            Color(hex: 0xFFB74D),
            Color(hex: 0x7E57C2),
            Color(hex: 0x4CAF50),
            Color(hex: 0xE91E63),
            Color(hex: 0x00BCD4),
        ]
        return colors[hash % colors.count]
    }

    // MARK: - Shared

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
