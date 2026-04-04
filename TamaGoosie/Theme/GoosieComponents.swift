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
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(GoosieTheme.captionFont())
                .foregroundStyle(GoosieTheme.charcoalOutline)
                .frame(width: 70, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.2))

                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * (value / 100)))
                }
            }
            .frame(height: 10)

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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(color, in: Capsule())
            .shadow(color: color.opacity(0.3), radius: 8, y: 4)
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
                    .frame(width: 52, height: 52)
                    .background(color, in: Circle())
                    .shadow(color: color.opacity(0.3), radius: 6, y: 3)

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
            .background(GoosieTheme.creamWhite, in: RoundedRectangle(cornerRadius: GoosieTheme.smallCornerRadius))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

// MARK: - Level Badge

struct LevelBadge: View {
    let level: Int

    var body: some View {
        Text("Lv.\(level)")
            .font(GoosieTheme.captionFont(12))
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(GoosieTheme.warmOrange, in: Capsule())
    }
}

// MARK: - Streak Flame

struct StreakFlame: View {
    let days: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .foregroundStyle(GoosieTheme.warmOrange)
            Text("\(days)")
                .font(GoosieTheme.bodyFont(14))
                .foregroundStyle(GoosieTheme.charcoalOutline)
        }
    }
}
