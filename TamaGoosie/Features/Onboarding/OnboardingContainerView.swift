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
    let entryPath: OnboardingEntryPath
    let onComplete: () -> Void

    @State private var step: Int = 0
    @State private var obState = OnboardingState()

    // Steps 0-12:
    //  0  = welcome (freshInstall) or returnWelcome (loggedOutReturn)
    //  1  = hatch
    //  2  = name
    //  3-6 = tutorial (4 screens)
    //  7  = signIn
    //  8  = createAccount (email)
    //  9  = username
    // 10  = notifications
    // 11  = health
    // 12  = complete

    // MARK: - Visible Steps

    private var visibleSteps: [Int] {
        switch obState.entryPath {
        case .freshInstall:
            var steps = [0, 1, 2, 3, 4, 5, 6, 7]
            if obState.choseEmailSignUp {
                steps.append(8)
            }
            if !obState.isReturningUser {
                steps.append(9)
            }
            // Permissions
            if !obState.notificationsAlreadyAuthorized { steps.append(10) }
            if !obState.healthAlreadyAuthorized { steps.append(11) }
            steps.append(12)
            return steps

        case .returningAccount:
            var steps = [7]
            if !obState.isReturningUser {
                if obState.choseEmailSignUp { steps.append(8) }
                steps.append(9)
            }
            if !obState.notificationsAlreadyAuthorized { steps.append(10) }
            if !obState.healthAlreadyAuthorized { steps.append(11) }
            steps.append(12)
            return steps

        case .loggedOutReturn:
            var steps = [0, 7]
            if !obState.isReturningUser {
                if obState.choseEmailSignUp { steps.append(8) }
                steps.append(9)
            }
            if !obState.notificationsAlreadyAuthorized { steps.append(10) }
            if !obState.healthAlreadyAuthorized { steps.append(11) }
            steps.append(12)
            return steps
        }
    }

    // MARK: - Section-Scoped Dots

    /// Tutorial section: steps 3-6 (4 dots)
    private var tutorialDotInfo: (index: Int, total: Int)? {
        let tutorialSteps = [3, 4, 5, 6]
        guard tutorialSteps.contains(step) else { return nil }
        let idx = step - 3
        return (index: idx, total: 4)
    }

    /// Permissions section: steps 10-11 (only visible ones)
    private var permissionsDotInfo: (index: Int, total: Int)? {
        let permSteps = visibleSteps.filter { $0 == 10 || $0 == 11 }
        guard permSteps.contains(step), permSteps.count > 1 else { return nil }
        guard let idx = permSteps.firstIndex(of: step) else { return nil }
        return (index: idx, total: permSteps.count)
    }

    /// Active dot info for the current step, if any
    private var activeDotInfo: (index: Int, total: Int)? {
        tutorialDotInfo ?? permissionsDotInfo
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            OBTheme.cream.ignoresSafeArea()

            ZStack {
                stepView
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: step)

            if let dots = activeDotInfo {
                PageDots(current: dots.index, total: dots.total)
                    .padding(.bottom, 20)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .task {
            obState.entryPath = entryPath
            // Set starting step based on entry path
            switch entryPath {
            case .freshInstall:
                step = 0
            case .returningAccount:
                step = 7
            case .loggedOutReturn:
                step = 0
            }
            await checkDevicePermissions()
        }
    }

    // MARK: - Step Router

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case 0:
            if obState.entryPath == .loggedOutReturn {
                OnboardingReturnWelcomeView(onStartNow: { advance() })
                    .transition(forwardTransition)
            } else {
                OnboardingWelcomeView(
                    obState: obState,
                    onGetStarted: { advance() },
                    onAlreadyHaveAccount: {
                        obState.entryPath = .returningAccount
                        step = 7
                    }
                )
                .transition(forwardTransition)
            }

        case 1:
            OnboardingHatchView(obState: obState, onAdvance: { advance() })
                .transition(forwardTransition)

        case 2:
            OnboardingNameView(obState: obState, onAdvance: { advance() })
                .transition(forwardTransition)

        case 3:
            OnboardingTutorialView(
                mood: .sad,
                title: "If you treat yourself badly, your goose will reflect that",
                buttonTitle: "I'll treat myself well",
                checkmarks: nil,
                onAdvance: { advance() }
            )
            .transition(forwardTransition)

        case 4:
            OnboardingTutorialView(
                mood: .happy,
                title: "Take care of yourself, and your goose will thrive",
                buttonTitle: "I will!",
                checkmarks: nil,
                onAdvance: { advance() }
            )
            .transition(forwardTransition)

        case 5:
            OnboardingTutorialView(
                mood: .ecstatic,
                title: "Every action adds up \u{2014} watch your goose grow",
                buttonTitle: "Let's grow!",
                checkmarks: nil,
                onAdvance: { advance() }
            )
            .transition(forwardTransition)

        case 6:
            OnboardingTutorialView(
                mood: .ecstatic,
                title: "Every goal is tracked.\nBuild habits, see progress.",
                buttonTitle: "Let's go!",
                checkmarks: ["Track your health", "Build daily habits", "Watch your goose thrive"],
                onAdvance: { advance() }
            )
            .transition(forwardTransition)

        case 7:
            OnboardingSignInView(
                obState: obState,
                onAdvance: { advance() },
                onChooseEmail: {
                    obState.choseEmailSignUp = true
                    advance()
                }
            )
            .transition(forwardTransition)

        case 8:
            OnboardingCreateAccountView(obState: obState, onAdvance: { advance() })
                .transition(forwardTransition)

        case 9:
            OnboardingUsernameView(obState: obState, onAdvance: { advance() })
                .transition(forwardTransition)

        case 10:
            OnboardingNotificationsView(obState: obState, onAdvance: { advance() })
                .transition(forwardTransition)

        case 11:
            OnboardingHealthView(obState: obState, onAdvance: { advance() })
                .transition(forwardTransition)

        case 12:
            OnboardingCompleteView(obState: obState, onComplete: onComplete)
                .transition(forwardTransition)

        default:
            EmptyView()
        }
    }

    // MARK: - Navigation

    private var forwardTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance() {
        guard let currentIdx = visibleSteps.firstIndex(of: step) else {
            step = visibleSteps.last ?? 12
            return
        }
        let nextIdx = currentIdx + 1
        if nextIdx < visibleSteps.count {
            step = visibleSteps[nextIdx]
        }
    }

    // MARK: - Permission Checks

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
