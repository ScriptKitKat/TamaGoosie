import SwiftUI

struct OnboardingHealthView: View {
    let obState: OnboardingState
    let onAdvance: () -> Void

    @State private var requesting = false

    private let infoRows: [(icon: String, color: Color, text: String)] = [
        ("figure.walk",        Color(hex: 0x7ECBC4), "Steps & active minutes boost your goose's health"),
        ("moon.zzz.fill",      Color(hex: 0xA8D8EA), "Sleep hours keep energy levels up"),
        ("heart.fill",         Color(hex: 0xF4A683), "Exercise data fuels your goose's happiness"),
        ("rectangle.stack.fill", Color(hex: 0xFFD97A), "Stand hours reduce sitting penalties"),
    ]

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Duck + speech bubble
                VStack(spacing: 0) {
                    OBSpeechBubble(text: "I get stronger when you stay active!")
                        .padding(.horizontal, 40)

                    Spacer().frame(height: 8)

                    GooseCharacterView(mood: .ecstatic)
                        .frame(height: 160)
                }

                Spacer().frame(height: 28)

                // Title
                Text("Connect Health Data")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)

                Spacer().frame(height: 20)

                // Info rows
                VStack(spacing: 12) {
                    ForEach(infoRows.indices, id: \.self) { i in
                        let row = infoRows[i]
                        HStack(spacing: 14) {
                            Image(systemName: row.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(row.color)
                                .frame(width: 32)

                            Text(row.text)
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundStyle(OBTheme.text)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer()
                        }
                        .padding(.horizontal, 32)
                    }
                }

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    OBButton(title: requesting ? "Requesting…" : "Connect Health", isEnabled: !requesting) {
                        requesting = true
                        Task {
                            try? await HealthKitManager.shared.requestAuthorization()
                            await MainActor.run {
                                obState.healthAuthorized = true
                                requesting = false
                                onAdvance()
                            }
                        }
                    }

                    Button("Skip for now") { onAdvance() }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(OBTheme.secondary)
                }
                .padding(.bottom, 36)
            }
        }
    }
}
