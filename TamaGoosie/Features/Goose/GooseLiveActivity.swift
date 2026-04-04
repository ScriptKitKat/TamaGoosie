import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Activity Attributes

struct GoosePetActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var healthiness: Double
        var happiness: Double
        var mood: String
        var level: Int
        var streakDays: Int
        var currentGoalTitle: String?
        var currentGoalProgress: Double?
        var isFocusing: Bool
        var focusMinutesRemaining: Int?
    }

    var gooseName: String
}

// MARK: - Live Activity Widget

struct GooseLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GoosePetActivity.self) { context in
            lockScreenBanner(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    moodEmoji(context.state.mood)
                        .font(.system(size: 32))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Lv.\(context.state.level)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        if context.state.streakDays > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10))
                                Text("\(context.state.streakDays)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    if context.state.isFocusing, let minutes = context.state.focusMinutesRemaining {
                        Text("\(minutes)m left")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    } else {
                        Text(context.attributes.gooseName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isFocusing {
                        Text("Focusing...")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 12) {
                            miniStatBar(value: context.state.healthiness, color: .red, icon: "heart.fill")
                            miniStatBar(value: context.state.happiness, color: .yellow, icon: "face.smiling.fill")
                        }
                        .padding(.horizontal, 4)
                    }
                }
            } compactLeading: {
                moodEmoji(context.state.mood)
                    .font(.system(size: 16))
            } compactTrailing: {
                if context.state.isFocusing, let minutes = context.state.focusMinutesRemaining {
                    Text("\(minutes)m")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                } else {
                    Text("\(Int(context.state.healthiness * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(context.state.healthiness > 0.3 ? Color.primary : Color.red)
                }
            } minimal: {
                moodEmoji(context.state.mood)
                    .font(.system(size: 14))
            }
        }
    }

    // MARK: - Lock Screen Banner

    @ViewBuilder
    private func lockScreenBanner(context: ActivityViewContext<GoosePetActivity>) -> some View {
        HStack(spacing: 12) {
            moodEmoji(context.state.mood)
                .font(.system(size: 36))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(context.attributes.gooseName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Lv.\(context.state.level)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if context.state.isFocusing, let minutes = context.state.focusMinutesRemaining {
                    Text("Focusing - \(minutes)m remaining")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                } else if let goal = context.state.currentGoalTitle {
                    Text("Next: \(goal)")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(Int(context.state.healthiness * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                if context.state.streakDays > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                        Text("\(context.state.streakDays)")
                            .font(.system(size: 11, design: .rounded))
                    }
                    .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .background(Color(hex: 0xB8E8D0).opacity(0.3))
    }

    // MARK: - Helpers

    private func moodEmoji(_ moodRaw: String) -> Text {
        let mood = GooseMood(rawValue: moodRaw)
        return Text(mood?.emoji ?? "😌")
    }

    /// Display a mini stat bar for 0.0–1.0 values
    private func miniStatBar(value: Double, color: Color, icon: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(color)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.2))
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * value))
                }
            }
            .frame(height: 4)
        }
    }
}
