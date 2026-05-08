import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Activity Attributes

struct GoosePetActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var healthiness: Double
        var happiness: Double
        var mood: String
        var streakDays: Int
        var currentGoalTitle: String?
        var currentGoalProgress: Double?
        var isFocusing: Bool
        var focusMinutesRemaining: Int?
        // Wandering goose
        var gooseX: Double        // 0.0–1.0 horizontal position across the stage
        var isMovingRight: Bool   // true = facing right
        var spriteKey: String     // e.g. "happy", "sad", "sick" — drives MiniGooseView
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
                    if context.state.streakDays > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.orange)
                            Text("\(context.state.streakDays)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Image(systemName: "flame")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.streakDays > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                            Text("\(context.state.streakDays)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    if context.state.isFocusing, let minutes = context.state.focusMinutesRemaining {
                        Text("Focusing — \(minutes)m")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    } else {
                        Text(context.attributes.gooseName)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    walkingStage(context: context)
                }
            } compactLeading: {
                MiniGooseView(
                    spriteKey: context.state.spriteKey,
                    isFlipped: !context.state.isMovingRight
                )
                .scaleEffect(0.72)
                .frame(width: 20, height: 23)
            } compactTrailing: {
                if context.state.isFocusing, let minutes = context.state.focusMinutesRemaining {
                    Text("\(minutes)m")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                } else {
                    StatRingsView(
                        healthiness: context.state.healthiness,
                        happiness: context.state.happiness
                    )
                    .frame(width: 22, height: 22)
                }
            } minimal: {
                MiniGooseView(
                    spriteKey: context.state.spriteKey,
                    isFlipped: !context.state.isMovingRight
                )
                .scaleEffect(0.60)
                .frame(width: 17, height: 19)
            }
        }
    }

    // MARK: - Walking Stage (bottom region)

    @ViewBuilder
    private func walkingStage(context: ActivityViewContext<GoosePetActivity>) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .center) {
                // Left: health bar
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.red)
                    miniStatBar(value: context.state.healthiness, color: .red)
                }
                .frame(width: 60)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: happiness bar
                HStack(spacing: 4) {
                    miniStatBar(value: context.state.happiness, color: .yellow)
                    Image(systemName: "face.smiling.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                }
                .frame(width: 60)
                .frame(maxWidth: .infinity, alignment: .trailing)

                // Goose walks in the center stage (between the two bars)
                let stageWidth = geo.size.width - 140  // 70pt margin each side
                let offset = (context.state.gooseX - 0.5) * stageWidth

                MiniGooseView(
                    spriteKey: context.state.spriteKey,
                    isFlipped: !context.state.isMovingRight
                )
                .offset(x: offset)
                .animation(.linear(duration: 2.3), value: context.state.gooseX)
            }
        }
        .frame(height: 42)
        .padding(.horizontal, 4)
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
                }

                if context.state.isFocusing, let minutes = context.state.focusMinutesRemaining {
                    Text("Focusing — \(minutes)m remaining")
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

    private func miniStatBar(value: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.2))
                Capsule()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * value))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Stat Rings View

/// Two concentric Activity-ring-style circles: outer = healthiness, inner = happiness.
private struct StatRingsView: View {
    let healthiness: Double
    let happiness: Double

    private let ringWidth: CGFloat = 3.5
    private let gap: CGFloat = 2

    var body: some View {
        ZStack {
            // Outer ring — healthiness (red)
            Circle()
                .stroke(Color.red.opacity(0.25), lineWidth: ringWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(healthiness, 1.0)))
                .stroke(Color.red, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Inner ring — happiness (yellow)
            let inset = ringWidth + gap
            Circle()
                .stroke(Color.yellow.opacity(0.25), lineWidth: ringWidth)
                .padding(inset)
            Circle()
                .trim(from: 0, to: CGFloat(min(happiness, 1.0)))
                .stroke(Color.yellow, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(inset)
        }
    }
}

// MARK: - Mini Goose View

/// Compact procedural goose for the Dynamic Island.
/// Appearance driven entirely by `spriteKey`: "happy", "neutral", "sad", "sick".
private struct MiniGooseView: View {
    let spriteKey: String
    let isFlipped: Bool

    private var bodyColor: Color {
        switch spriteKey {
        case "happy":   return .white
        case "neutral": return Color(white: 0.88)
        case "sad":     return Color(red: 0.78, green: 0.87, blue: 1.0)
        case "sick":    return Color(red: 0.80, green: 0.95, blue: 0.80)
        default:        return .white
        }
    }

    var body: some View {
        gooseBody
            .scaleEffect(x: isFlipped ? -1 : 1, y: 1)
            .frame(width: 28, height: 32)
    }

    private var gooseBody: some View {
        ZStack {
            // Body
            Ellipse()
                .fill(bodyColor)
                .frame(width: 20, height: 16)
                .offset(y: 6)

            // Neck
            Capsule()
                .fill(bodyColor)
                .frame(width: 7, height: 12)
                .offset(x: 4, y: -2)

            // Head
            Circle()
                .fill(bodyColor)
                .frame(width: 11, height: 11)
                .offset(x: 6, y: -8)

            // Beak — droops slightly when sad
            Triangle()
                .fill(spriteKey == "sick" ? Color.green.opacity(0.8) : Color.orange)
                .frame(width: 6, height: 4)
                .rotationEffect(spriteKey == "sad" ? .degrees(15) : .degrees(0))
                .offset(x: 12, y: spriteKey == "sad" ? -7 : -8)

            // Eye — X for sick, normal for others
            if spriteKey == "sick" {
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 4, height: 1.5)
                        .rotationEffect(.degrees(45))
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 4, height: 1.5)
                        .rotationEffect(.degrees(-45))
                }
                .offset(x: 8, y: -9)
            } else {
                Circle()
                    .fill(Color.black)
                    .frame(width: 3, height: 3)
                    .offset(x: 8, y: -9)
            }

            // Teardrop for sad
            if spriteKey == "sad" {
                Ellipse()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 2, height: 3)
                    .offset(x: 8, y: -6)
            }

            // Feet
            HStack(spacing: 4) {
                Capsule()
                    .fill(Color.orange.opacity(0.8))
                    .frame(width: 5, height: 3)
                Capsule()
                    .fill(Color.orange.opacity(0.8))
                    .frame(width: 5, height: 3)
            }
            .offset(y: 14)
        }
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
