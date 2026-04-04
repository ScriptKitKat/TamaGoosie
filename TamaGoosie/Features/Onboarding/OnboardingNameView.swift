import SwiftUI

struct OnboardingNameView: View {
    let obState: OnboardingState
    let onAdvance: () -> Void

    @FocusState private var isFocused: Bool
    @State private var bobOffset: CGFloat = 0
    @State private var wiggle: Double = 0
    @State private var lastNameLength: Int = 0

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Duck
                GooseCharacterView(mood: .happy, phase: .baby)
                    .frame(height: 180)
                    .offset(y: bobOffset)
                    .rotationEffect(.degrees(wiggle))
                    .onAppear {
                        lastNameLength = obState.gooseName.count
                        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                            bobOffset = -10
                        }
                    }
                    .onChange(of: obState.gooseName) { _, newValue in
                        if newValue.count != lastNameLength {
                            lastNameLength = newValue.count
                            wiggleDuck()
                        }
                    }

                Spacer().frame(height: 32)

                // Label
                Text("What's your goose's name?")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 20)

                // Text field
                TextField("Harold", text: Binding(
                    get: { obState.gooseName },
                    set: { obState.gooseName = $0 }
                ))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(OBTheme.text)
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(OBTheme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isFocused ? OBTheme.teal : OBTheme.border, lineWidth: isFocused ? 2.5 : 1.5)
                        )
                )
                .padding(.horizontal, 40)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { isFocused = false }
                .animation(.easeInOut(duration: 0.2), value: isFocused)

                Spacer()
                Spacer()

                OBButton(
                    title: "Continue",
                    isEnabled: !obState.gooseName.trimmingCharacters(in: .whitespaces).isEmpty,
                    action: onAdvance
                )
                .padding(.bottom, 36)
            }
        }
        .onTapGesture { isFocused = false }
    }

    private func wiggleDuck() {
        withAnimation(.easeInOut(duration: 0.15)) { wiggle = 5 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.15)) { wiggle = -5 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { wiggle = 0 }
            }
        }
    }
}
