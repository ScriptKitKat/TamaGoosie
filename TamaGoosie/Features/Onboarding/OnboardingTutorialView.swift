import SwiftUI

struct OnboardingTutorialView: View {
    let mood: GooseMood
    let title: String
    let buttonTitle: String
    let checkmarks: [String]?
    let onAdvance: () -> Void

    @State private var bobOffset: CGFloat = 0

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                GooseCharacterView(mood: mood)
                    .frame(height: 220)
                    .offset(y: bobOffset)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.6)
                            .repeatForever(autoreverses: true)
                        ) {
                            bobOffset = -8
                        }
                    }

                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                    .padding(.top, 28)

                if let checkmarks {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(checkmarks, id: \.self) { item in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(OBTheme.teal)

                                Text(item)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(OBTheme.text)
                            }
                        }
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 40)
                }

                Spacer()

                OBButton(title: buttonTitle, isEnabled: true, action: onAdvance)
                    .padding(.bottom, 52)
            }
        }
    }
}
