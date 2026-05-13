import SwiftUI
import SwiftData
import DeviceActivity
import FamilyControls

struct ScreenTimeDashboardView: View {
    @State private var manager = ScreenTimeManager.shared
    @State private var selectedPeriod = 0
    @State private var selectedDate = Date()
    @State private var showEditSheet = false
    @State private var showPicker = false
    @State private var draftSelection = FamilyActivitySelection()

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
        ScrollView {
            VStack(spacing: 16) {
                periodPicker
                dateNavigation
                statCards
                distributionReport
                actionButtons
            }
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 8)
            .trackScrollOffset()
        }
        .sheet(isPresented: $showEditSheet) {
            editPlanSheet
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $draftSelection)
        .onChange(of: showPicker) { wasShowing, isShowing in
            if wasShowing && !isShowing {
                manager.saveSelection(draftSelection)
            }
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            Text("Day").tag(0)
            Text("Week").tag(1)
        }
        .pickerStyle(.segmented)
    }

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
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
            }

            Spacer()

            Text(dateLabel)
                .font(GoosieTheme.bodyFont(15))
                .foregroundStyle(GoosieTheme.charcoalOutline)

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
                    .foregroundStyle(
                        isToday ? GoosieTheme.charcoalOutline.opacity(0.15) : GoosieTheme.charcoalOutline.opacity(0.5)
                    )
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

    private var statCards: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "iphone.slash",
                iconColor: GoosieTheme.coralAccent,
                title: "Distraction Time",
                value: formatMinutes(distractionMinutesForPeriod),
                change: distractionChange
            )

            statCard(
                icon: "hourglass",
                iconColor: GoosieTheme.skyBlue,
                title: "Limit Remaining",
                value: formatMinutes(max(0, manager.userLimitMinutes - currentDistractionMinutes)),
                change: nil
            )
        }
    }

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
        if selectedPeriod == 0 {
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
        return nil
    }

    private func statCard(icon: String, iconColor: Color, title: String, value: String, change: String?) -> some View {
        GoosieCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(iconColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(GoosieTheme.captionFont(12))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                Text(value)
                    .font(GoosieTheme.titleFont(22))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                if let change {
                    Text(change)
                        .font(GoosieTheme.captionFont(11))
                        .foregroundStyle(changeColor(change))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(changeColor(change).opacity(0.12), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func changeColor(_ change: String) -> Color {
        if change.hasPrefix("-") { return .green }
        else if change.hasPrefix("+") { return GoosieTheme.coralAccent }
        return GoosieTheme.charcoalOutline.opacity(0.5)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    private var distributionReport: some View {
        GoosieCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(GoosieTheme.skyBlue)
                    Text("Screen Time Distribution")
                        .font(GoosieTheme.bodyFont(14))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                }
                DeviceActivityReport(.init(rawValue: "distraction_summary"))
                    .frame(height: 120)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showEditSheet = true
            } label: {
                HStack {
                    Text("Edit Plan")
                        .font(GoosieTheme.bodyFont(15))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                }
                .padding(GoosieTheme.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: GoosieTheme.smallCornerRadius)
                        .fill(GoosieTheme.creamWhite)
                )
            }

            GoosieCard {
                HStack {
                    Text("Pause Plan")
                        .font(GoosieTheme.bodyFont(15))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { manager.isPaused },
                        set: { manager.isPaused = $0 }
                    ))
                    .labelsHidden()
                    .tint(GoosieTheme.coralAccent)
                }
            }
        }
    }

    private var editPlanSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PillButton(
                        title: "Change Selected Apps",
                        icon: "app.badge",
                        color: GoosieTheme.coralAccent
                    ) {
                        draftSelection = manager.selection
                        showPicker = true
                    }

                    if manager.hasSelection {
                        let count = manager.selection.applicationTokens.count + manager.selection.categoryTokens.count
                        Text("\(count) item\(count == 1 ? "" : "s") selected")
                            .font(GoosieTheme.captionFont(12))
                            .foregroundStyle(GoosieTheme.skyBlue)
                    }

                    ScreenTimeScheduleView {
                        showEditSheet = false
                    }
                }
                .padding(GoosieTheme.padding)
            }
            .background(GoosieTheme.mintBackground.ignoresSafeArea())
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEditSheet = false }
                }
            }
        }
    }
}
