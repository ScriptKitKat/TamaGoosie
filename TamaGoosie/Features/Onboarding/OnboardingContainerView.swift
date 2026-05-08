import SwiftUI
import HealthKit
import UserNotifications

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

    // All logical steps: 0=signIn, 1=hatch, 2=name, 3=goals, 4=health, 5=notifications, 6=username, 7=complete
    // Returning user skips: 1 (hatch), 2 (name), 3 (goals), 6 (username)
    // Additionally skips health/notifications if already authorized on this device

    /// Steps that should be shown for the current user type
    private var visibleSteps: [Int] {
        if obState.isReturningUser {
            // Returning: sign-in(0), optionally health(4), optionally notifications(5), complete(7)
            var steps = [0]
            if !obState.healthAlreadyAuthorized { steps.append(4) }
            if !obState.notificationsAlreadyAuthorized { steps.append(5) }
            steps.append(7)
            return steps
        } else {
            // New user: all steps
            return [0, 1, 2, 3, 4, 5, 6, 7]
        }
    }

    /// Number of dots = visible steps minus sign-in screen
    private var totalDots: Int {
        max(visibleSteps.count - 1, 1)
    }

    /// Current dot index (step 0 has no dot)
    private var currentDotIndex: Int {
        guard let idx = visibleSteps.firstIndex(of: step) else { return 0 }
        return max(idx - 1, 0)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            OBTheme.cream.ignoresSafeArea()

            ZStack {
                if step == 0 {
                    OnboardingSignInView(obState: obState, onAdvance: { advance() }, onChooseEmail: { advance() })
                        .transition(forwardTransition)
                }
                if step == 1 {
                    OnboardingHatchView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }
                if step == 2 {
                    OnboardingNameView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }
                if step == 3 {
                    OnboardingGoalsView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }
                if step == 4 {
                    OnboardingHealthView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }
                if step == 5 {
                    OnboardingNotificationsView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }
                if step == 6 {
                    OnboardingUsernameView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }
                if step == 7 {
                    OnboardingCompleteView(obState: obState, onComplete: onComplete)
                        .transition(forwardTransition)
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: step)

            // Page indicator — hidden on sign-in screen
            if step > 0 {
                PageDots(current: currentDotIndex, total: totalDots)
                    .padding(.bottom, 20)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .task {
            await checkDevicePermissions()
        }
    }

    private var forwardTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance() {
        // Find the next visible step after the current one
        guard let currentIdx = visibleSteps.firstIndex(of: step) else {
            step = visibleSteps.last ?? 7
            return
        }
        let nextIdx = currentIdx + 1
        if nextIdx < visibleSteps.count {
            step = visibleSteps[nextIdx]
        }
    }

    /// Check if HealthKit and notifications are already authorized on this device
    private func checkDevicePermissions() async {
        // Check HealthKit
        if HKHealthStore.isHealthDataAvailable() {
            let store = HKHealthStore()
            if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
                let status = store.authorizationStatus(for: stepType)
                if status == .sharingAuthorized {
                    obState.healthAlreadyAuthorized = true
                    obState.healthAuthorized = true
                }
            }
        }

        // Check notifications
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .authorized {
            obState.notificationsAlreadyAuthorized = true
            obState.notificationsAuthorized = true
        }
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
