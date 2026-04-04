import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct GooseWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GooseWidgetEntry {
        GooseWidgetEntry(date: .now, stats: GooseStats())
    }

    func getSnapshot(in context: Context, completion: @escaping (GooseWidgetEntry) -> Void) {
        completion(GooseWidgetEntry(date: .now, stats: loadStats()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GooseWidgetEntry>) -> Void) {
        let entry = GooseWidgetEntry(date: .now, stats: loadStats())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadStats() -> GooseStats {
        guard let defaults = UserDefaults(suiteName: GoosieConstants.appGroupID),
              let data = defaults.data(forKey: GoosieConstants.gooseStatsKey),
              let stats = try? JSONDecoder().decode(GooseStats.self, from: data) else {
            return GooseStats()
        }
        return stats
    }
}

// MARK: - Timeline Entry

struct GooseWidgetEntry: TimelineEntry {
    let date: Date
    let stats: GooseStats
}

// MARK: - Small Widget

struct GooseWidgetSmall: View {
    let entry: GooseWidgetEntry

    var body: some View {
        VStack(spacing: 6) {
            Text(entry.stats.mood.emoji)
                .font(.system(size: 36))

            Text(entry.stats.gooseName)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)

            Text("\(Int(entry.stats.health))%")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(entry.stats.health > 30 ? Color.secondary : Color.red)
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
                Text(entry.stats.mood.emoji)
                    .font(.system(size: 40))

                Text(entry.stats.gooseName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)

                Text("Lv.\(entry.stats.level)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 80)

            // Right: Stats
            VStack(alignment: .leading, spacing: 6) {
                widgetStatBar("Health", value: entry.stats.health, color: .red)
                widgetStatBar("Happy", value: entry.stats.happiness, color: .yellow)
                widgetStatBar("Energy", value: entry.stats.energy, color: .blue)
                widgetStatBar("Hygiene", value: entry.stats.hygiene, color: .green)

                if entry.stats.streakDays > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("\(entry.stats.streakDays) day streak")
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
                        .frame(width: max(0, geo.size.width * (value / 100)))
                }
            }
            .frame(height: 6)

            Text("\(Int(value))")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 20)
        }
    }
}

// MARK: - Widget Configuration

@main
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
