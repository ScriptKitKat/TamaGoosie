import SwiftUI

// MARK: - Stat Bar

struct StatBar: View {
    let label: String
    let icon: String
    let value: Double // 0...100
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 22)

            Text(label)
                .font(GoosieTheme.captionFont())
                .foregroundStyle(GoosieTheme.charcoalOutline)
                .frame(width: 70, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.18))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * (value / 100)))
                        .shadow(color: color.opacity(0.3), radius: 4, y: 2)
                }
            }
            .frame(height: 12)

            Text("\(Int(value))")
                .font(GoosieTheme.captionFont(12))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                .frame(width: 28, alignment: .trailing)
        }
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
                .stroke(GoosieTheme.hygieneGreen.opacity(0.25), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(GoosieTheme.hygieneGreen, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
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
