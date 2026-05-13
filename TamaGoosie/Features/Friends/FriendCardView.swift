import SwiftUI

struct FriendCardView: View {
    let friend: FriendData
    var onRemove: () -> Void

    private var scoreValue: Int {
        Int((friend.healthiness + friend.happiness) / 2.0 * 100)
    }

    private var ringColor: Color {
        let avg = (friend.healthiness + friend.happiness) / 2.0
        if avg >= 0.7 { return Color(hex: 0xF5A623) }
        if avg >= 0.4 { return Color(hex: 0x66BB6A) }
        return Color(hex: 0xBDBDBD)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar ring with score badge
            ZStack(alignment: .bottomLeading) {
                Circle()
                    .strokeBorder(ringColor, lineWidth: 2.5)
                    .frame(width: 52, height: 52)
                    .overlay {
                        GooseCharacterView(mood: friend.derivedMood)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    }

                // Score badge
                Text("\(scoreValue)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(
                                scoreValue >= 70
                                    ? Color(hex: 0x42A5F5)
                                    : scoreValue >= 40
                                        ? Color(hex: 0x66BB6A)
                                        : Color(hex: 0xBDBDBD)
                            )
                    )
                    .offset(x: -2, y: 2)
            }

            // Name + goose name + stats
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.username)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Text(friend.gooseName)
                    .font(.system(size: 12))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.45))

                // Health + Happiness + Streak
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(GoosieTheme.healthRed)
                        Text("\(Int(friend.healthiness * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "face.smiling.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(GoosieTheme.happinessYellow)
                        Text("\(Int(friend.happiness * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                    }

                    if friend.streakDays > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: 0xFF6D00))
                            Text("\(friend.streakDays)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: 0xFF6D00))
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, GoosieTheme.padding)
        .padding(.vertical, 12)
        .contextMenu {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove Friend", systemImage: "person.badge.minus")
            }
        }
    }
}
