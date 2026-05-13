import SwiftUI

// MARK: - Stat Bar

struct StatBar: View {
    let label: String
    let icon: String
    let value: Double // 0...100
    let color: Color

    private var darkerColor: Color {
        color == GoosieTheme.healthRed
            ? Color(hex: 0xBF3B2B)
            : Color(hex: 0xB8722A)
    }

    private var lighterColor: Color {
        color == GoosieTheme.healthRed
            ? Color(hex: 0xF09080)
            : Color(hex: 0xF0B870)
    }

    var body: some View {
        GeometryReader { geo in
            let fillFraction = min(max(value / 100, 0), 1)
            let barWidth = geo.size.width
            let fillWidth = max(0, barWidth * fillFraction)

            ZStack(alignment: .leading) {
                // Outer track (darker border)
                RoundedRectangle(cornerRadius: 5)
                    .fill(darkerColor.opacity(0.35))

                // Inner track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: 0xF0F0F0))
                    .padding(2)

                // Fill bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [lighterColor, color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, fillWidth - 4))
                    .padding(2)

                // Shine highlight
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.35))
                    .frame(width: max(4, fillWidth - 8), height: 4)
                    .padding(.leading, 4)
                    .offset(y: -3)

                // Percentage
                Text("\(Int(value))%")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 8)
            }
        }
        .frame(height: 20)
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
    var size: CGFloat = 38
    var lineWidth: CGFloat = 4.5

    var body: some View {
        ZStack {
            // White badge background
            Circle()
                .fill(.white)
                .shadow(color: .black.opacity(0.10), radius: 2, y: 1)

            // Track
            Circle()
                .stroke(Color(hex: 0xE0E0E0), lineWidth: lineWidth)
                .padding(5)

            // Fill arc
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    Color(hex: 0x43A047),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(5)

            // Count text
            Text("\(completed)/\(total)")
                .font(.system(size: size * 0.26, weight: .heavy, design: .rounded))
                .foregroundStyle(.black.opacity(0.6))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Streak Flame

struct StreakFlame: View {
    let days: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(days > 0 ? Color(hex: 0xFF6D00) : .gray.opacity(0.3))
            Text("\(days)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(days > 0 ? .black.opacity(0.7) : .gray.opacity(0.4))
        }
    }
}

// MARK: - Goal + Streak Combined Badge

struct GoalStreakBadge: View {
    let progress: Double
    let completed: Int
    let total: Int
    let streakDays: Int

    var body: some View {
        HStack(spacing: 0) {
            // Goal ring
            ZStack {
                Circle()
                    .stroke(Color(hex: 0xE0E0E0), lineWidth: 3.5)

                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(
                        Color(hex: 0x43A047),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Image(systemName: "checklist")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: 0x43A047))
            }
            .frame(width: 28, height: 28)

            // Goal count
            Text("\(completed)/\(total)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.black.opacity(0.6))
                .padding(.leading, 6)

            // Divider
            RoundedRectangle(cornerRadius: 1)
                .fill(.black.opacity(0.12))
                .frame(width: 1.5, height: 16)
                .padding(.horizontal, 8)

            // Streak
            StreakFlame(days: streakDays)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.white)
                .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
        )
    }
}

// MARK: - Rounded Parallelogram Shape

struct RoundedParallelogram: Shape {
    var skew: CGFloat = 8
    var cornerRadius: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let s = skew
        let r = min(cornerRadius, min(w, h) / 2)

        // Four corners of the parallelogram (top-left skewed right, bottom-right skewed left)
        let topLeft = CGPoint(x: s, y: 0)
        let topRight = CGPoint(x: w, y: 0)
        let bottomRight = CGPoint(x: w - s, y: h)
        let bottomLeft = CGPoint(x: 0, y: h)

        var path = Path()

        // Start from top-left, offset by corner radius along the top edge
        path.move(to: lerp(topLeft, topRight, t: r / dist(topLeft, topRight)))

        // Top-right corner
        path.addLine(to: lerp(topRight, topLeft, t: r / dist(topLeft, topRight)))
        path.addQuadCurve(
            to: lerp(topRight, bottomRight, t: r / dist(topRight, bottomRight)),
            control: topRight
        )

        // Bottom-right corner
        path.addLine(to: lerp(bottomRight, topRight, t: r / dist(topRight, bottomRight)))
        path.addQuadCurve(
            to: lerp(bottomRight, bottomLeft, t: r / dist(bottomRight, bottomLeft)),
            control: bottomRight
        )

        // Bottom-left corner
        path.addLine(to: lerp(bottomLeft, bottomRight, t: r / dist(bottomRight, bottomLeft)))
        path.addQuadCurve(
            to: lerp(bottomLeft, topLeft, t: r / dist(bottomLeft, topLeft)),
            control: bottomLeft
        )

        // Top-left corner
        path.addLine(to: lerp(topLeft, bottomLeft, t: r / dist(bottomLeft, topLeft)))
        path.addQuadCurve(
            to: lerp(topLeft, topRight, t: r / dist(topLeft, topRight)),
            control: topLeft
        )

        path.closeSubpath()
        return path
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, t: CGFloat) -> CGPoint {
        let clamped = min(max(t, 0), 0.5)
        return CGPoint(x: a.x + (b.x - a.x) * clamped, y: a.y + (b.y - a.y) * clamped)
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }
}
