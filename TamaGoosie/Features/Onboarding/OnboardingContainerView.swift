import SwiftUI

// MARK: - Shared Onboarding Color Palette (internal — visible to all onboarding files)

enum OBTheme {
    static let cream     = Color(hex: 0xFFF8F0)
    static let card      = Color(hex: 0xF5EFE6)
    static let border    = Color(hex: 0xE8E0D4)
    static let text      = Color(hex: 0x4A3728)
    static let secondary = Color(hex: 0xA09080)
    static let teal      = Color(hex: 0x7ECBC4)
    static let coral     = Color(hex: 0xF4A683)
    static let yellow    = Color(hex: 0xFFD97A)
}

// MARK: - Container

struct OnboardingContainerView: View {
    let onComplete: () -> Void

    @State private var step = 0
    @State private var obState = OnboardingState()

    private let totalDots = 5   // dots for steps 1-5 (step 0 = egg hatch, no dots)

    var body: some View {
        ZStack(alignment: .bottom) {
            OBTheme.cream.ignoresSafeArea()

            // Step content — each view manages its own layout
            ZStack {
                if step == 0 {
                    OnboardingHatchView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }
                if step == 1 {
                    OnboardingNameView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }
                if step == 2 {
                    OnboardingGoalsView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }
                if step == 3 {
                    OnboardingHealthView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }
                if step == 4 {
                    OnboardingNotificationsView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }
                if step == 5 {
                    OnboardingCompleteView(obState: obState, onComplete: onComplete)
                        .transition(forwardTransition)
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: step)

            // Custom page indicator — hidden on egg hatch screen
            if step > 0 {
                PageDots(current: step - 1, total: totalDots)
                    .padding(.bottom, 20)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var forwardTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance() {
        step = min(step + 1, 5)
    }
}

// MARK: - Page Dots

struct PageDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? OBTheme.teal : OBTheme.border)
                    .frame(width: i == current ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
            }
        }
    }
}

// MARK: - Shared Onboarding Button

struct OBButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(isEnabled ? OBTheme.teal : OBTheme.border)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

// MARK: - Shared Speech Bubble

struct OBSpeechBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(OBTheme.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(OBTheme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(OBTheme.border, lineWidth: 1.5)
                        )
                        .shadow(color: OBTheme.border.opacity(0.4), radius: 4, y: 2)
                )

            // Tail pointing down toward duck below
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 14))
                .foregroundStyle(OBTheme.card)
                .shadow(color: OBTheme.border.opacity(0.3), radius: 1, y: 1)
                .offset(y: -1)
        }
    }
}
