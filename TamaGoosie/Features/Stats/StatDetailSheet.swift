import SwiftUI
import SwiftData

enum StatDetailType: String, Identifiable {
    case healthTrends = "Health Trends"
    case happinessTrends = "Happiness Trends"
    case activityLog = "Activity Log"
    case sleepData = "Sleep Data"
    case bestDays = "Best Days"
    case baselines = "Baselines & More"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .healthTrends:    "heart.fill"
        case .happinessTrends: "face.smiling.fill"
        case .activityLog:     "figure.walk"
        case .sleepData:       "moon.fill"
        case .bestDays:        "trophy.fill"
        case .baselines:       "gearshape.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .healthTrends:    Color(hex: 0xEF5350)
        case .happinessTrends: Color(hex: 0xFFB300)
        case .activityLog:     Color(hex: 0x43A047)
        case .sleepData:       Color(hex: 0x5C6BC0)
        case .bestDays:        Color(hex: 0xF5A623)
        case .baselines:       Color(hex: 0x78909C)
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .healthTrends:    [Color(hex: 0xEF9A9A), Color(hex: 0xEF5350)]
        case .happinessTrends: [Color(hex: 0xFFE082), Color(hex: 0xFFB300)]
        case .activityLog:     [Color(hex: 0xA5D6A7), Color(hex: 0x43A047)]
        case .sleepData:       [Color(hex: 0x9FA8DA), Color(hex: 0x5C6BC0)]
        case .bestDays:        [Color(hex: 0xFFCC80), Color(hex: 0xF5A623)]
        case .baselines:       [Color(hex: 0xB0BEC5), Color(hex: 0x78909C)]
        }
    }
}

struct StatDetailSheet: View {
    let detailType: StatDetailType
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var allLogs: [DailyLog]
    @Query private var profiles: [UserProfile]
    @Query private var gooseStates: [GooseState]

    private var profile: UserProfile? { profiles.first }
    private var gooseName: String { gooseStates.first?.name ?? "Harold" }

    private var recentLogs: [DailyLog] {
        Array(allLogs.prefix(7))
    }

    private var bestDayLog: DailyLog? {
        let last90 = Array(allLogs.prefix(90))
        return last90.max {
            ($0.endOfDayHealthiness + $0.endOfDayHappiness) < ($1.endOfDayHealthiness + $1.endOfDayHappiness)
        }
    }

    private var overallGrade: String {
        guard let state = gooseStates.first else { return "C" }
        let avg = (state.healthiness + state.happiness) / 2.0
        if avg >= 0.9 { return "S" }
        if avg >= 0.8 { return "A" }
        if avg >= 0.65 { return "B" }
        if avg >= 0.45 { return "C" }
        if avg >= 0.25 { return "D" }
        return "E"
    }

    private var gradeMessage: String {
        switch overallGrade {
        case "S": return "\(gooseName) is absolutely thriving! Keep it up!"
        case "A": return "\(gooseName) is doing great! Almost perfect!"
        case "B": return "\(gooseName) is doing well. A little more effort and you'll be amazing!"
        case "C": return "\(gooseName) is doing okay. There's room for improvement!"
        case "D": return "\(gooseName) could use some more attention. Try to be more active!"
        default:  return "\(gooseName) needs help! Focus on health and goals."
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            LinearGradient(
                colors: [detailType.gradientColors[0].opacity(0.3), Color(hex: 0xF5F5F0)],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Title pill
                    Text(detailType.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(detailType.accentColor))
                        .padding(.top, 20)

                    // Grade badge area
                    gradeBadge
                        .padding(.top, 20)

                    // Grade message
                    Text(gradeMessage)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)

                    // Detail-specific content
                    detailContent
                        .padding(.top, 24)

                    Spacer(minLength: 80)
                }
            }

            // Dismiss button
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(.white)
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 16)
            .background(
                LinearGradient(
                    colors: [detailType.gradientColors[1], detailType.gradientColors[0]],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 90)
                .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    // MARK: - Grade Badge

    private var gradeBadge: some View {
        ZStack {
            // Sparkles
            ForEach(0..<4, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                    .foregroundStyle(detailType.accentColor.opacity(0.4))
                    .offset(
                        x: CGFloat([-50, 50, -35, 40][i]),
                        y: CGFloat([-20, -15, 25, 20][i])
                    )
            }

            // Badge
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .frame(width: 80, height: 80)
                    .shadow(color: detailType.accentColor.opacity(0.2), radius: 8, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(detailType.accentColor.opacity(0.3), lineWidth: 2)
                    )

                Text(overallGrade)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(detailType.accentColor)
            }

            Text("Overall Grade")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(detailType.accentColor.opacity(0.8))
                .offset(y: 56)
        }
        .frame(height: 130)
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch detailType {
        case .healthTrends:
            healthTrendsContent
        case .happinessTrends:
            happinessTrendsContent
        case .activityLog:
            activityLogContent
        case .sleepData:
            sleepDataContent
        case .bestDays:
            bestDaysContent
        case .baselines:
            baselinesContent
        }
    }

    // MARK: - Health Trends

    private var healthTrendsContent: some View {
        VStack(spacing: 0) {
            sectionHeader("Weekly Health")

            VStack(spacing: 0) {
                ForEach(recentLogs, id: \.id) { log in
                    summaryRow(
                        title: log.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                        value: "\(Int(log.endOfDayHealthiness * 100))%",
                        stars: starCount(log.endOfDayHealthiness),
                        icon: "heart.fill",
                        iconColor: GoosieTheme.healthRed
                    )
                    if log.id != recentLogs.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .padding(16)
            .background(whiteCard)
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)
        }
    }

    // MARK: - Happiness Trends

    private var happinessTrendsContent: some View {
        VStack(spacing: 0) {
            sectionHeader("Weekly Happiness")

            VStack(spacing: 0) {
                ForEach(recentLogs, id: \.id) { log in
                    summaryRow(
                        title: log.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                        value: "\(Int(log.endOfDayHappiness * 100))%",
                        stars: starCount(log.endOfDayHappiness),
                        icon: "face.smiling.fill",
                        iconColor: GoosieTheme.happinessYellow
                    )
                    if log.id != recentLogs.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .padding(16)
            .background(whiteCard)
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)
        }
    }

    // MARK: - Activity Log

    private var activityLogContent: some View {
        VStack(spacing: 0) {
            sectionHeader("Recent Activity")

            VStack(spacing: 0) {
                ForEach(recentLogs, id: \.id) { log in
                    HStack(spacing: 12) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: 0x43A047))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(GoosieTheme.charcoalOutline)

                            HStack(spacing: 12) {
                                statMini("figure.walk", "\(log.steps)")
                                statMini("heart.fill", "\(log.exerciseMinutes)m")
                                if isWatchPaired {
                                    statMini("chair.lounge.fill", String(format: "%.1fh", log.sittingHours))
                                }
                            }
                        }

                        Spacer()

                        starsView(count: starCount(Double(log.steps) / 10000.0))
                    }
                    .padding(.vertical, 8)

                    if log.id != recentLogs.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .padding(16)
            .background(whiteCard)
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)
        }
    }

    // MARK: - Sleep Data

    private var sleepDataContent: some View {
        VStack(spacing: 0) {
            sectionHeader("Sleep Summary")

            VStack(spacing: 0) {
                ForEach(recentLogs, id: \.id) { log in
                    summaryRow(
                        title: log.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                        value: String(format: "%.1fh", log.sleepHours),
                        stars: starCount(min(log.sleepHours / 8.0, 1.0)),
                        icon: "moon.fill",
                        iconColor: Color(hex: 0x5C6BC0)
                    )
                    if log.id != recentLogs.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .padding(16)
            .background(whiteCard)
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)

            if let profile {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your sleep baseline: \(String(format: "%.1f", profile.avgSleepHours))h")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(whiteCard)
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 12)
            }
        }
    }

    // MARK: - Best Days

    private var bestDaysContent: some View {
        VStack(spacing: 0) {
            sectionHeader("Top Performances")

            if let log = bestDayLog {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(GoosieTheme.warmOrange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All-Time Best")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                            Text(log.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                        }
                        Spacer()
                        starsView(count: 3)
                    }

                    Divider()

                    HStack(spacing: 12) {
                        scorePill(label: "Health", value: Int(log.endOfDayHealthiness * 100), color: Color(hex: 0x42A5F5))
                        scorePill(label: "Joy", value: Int(log.endOfDayHappiness * 100), color: Color(hex: 0xFFB300))
                    }

                    let details: [(String, String, String)] = [
                        ("figure.walk", "\(log.steps)", "steps"),
                        ("heart.fill", "\(log.exerciseMinutes)min", "exercise"),
                        ("moon.fill", "\(String(format: "%.1f", log.sleepHours))h", "sleep"),
                        ("checklist", "\(log.goalsCompleted)/\(log.goalsTotal)", "goals"),
                    ]

                    HStack(spacing: 0) {
                        ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                            VStack(spacing: 4) {
                                Image(systemName: detail.0)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: 0x43A047))
                                Text(detail.1)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                                Text(detail.2)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.45))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(16)
                .background(whiteCard)
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 12)
            } else {
                Text("Not enough data yet. Keep going!")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                    .padding(.top, 20)
            }
        }
    }

    // MARK: - Baselines

    private var isWatchPaired: Bool {
        profile?.watchPaired ?? false
    }

    private var baselinesContent: some View {
        VStack(spacing: 0) {
            sectionHeader("Your Baselines")

            if let profile {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Auto-updates after 7 days of data.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

                    Divider()

                    baselineRow("Sleep", value: "\(String(format: "%.1f", profile.avgSleepHours))h", icon: "moon.fill", color: Color(hex: 0x5C6BC0))
                    baselineRow("Steps", value: "\(profile.avgSteps)", icon: "figure.walk", color: Color(hex: 0x43A047))
                    baselineRow("Exercise", value: "\(profile.avgExerciseMinutes)min", icon: "heart.fill", color: GoosieTheme.healthRed)

                    if isWatchPaired {
                        baselineRow("Sitting", value: "\(String(format: "%.1f", profile.avgSittingHours))h", icon: "chair.lounge.fill", color: Color(hex: 0xBDBDBD))
                    }
                }
                .padding(16)
                .background(whiteCard)
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 12)
            } else {
                Text("Baselines will appear after a few days of data.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                    .padding(.top, 20)
            }
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(detailType.accentColor)
                .frame(width: 4, height: 20)
                .padding(.trailing, 10)

            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, GoosieTheme.padding)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: detailType.gradientColors,
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private func summaryRow(title: String, value: String, stars: Int, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)
                .frame(width: 44, alignment: .trailing)

            starsView(count: stars)
        }
        .padding(.vertical, 6)
    }

    private func starsView(count: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundStyle(i < count ? Color(hex: 0xF5A623) : Color(hex: 0xE0E0E0))
            }
        }
    }

    private func statMini(_ icon: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
        }
    }

    private func scorePill(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
            Spacer()
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.1)))
    }

    private func baselineRow(_ label: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)
        }
    }

    private var whiteCard: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.white)
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }

    private func starCount(_ value: Double) -> Int {
        if value >= 0.8 { return 3 }
        if value >= 0.5 { return 2 }
        if value > 0 { return 1 }
        return 0
    }
}
