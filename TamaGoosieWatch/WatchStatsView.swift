import SwiftUI

struct WatchStatsView: View {
    let steps: Int
    let exerciseMinutes: Int
    let sleepHours: Double
    let standHours: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Today")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(WatchTheme.text)
                    .padding(.bottom, 10)

                VStack(spacing: 8) {
                    statRow(
                        dot: WatchTheme.stepsBlue,
                        label: "Steps",
                        value: steps.formatted(),
                        valueColor: WatchTheme.stepsBlue,
                        fraction: Double(steps) / 10_000
                    )
                    statRow(
                        dot: WatchTheme.coral,
                        label: "Exercise",
                        value: "\(exerciseMinutes) min",
                        valueColor: WatchTheme.exerciseDark,
                        fraction: Double(exerciseMinutes) / 30
                    )
                    statRow(
                        dot: WatchTheme.sleepPurple,
                        label: "Sleep",
                        value: String(format: "%.1f hr", sleepHours),
                        valueColor: WatchTheme.sleepPurpleDark,
                        fraction: sleepHours / 9.0
                    )
                    statRow(
                        dot: WatchTheme.teal,
                        label: "Stand",
                        value: "\(standHours) hr",
                        valueColor: WatchTheme.standDark,
                        fraction: Double(standHours) / 12
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .background(WatchTheme.creamWhite)
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statRow(dot: Color, label: String, value: String, valueColor: Color, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Circle().fill(dot).frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(WatchTheme.text)
                Spacer()
                Text(value)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(valueColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(WatchTheme.border)
                    Capsule().fill(dot)
                        .frame(width: geo.size.width * max(0, min(1, fraction)))
                }
            }
            .frame(height: 3)
        }
    }
}

#Preview {
    NavigationStack {
        WatchStatsView(steps: 7_432, exerciseMinutes: 28, sleepHours: 7.2, standHours: 9)
    }
}
