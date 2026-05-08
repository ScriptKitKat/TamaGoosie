import SwiftUI

struct OnboardingNotificationsView: View {
    let obState: OnboardingState
    let onAdvance: () -> Void

    @State private var requesting = false

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Duck + speech bubble
                VStack(spacing: 0) {
                    OBSpeechBubble(text: "Honk! Don't forget to check on me today!")
                        .padding(.horizontal, 36)

                    Spacer().frame(height: 8)

                    GooseCharacterView(mood: .happy)
                        .frame(height: 160)
                }

                Spacer().frame(height: 28)

                // Title
                Text("Keep Track of\nYour Goals")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)
                    .multilineTextAlignment(.center)

                Text("We'll send you gentle reminders to check on your goose.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(OBTheme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)

                Spacer().frame(height: 24)

                // Fake notification preview card
                notificationPreview

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    OBButton(title: requesting ? "Requesting…" : "Remind Me", isEnabled: !requesting) {
                        requesting = true
                        Task {
                            _ = try? await NotificationManager.shared.requestAuthorization()
                            await MainActor.run {
                                obState.notificationsAuthorized = true
                                requesting = false
                                onAdvance()
                            }
                        }
                    }

                    Button("Maybe Later") { onAdvance() }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(OBTheme.secondary)
                }
                .padding(.bottom, 36)
            }
        }
    }

    private var notificationPreview: some View {
        HStack(spacing: 12) {
            // App icon stand-in
            RoundedRectangle(cornerRadius: 10)
                .fill(OBTheme.teal)
                .frame(width: 40, height: 40)
                .overlay(
                    Image("goose_icon")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("TamaGoosie")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(OBTheme.text)
                    Spacer()
                    Text("now")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(OBTheme.secondary)
                }

                Text("Honk! \(obState.gooseName) misses you. Come say hi! 🪿")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(OBTheme.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(OBTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(OBTheme.border, lineWidth: 1.5)
                )
                .shadow(color: OBTheme.border.opacity(0.5), radius: 6, y: 3)
        )
        .padding(.horizontal, 28)
    }
}
