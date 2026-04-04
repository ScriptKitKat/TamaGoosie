import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct GooseWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GooseWidgetEntry {
        GooseWidgetEntry(date: .now, payload: GooseSyncPayload())
    }

    func getSnapshot(in context: Context, completion: @escaping (GooseWidgetEntry) -> Void) {
        completion(GooseWidgetEntry(date: .now, payload: loadPayload()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GooseWidgetEntry>) -> Void) {
        let entry = GooseWidgetEntry(date: .now, payload: loadPayload())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadPayload() -> GooseSyncPayload {
        guard let defaults = UserDefaults(suiteName: GoosieConstants.appGroupID),
              let data = defaults.data(forKey: GoosieConstants.gooseStatsKey),
              let payload = try? JSONDecoder().decode(GooseSyncPayload.self, from: data) else {
            return GooseSyncPayload()
        }
        return payload
    }
}

// MARK: - Timeline Entry

struct GooseWidgetEntry: TimelineEntry {
    let date: Date
    let payload: GooseSyncPayload
}

// MARK: - Small Widget

struct GooseWidgetSmall: View {
    let entry: GooseWidgetEntry

    var body: some View {
        VStack(spacing: 6) {
            Text(entry.payload.moodEnum.emoji)
                .font(.system(size: 36))

            Text(entry.payload.name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)

            Text("\(entry.payload.healthinessPercent)%")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(entry.payload.healthiness > 0.3 ? Color.secondary : Color.red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Color(hex: 0xB8E8D0).opacity(0.3)
        }
    }
}

// MARK: - Medium Widget

struct GooseWidgetMedium: View {
    let entry: GooseWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: Goose mood
            VStack(spacing: 4) {
                Text(entry.payload.moodEnum.emoji)
                    .font(.system(size: 40))

                Text(entry.payload.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)

                Text("Lv.\(entry.payload.level)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 80)

            // Right: Stats + Goals
            VStack(alignment: .leading, spacing: 6) {
                widgetStatBar("Health", value: entry.payload.healthiness, color: .red)
                widgetStatBar("Happy", value: entry.payload.happiness, color: .yellow)

                // Top goals
                ForEach(entry.payload.topGoals.prefix(3)) { goal in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(goal.progress >= 1.0 ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(goal.title)
                            .font(.system(size: 10))
                            .lineLimit(1)
                    }
                }

                if entry.payload.streakDays > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("\(entry.payload.streakDays) day streak")
                            .font(.system(size: 11, design: .rounded))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Color(hex: 0xB8E8D0).opacity(0.3)
        }
    }

    /// Display a stat bar for 0.0–1.0 values
    private func widgetStatBar(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10))
                .frame(width: 44, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.2))
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * value))
                }
            }
            .frame(height: 6)

            Text("\(Int(value * 100))")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 20)
        }
    }
}

// MARK: - Widget Configuration

struct GooseWidget: Widget {
    let kind = "GooseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GooseWidgetProvider()) { entry in
            GooseWidgetMedium(entry: entry)
        }
        .configurationDisplayName("TamaGoosie")
        .description("Keep an eye on your goose!")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct TamaGoosieWidgetBundle: WidgetBundle {
    var body: some Widget {
        GooseWidget()
        GooseLiveActivityWidget()
    }
}

// MARK: - Color Hex Extension (widget target cannot import main app module)

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
