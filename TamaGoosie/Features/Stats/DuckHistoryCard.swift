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

    private let happinessColor: Color = Color(hex: 0xFFD54F)
    private let healthColor: Color    = Color(hex: 0x42A5F5)
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
        VStack(alignment: .leading, spacing: 0) {
            // Blue chart area
            VStack(alignment: .leading, spacing: 12) {
                headerRow
                if filtered.count >= 2 {
                    chartSection
                } else {
                    emptyState
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x42A5F5), Color(hex: 0x1E88E5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )

            // Summary below chart
            if filtered.count >= 2 {
                summaryRow
                    .padding(.horizontal, 4)
                    .padding(.top, 14)

                legendRow
                    .padding(.horizontal, 4)
                    .padding(.top, 10)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.4))
            Text("\(gooseName) needs a few more days to show you trends")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Goose History")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Last \(selectedRange.days) Days")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
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
                        .font(.system(size: 11, weight: selectedRange == range ? .bold : .medium, design: .rounded))
                        .foregroundStyle(
                            selectedRange == range ? Color(hex: 0x1E88E5) : .white.opacity(0.7)
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(selectedRange == range ? .white : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(.white.opacity(0.15)))
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
            // Reference lines
            RuleMark(y: .value("Ref50", 50.0))
                .lineStyle(StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(.white.opacity(0.2))

            // Bar marks for health (blue bars)
            ForEach(filtered) { pt in
                BarMark(
                    x: .value("Date", pt.date, unit: .day),
                    y: .value("Health", pt.health)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: 0x90CAF9), Color(hex: 0x64B5F6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
            }

            // Happiness line overlay
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

            // Happiness dots
            ForEach(filtered) { pt in
                PointMark(
                    x: .value("Date", pt.date),
                    y: .value("Happiness", pt.joy)
                )
                .foregroundStyle(happinessColor)
                .symbolSize(20)
            }

            // Scrubber overlay
            if let sel = selectedPoint {
                RuleMark(x: .value("Selected", sel.date))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))

                PointMark(
                    x: .value("Date", sel.date),
                    y: .value("Happiness", sel.joy)
                )
                .foregroundStyle(happinessColor)
                .symbolSize(50)

                PointMark(
                    x: .value("Date", sel.date),
                    y: .value("Health", sel.health)
                )
                .foregroundStyle(.white)
                .symbolSize(50)
            }
        }
        .chartYScale(domain: 0.0...100.0)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: axisLabelCount)) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        VStack(spacing: 1) {
                            Text(dayName(for: date))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                            Text(dayNumber(for: date))
                                .font(.system(size: 9, weight: .regular, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0.0, 50.0, 100.0]) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.1))
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text("\(Int(v))")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
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

    private func dayName(for date: Date) -> String {
        let f = DateFormatter()
        switch selectedRange {
        case .week:    f.dateFormat = "EEE"
        case .month:   f.dateFormat = "MMM d"
        case .quarter: f.dateFormat = "MMM"
        }
        return f.string(from: date)
    }

    private func dayNumber(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
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
                .fill(.white)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
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
                .font(.system(size: 10, weight: .medium, design: .rounded))
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
                                ? Color(hex: 0x43A047)
                                : Color(hex: 0xEF5350)
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
                .font(.system(size: 10, weight: .medium, design: .rounded))
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
        HStack(spacing: 16) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(healthColor)
                    .frame(width: 14, height: 8)
                Text("Health")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.55))
            }
            HStack(spacing: 5) {
                Circle()
                    .fill(happinessColor)
                    .frame(width: 8, height: 8)
                RoundedRectangle(cornerRadius: 1)
                    .fill(happinessColor)
                    .frame(width: 10, height: 2)
                Text("Happiness")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.55))
            }
        }
    }
}
