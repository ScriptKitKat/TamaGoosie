import SwiftUI

struct WeeklyHeatMap: View {
    let completionDates: [Date]

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let completedColor = Color(hex: 0x43A047)
    private let missedColor = Color(hex: 0xE8F5E9)
    private let futureColor = Color(hex: 0xEEEEEE)

    /// Returns the Monday-starting dates for the current week.
    private var weekDates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // weekday: 1=Sun, 2=Mon, ... 7=Sat
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7 // Mon=0, Tue=1, ... Sun=6
        guard let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return []
        }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    private func cellColor(for date: Date) -> Color {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        if date > today {
            return futureColor
        }

        let isCompleted = completionDates.contains { cal.isDate($0, inSameDayAs: date) }
        return isCompleted ? completedColor : missedColor
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(zip(weekDates.indices, weekDates)), id: \.0) { index, date in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(cellColor(for: date))
                        .frame(height: 18)

                    Text(dayLabels[index])
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.black.opacity(0.35))
                }
            }
        }
    }
}
