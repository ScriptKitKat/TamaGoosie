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
            Circle().fill(Color(hex: 0xFFF8F0))
            Circle()
                .trim(from: 0, to: entry.payload.healthiness)
                .stroke(Color(hex: 0x7ECBC4), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(2)
            DuckFaceView(size: 22)
        }
    }
}

struct GooseComplicationRectangular: View {
    let entry: GooseComplicationEntry

    var body: some View {
        HStack(spacing: 6) {
            DuckFaceView(size: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.payload.name)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: 0x4A3728))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: 0xE8E0D4))
                        Capsule().fill(Color(hex: 0x7ECBC4))
                            .frame(width: geo.size.width * max(0, entry.payload.healthiness))
                    }
                }
                .frame(height: 3)

                if entry.payload.streakDays > 0 {
                    Text("\(entry.payload.streakDays)-day streak")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Color(hex: 0xA09080))
                }
            }
        }
    }
}

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
