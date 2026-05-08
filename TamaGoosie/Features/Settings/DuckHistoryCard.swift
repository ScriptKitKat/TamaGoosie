import SwiftUI
import SwiftData
import Charts

// MARK: - Card

struct DuckHistoryCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gooseStates: [GooseState]

    @State private var selectedRange: ChartRange = .week
    @State private var selectedPoint: DayPoint? = nil
    @State private var tooltipX: CGFloat = 0
    @State private var chartWidth: CGFloat = 300

    private let happinessColor: Color = GoosieTheme.sunYellow
    private let healthColor: Color    = GoosieTheme.skyBlue
    private let tooltipWidth: CGFloat = 136

    private var gooseName: String { gooseStates.first?.name ?? "Harold" }

    private var provider: DailyLogHistoryProvider {
        DailyLogHistoryProvider(modelContext: modelContext)
    }

    // MARK: - Derived

    private var todayPoint: DayPoint? {
        guard let state = gooseStates.first, state.healthiness > 0 || state.happiness > 0 else { return nil }
        return DayPoint(
            id: Calendar.current.startOfDay(for: .now),
            date: Calendar.current.startOfDay(for: .now),
            healthiness: state.healthiness,
            happiness: state.happiness
        )
    }

    private var filtered: [DayPoint] {
        var points = provider.fetchPoints(range: selectedRange)
        if let today = todayPoint {
            // Replace any existing entry for today, then re-sort
            points.removeAll { Calendar.current.isDateInToday($0.date) }
            points.append(today)
            points.sort { $0.date < $1.date }
        }
        return points
    }

    private var summary: ChartSummary {
        provider.computeSummary(currentPoints: filtered, range: selectedRange)
    }

    // MARK: - Body

    var body: some View {
        GoosieCard {
            VStack(alignment: .leading, spacing: 16) {
                headerRow
                if filtered.count >= 2 {
                    chartSection
                    summaryRow
                    legendRow
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 36))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.25))
            Text("\(gooseName) needs a few more days to show you trends")
                .font(GoosieTheme.captionFont(13))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Duck History")
                    .font(GoosieTheme.bodyFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                Text("Last \(selectedRange.days) Days")
                    .font(GoosieTheme.captionFont(11))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.45))
            }
            Spacer()
            rangeToggle
        }
    }

    private var rangeToggle: some View {
        HStack(spacing: 0) {
            ForEach(ChartRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedRange = range
                        selectedPoint = nil
                    }
                } label: {
                    Text(range.rawValue)
                        .font(GoosieTheme.captionFont(12))
                        .fontWeight(selectedRange == range ? .semibold : .regular)
                        .foregroundStyle(
                            selectedRange == range
                                ? GoosieTheme.creamWhite
                                : GoosieTheme.charcoalOutline.opacity(0.5)
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(selectedRange == range ? GoosieTheme.charcoalOutline : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(GoosieTheme.charcoalOutline.opacity(0.08)))
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        ZStack(alignment: .topLeading) {
            chartBody
                .frame(height: 180)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: selectedRange)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chartWidth = $0 }

            if let sel = selectedPoint {
                tooltipView(for: sel)
                    .frame(width: tooltipWidth)
                    .offset(x: clampedTooltipX, y: 4)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.2), value: selectedPoint?.date)
    }

    private var clampedTooltipX: CGFloat {
        max(0, min(tooltipX - tooltipWidth / 2, chartWidth - tooltipWidth))
    }

    // MARK: - Chart

    private var chartBody: some View {
        Chart {
            // Dashed reference lines
            RuleMark(y: .value("Ref50", 50.0))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.13))

            RuleMark(y: .value("Ref75", 75.0))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.13))

            // Happiness gradient fill
            ForEach(filtered) { pt in
                AreaMark(
                    x: .value("Date", pt.date),
                    yStart: .value("Base", 0.0),
                    yEnd: .value("Happiness", pt.joy)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [happinessColor.opacity(0.20), happinessColor.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Health gradient fill
            ForEach(filtered) { pt in
                AreaMark(
                    x: .value("Date", pt.date),
                    yStart: .value("Base", 0.0),
                    yEnd: .value("Health", pt.health)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [healthColor.opacity(0.16), healthColor.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Happiness line
            ForEach(filtered) { pt in
                LineMark(
                    x: .value("Date", pt.date),
                    y: .value("Happiness", pt.joy),
                    series: .value("Series", "Happiness")
                )
                .foregroundStyle(happinessColor)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            // Health line
            ForEach(filtered) { pt in
                LineMark(
                    x: .value("Date", pt.date),
                    y: .value("Health", pt.health),
                    series: .value("Series", "Health")
                )
                .foregroundStyle(healthColor)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            // Scrubber overlay
            if let sel = selectedPoint {
                RuleMark(x: .value("Selected", sel.date))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.28))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))

                PointMark(
                    x: .value("Date", sel.date),
                    y: .value("Happiness", sel.joy)
                )
                .foregroundStyle(happinessColor)
                .symbolSize(44)

                PointMark(
                    x: .value("Date", sel.date),
                    y: .value("Health", sel.health)
                )
                .foregroundStyle(healthColor)
                .symbolSize(44)
            }
        }
        .chartYScale(domain: 0.0...100.0)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: axisLabelCount)) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(xAxisLabel(for: date))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0.0, 50.0, 100.0]) { value in
                AxisGridLine().foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.07))
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text("\(Int(v))")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.35))
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let x = drag.location.x
                                guard let date = proxy.value(atX: x, as: Date.self) else { return }
                                let nearest = filtered.min {
                                    abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                }
                                withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                                    selectedPoint = nearest
                                }
                                // Snap tooltip to exact data point position if available
                                if let sel = nearest,
                                   let snappedX = proxy.position(forX: sel.date) {
                                    tooltipX = snappedX
                                } else {
                                    tooltipX = x
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.25)) {
                                    selectedPoint = nil
                                }
                            }
                    )
            }
        }
    }

    private var axisLabelCount: Int {
        switch selectedRange {
        case .week:    7
        case .month:   5
        case .quarter: 4
        }
    }

    private func xAxisLabel(for date: Date) -> String {
        let f = DateFormatter()
        switch selectedRange {
        case .week:    f.dateFormat = "EEE"
        case .month:   f.dateFormat = "MMM d"
        case .quarter: f.dateFormat = "MMM"
        }
        return f.string(from: date)
    }

    // MARK: - Tooltip

    private func tooltipView(for point: DayPoint) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(point.date, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)

            HStack(spacing: 4) {
                Circle().fill(happinessColor).frame(width: 7, height: 7)
                Text("Joy")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.55))
                Spacer()
                Text("\(Int(point.joy.rounded()))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
            }

            HStack(spacing: 4) {
                Circle().fill(healthColor).frame(width: 7, height: 7)
                Text("Health")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.55))
                Spacer()
                Text("\(Int(point.health.rounded()))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(GoosieTheme.creamWhite)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        )
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: 8) {
            statChip(
                label: "Avg Joy",
                value: "\(Int(summary.avgHappiness.rounded()))",
                trend: summary.happyTrend,
                tint: happinessColor
            )
            statChip(
                label: "Avg Health",
                value: "\(Int(summary.avgHealthiness.rounded()))",
                trend: summary.healthTrend,
                tint: healthColor
            )
            if let best = summary.bestDay {
                bestDayChip(date: best)
            }
        }
    }

    private func statChip(label: String, value: String, trend: Double?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(GoosieTheme.captionFont(10))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                if let trend {
                    Image(systemName: trend >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(
                            trend >= 0
                                ? Color(hue: 0.38, saturation: 0.55, brightness: 0.55)
                                : GoosieTheme.coralAccent
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.1)))
    }

    private func bestDayChip(date: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Best Day")
                .font(GoosieTheme.captionFont(10))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
            Text(date, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(GoosieTheme.warmOrange.opacity(0.1)))
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 14) {
            legendItem(color: happinessColor, label: "Happiness")
            legendItem(color: healthColor,    label: "Health")
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 14, height: 3)
            Text(label)
                .font(GoosieTheme.captionFont(11))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.55))
        }
    }
}
