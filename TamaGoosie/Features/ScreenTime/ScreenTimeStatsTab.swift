import SwiftUI
import SwiftData
import DeviceActivity

struct ScreenTimeStatsTab: View {
    @State private var manager = ScreenTimeManager.shared
    @State private var selectedPeriod = 0
    @State private var selectedDate = Date()

    @Query(sort: \DailyLog.date, order: .reverse) private var allLogs: [DailyLog]

    private var todayLog: DailyLog? {
        allLogs.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var yesterdayLog: DailyLog? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        return allLogs.first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var body: some View {
        VStack(spacing: 16) {
            periodPicker
            dateNavigation
            heroStat
            quickStatsRow
            distributionReport
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            Text("Day").tag(0)
            Text("Week").tag(1)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Date Navigation

    private var dateNavigation: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(
                    byAdding: selectedPeriod == 0 ? .day : .weekOfYear,
                    value: -1,
                    to: selectedDate
                ) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Text(dateLabel)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button {
                let next = Calendar.current.date(
                    byAdding: selectedPeriod == 0 ? .day : .weekOfYear,
                    value: 1,
                    to: selectedDate
                ) ?? selectedDate
                if next <= Date() {
                    selectedDate = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isToday ? .white.opacity(0.15) : .white.opacity(0.5))
            }
            .disabled(isToday)
        }
        .padding(.vertical, 4)
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let base = formatter.string(from: selectedDate)
        return isToday ? "\(base) (Today)" : base
    }

    // MARK: - Hero Stat

    private var heroStat: some View {
        VStack(spacing: 6) {
            Text(formatMinutes(distractionMinutesForPeriod))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("SCREEN TIME")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)

            if let change = distractionChange {
                Text(change)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(changeColor(change))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(changeColor(change).opacity(0.15), in: Capsule())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.08))
        )
    }

    // MARK: - Quick Stats

    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            quickStatCard(
                icon: "hourglass",
                iconColor: GoosieTheme.skyBlue,
                title: "Limit Remaining",
                value: formatMinutes(max(0, manager.userLimitMinutes - currentDistractionMinutes))
            )

            quickStatCard(
                icon: "iphone.gen1",
                iconColor: GoosieTheme.coralAccent,
                title: "Opens",
                value: "\(todayLog?.distractionOpens ?? 0)"
            )
        }
    }

    private func quickStatCard(icon: String, iconColor: Color, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(iconColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.08))
        )
    }

    // MARK: - Distribution Report

    private var distributionReport: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(GoosieTheme.skyBlue)
                Text("App Usage")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }

            DeviceActivityReport(.init(rawValue: "distraction_summary"))
                .frame(height: 250)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.08))
        )
    }

    // MARK: - Data Helpers

    private var distractionMinutesForPeriod: Int {
        if selectedPeriod == 0 {
            return todayLog?.distractionMinutes ?? (isToday ? manager.approxMinutesToday : 0)
        } else {
            let cal = Calendar.current
            guard let weekStart = cal.date(byAdding: .day, value: -6, to: selectedDate) else { return 0 }
            return allLogs
                .filter { $0.date >= cal.startOfDay(for: weekStart) && $0.date <= cal.startOfDay(for: selectedDate) }
                .reduce(0) { $0 + $1.distractionMinutes }
        }
    }

    private var currentDistractionMinutes: Int {
        todayLog?.distractionMinutes ?? manager.approxMinutesToday
    }

    private var distractionChange: String? {
        guard selectedPeriod == 0 else { return nil }
        guard let yesterday = yesterdayLog, yesterday.distractionMinutes > 0 else {
            return "No prior data"
        }
        let current = todayLog?.distractionMinutes ?? (isToday ? manager.approxMinutesToday : 0)
        if current == 0 && yesterday.distractionMinutes == 0 { return nil }
        let pct = Int(round(Double(current - yesterday.distractionMinutes) / Double(yesterday.distractionMinutes) * 100))
        if pct < 0 { return "\(pct)%" }
        else if pct > 0 { return "+\(pct)%" }
        return "No change"
    }

    private func changeColor(_ change: String) -> Color {
        if change.hasPrefix("-") { return .green }
        else if change.hasPrefix("+") { return GoosieTheme.coralAccent }
        return .white.opacity(0.5)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
}
