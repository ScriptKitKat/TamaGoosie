import SwiftUI
import WidgetKit

struct GooseComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> GooseComplicationEntry {
        GooseComplicationEntry(date: .now, payload: GooseSyncPayload())
    }

    func getSnapshot(in context: Context, completion: @escaping (GooseComplicationEntry) -> Void) {
        completion(GooseComplicationEntry(date: .now, payload: loadPayload()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GooseComplicationEntry>) -> Void) {
        let entry = GooseComplicationEntry(date: .now, payload: loadPayload())
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

struct GooseComplicationEntry: TimelineEntry {
    let date: Date
    let payload: GooseSyncPayload
}

struct GooseComplicationCircular: View {
    let entry: GooseComplicationEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Circle()
                .trim(from: 0, to: entry.payload.healthiness)
                .stroke(.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(3)

            Text(entry.payload.moodEnum.emoji)
                .font(.system(size: 18))
        }
    }
}

struct GooseComplicationRectangular: View {
    let entry: GooseComplicationEntry

    var body: some View {
        HStack(spacing: 6) {
            Text(entry.payload.moodEnum.emoji)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.payload.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.gray.opacity(0.3))
                            Capsule().fill(.green)
                                .frame(width: max(0, geo.size.width * entry.payload.healthiness))
                        }
                    }
                    .frame(height: 5)
                }

                if entry.payload.streakDays > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                        Text("\(entry.payload.streakDays)")
                            .font(.system(size: 10, design: .rounded))
                    }
                }
            }
        }
    }
}

@main
struct GooseComplicationWidget: Widget {
    let kind = "GooseComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GooseComplicationProvider()) { entry in
            GooseComplicationCircular(entry: entry)
        }
        .configurationDisplayName("Goose Status")
        .description("See your goose's mood and health")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
