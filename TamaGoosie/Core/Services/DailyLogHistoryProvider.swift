import Foundation
import SwiftData
import Observation

// MARK: - Chart Range

enum ChartRange: String, CaseIterable {
    case week = "7D"
    case month = "30D"
    case quarter = "90D"

    var days: Int {
        switch self {
        case .week:    7
        case .month:  30
        case .quarter: 90
        }
    }
}

// MARK: - Data Point

struct DayPoint: Identifiable {
    let id: Date
    let date: Date
    let healthiness: Double  // 0.0–1.0
    let happiness: Double    // 0.0–1.0

    /// Healthiness scaled to 0–100 for chart display.
    var health: Double { healthiness * 100 }
    /// Happiness scaled to 0–100 for chart display.
    var joy: Double { happiness * 100 }
}

// MARK: - Chart Summary

struct ChartSummary {
    let avgHealthiness: Double   // 0–100
    let avgHappiness: Double     // 0–100
    let healthTrend: Double?     // nil when no prior data
    let happyTrend: Double?      // nil when no prior data
    let bestDay: Date?
}

// MARK: - Provider

@Observable
final class DailyLogHistoryProvider {
    var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch

    func fetchPoints(range: ChartRange) -> [DayPoint] {
        fetchLogs(daysBack: range.days).map { log in
            DayPoint(
                id: log.date,
                date: log.date,
                healthiness: log.endOfDayHealthiness,
                happiness: log.endOfDayHappiness
            )
        }
    }

    // MARK: - Summary

    func computeSummary(currentPoints: [DayPoint], range: ChartRange) -> ChartSummary {
        let avgH = average(currentPoints.map(\.health))
        let avgJ = average(currentPoints.map(\.joy))

        // Prior period for trend comparison
        let priorLogs = fetchLogs(daysBack: range.days * 2, endDaysBack: range.days)
        let priorPoints = priorLogs.map { DayPoint(id: $0.date, date: $0.date, healthiness: $0.endOfDayHealthiness, happiness: $0.endOfDayHappiness) }

        let healthTrend: Double?
        let happyTrend: Double?

        if priorPoints.isEmpty {
            healthTrend = nil
            happyTrend = nil
        } else {
            let priorAvgH = average(priorPoints.map(\.health))
            let priorAvgJ = average(priorPoints.map(\.joy))
            healthTrend = avgH - priorAvgH
            happyTrend = avgJ - priorAvgJ
        }

        let bestDay = currentPoints.max {
            ($0.healthiness + $0.happiness) < ($1.healthiness + $1.happiness)
        }?.date

        return ChartSummary(
            avgHealthiness: avgH,
            avgHappiness: avgJ,
            healthTrend: healthTrend,
            happyTrend: happyTrend,
            bestDay: bestDay
        )
    }

    // MARK: - Private

    /// Fetches DailyLogs from `daysBack` ago to `endDaysBack` ago (default 0 = today).
    private func fetchLogs(daysBack: Int, endDaysBack: Int = 0) -> [DailyLog] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: calendar.startOfDay(for: .now)),
              let endDate = calendar.date(byAdding: .day, value: -endDaysBack, to: calendar.startOfDay(for: .now))
        else { return [] }

        let predicate = #Predicate<DailyLog> { log in
            log.date >= startDate && log.date < endDate
        }
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}
