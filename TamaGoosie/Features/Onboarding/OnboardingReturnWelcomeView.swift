import SwiftUI

struct OnboardingReturnWelcomeView: View {
    let onStartNow: () -> Void

    @State private var bobOffset: CGFloat = 0

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                GooseCharacterView(mood: .happy)
                    .frame(height: 200)
                    .offset(y: bobOffset)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.4)
                            .repeatForever(autoreverses: true)
                        ) {
                            bobOffset = -10
                        }
                    }

                Spacer().frame(height: 32)

                Text("Take care of yourself,\ntake care of your Goose")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()

                OBButton(title: "Start Now", isEnabled: true, action: onStartNow)
                    .padding(.bottom, 36)
            }
        }
    }
}
