import SwiftUI

// MARK: - Stat Bar

struct StatBar: View {
    let label: String
    let icon: String
    let value: Double // 0...100
    let color: Color

    private let barHeight: CGFloat = 38

    var body: some View {
        GeometryReader { geo in
            let fillWidth = max(0, geo.size.width * (value / 100))

            ZStack(alignment: .leading) {
                // Border outline
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(color.opacity(0.45), lineWidth: 2.5)

                // Fill bar
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.82)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)
                    .padding(2)
                    .shadow(color: color.opacity(0.25), radius: 4, y: 2)

                // Label inside the fill (white text)
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .heavy))
                    Text(label)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.leading, 12)
                // Only show when fill is wide enough
                .opacity(fillWidth > 80 ? 1 : 0)

                // Percentage on the right
                Text("\(Int(value))%")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 12)
            }
        }
        .frame(height: barHeight)
    }
}

// MARK: - Pill Button

struct PillButton: View {
    let title: String
    let icon: String
    let color: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(GoosieTheme.bodyFont(14))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(color, in: Capsule())
            .shadow(color: color.opacity(0.35), radius: 10, y: 5)
        }
    }
}

// MARK: - Circle Action Button

struct CircleActionButton: View {
    let icon: String
    let label: String
    let color: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(color, in: Circle())
                    .shadow(color: color.opacity(0.35), radius: 8, y: 4)

                Text(label)
                    .font(GoosieTheme.captionFont(11))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
            }
        }
    }
}

// MARK: - Card

struct GoosieCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(GoosieTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: GoosieTheme.smallCornerRadius)
                    .fill(GoosieTheme.creamWhite)
                    .overlay(
                        RoundedRectangle(cornerRadius: GoosieTheme.smallCornerRadius)
                            .strokeBorder(GoosieTheme.charcoalOutline.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: GoosieTheme.warmOrange.opacity(0.08), radius: 12, y: 5)
            )
    }
}

// MARK: - Goal Progress Ring

struct GoalProgressRing: View {
    let progress: Double // 0.0–1.0
    let completed: Int
    let total: Int
    var size: CGFloat = 32
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .stroke(GoosieTheme.warmOrange.opacity(0.25), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(GoosieTheme.warmOrange, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(completed)/\(total)")
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Streak Flame

struct StreakFlame: View {
    let days: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .foregroundStyle(days > 0 ? GoosieTheme.warmOrange : GoosieTheme.charcoalOutline.opacity(0.25))
            Text("\(days)")
                .font(GoosieTheme.bodyFont(14))
                .foregroundStyle(days > 0 ? GoosieTheme.charcoalOutline : GoosieTheme.charcoalOutline.opacity(0.4))
        }
    }
}
