import SwiftUI

struct OnboardingWelcomeView: View {
    let obState: OnboardingState
    let onGetStarted: () -> Void
    let onAlreadyHaveAccount: () -> Void

    @State private var bobOffset: CGFloat = 0

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Idle goose
                GooseCharacterView(mood: .happy)
                    .frame(height: 200)
                    .offset(y: bobOffset)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                            bobOffset = -10
                        }
                    }

                Spacer().frame(height: 32)

                // Title
                Text("Become a better version of yourself")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 12)

                // Subtitle
                Text("Your virtual goose reflects how well you take care of yourself.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(OBTheme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Primary CTA
                OBButton(title: "Get Started", isEnabled: true, action: onGetStarted)

                Spacer().frame(height: 16)

                // Secondary link
                Button(action: onAlreadyHaveAccount) {
                    Text("Already have an account?")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(OBTheme.teal)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 36)
            }
        }
    }
}
