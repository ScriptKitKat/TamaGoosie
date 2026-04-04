import SwiftUI

struct FriendCardView: View {
    let friend: FriendData
    var onRemove: () -> Void

    var body: some View {
        GoosieCard {
            HStack(spacing: 14) {
                // Mini goose
                GooseCharacterView(mood: friend.derivedMood)
                    .scaleEffect(0.3)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .background(
                        Circle()
                            .fill(GoosieTheme.creamWhite)
                            .frame(width: 64, height: 64)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.username)
                        .font(GoosieTheme.bodyFont())
                        .foregroundStyle(GoosieTheme.charcoalOutline)

                    Text(friend.gooseName)
                        .font(GoosieTheme.captionFont(12))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

                    HStack(spacing: 12) {
                        statPill(icon: "heart.fill", value: Int(friend.healthiness * 100), color: GoosieTheme.coralAccent)
                        statPill(icon: "face.smiling.fill", value: Int(friend.happiness * 100), color: GoosieTheme.happinessYellow)
                        if friend.streakDays > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(GoosieTheme.warmOrange)
                                Text("\(friend.streakDays)")
                                    .font(GoosieTheme.captionFont(11))
                                    .foregroundStyle(GoosieTheme.warmOrange)
                            }
                        }
                    }
                }

                Spacer()
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove Friend", systemImage: "person.badge.minus")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", systemImage: "person.badge.minus")
            }
        }
    }

    private func statPill(icon: String, value: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text("\(value)%")
                .font(GoosieTheme.captionFont(11))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
        }
    }
}
