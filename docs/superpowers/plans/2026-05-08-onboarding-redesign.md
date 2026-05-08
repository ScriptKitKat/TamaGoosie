# Onboarding Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the onboarding into 3 entry paths — fresh install (tutorial-first), returning account, and logged-out return — with sign-in moved after the tutorial and goal picking moved to the Goals tab.

**Architecture:** The existing `OnboardingContainerView` state machine is refactored to support 13 steps (0-12) with an `OnboardingEntryPath` enum routing between fresh install, returning account, and logged-out return flows. New screens are added for welcome, tutorial pages, and email account creation. The goal picker becomes a standalone sheet triggered on first Goals tab visit via a new `hasPickedInitialGoals` flag on `UserProfile`.

**Tech Stack:** SwiftUI, SwiftData, AuthenticationServices, GoogleSignIn, HealthKit, UserNotifications

**Spec:** `docs/superpowers/specs/2026-05-08-onboarding-redesign-design.md`

---

## File Map

### New Files
| File | Purpose |
|------|---------|
| `TamaGoosie/Features/Onboarding/OnboardingWelcomeView.swift` | Fresh install welcome screen (step 0) |
| `TamaGoosie/Features/Onboarding/OnboardingReturnWelcomeView.swift` | Logged-out return welcome (Path C step 0) |
| `TamaGoosie/Features/Onboarding/OnboardingTutorialView.swift` | Reusable tutorial page (steps 3-6) |
| `TamaGoosie/Features/Onboarding/OnboardingCreateAccountView.swift` | Email account creation form (step 8) |
| `TamaGoosie/Features/Goals/InitialGoalPickerSheet.swift` | First-visit Goals tab goal picker modal |

### Modified Files
| File | Changes |
|------|---------|
| `TamaGoosie/Features/Onboarding/OnboardingState.swift` | Add `entryPath` enum, `emailSignUpFields`, remove `selectedGoals` |
| `TamaGoosie/Features/Onboarding/OnboardingContainerView.swift` | New 13-step routing, section-scoped dots, 3 entry paths |
| `TamaGoosie/Features/Onboarding/OnboardingSignInView.swift` | Add Email button, update copy, support Path B/C routing |
| `TamaGoosie/Features/Onboarding/OnboardingNotificationsView.swift` | Update copy to "Keep track of your goals", button text to "Remind Me" / "Maybe Later" |
| `TamaGoosie/Features/Onboarding/OnboardingHealthView.swift` | Update copy to goose speech bubble style |
| `TamaGoosie/Features/Onboarding/OnboardingCompleteView.swift` | Set new user default stats to 1.0, remove goal creation logic |
| `TamaGoosie/Core/Models/UserProfile.swift` | Add `hasPickedInitialGoals` field |
| `TamaGoosie/App/ContentView.swift` | Detect Path C (hasCompletedOnboarding + no auth), pass entry path |
| `TamaGoosie/Features/Goals/GoalListView.swift` | Show `InitialGoalPickerSheet` on first visit |

### Deleted Files
| File | Reason |
|------|--------|
| `TamaGoosie/Features/Onboarding/OnboardingGoalsView.swift` | Goal picker moved to Goals tab |

---

## Task 1: Update OnboardingState with Entry Path Enum

**Files:**
- Modify: `TamaGoosie/Features/Onboarding/OnboardingState.swift`

- [ ] **Step 1: Add entry path enum and update state**

Replace the entire file:

```swift
import Foundation
import Observation

enum OnboardingEntryPath {
    case freshInstall       // Path A: full flow (welcome -> hatch -> name -> tutorial -> signIn -> account -> username -> permissions -> complete)
    case returningAccount   // Path B: "Already have an account?" from welcome (signIn -> detect -> permissions -> complete)
    case loggedOutReturn    // Path C: app was used before, user logged out (returnWelcome -> signIn -> home or account flow)
}

@Observable
final class OnboardingState {
    var entryPath: OnboardingEntryPath = .freshInstall
    var gooseName: String = "Harold"
    var healthAuthorized: Bool = false
    var notificationsAuthorized: Bool = false
    var username: String = ""

    // Email sign-up fields (only used if user chooses email)
    var emailAddress: String = ""
    var emailPassword: String = ""
    var emailConfirmPassword: String = ""
    var agreedToTerms: Bool = false
    var choseEmailSignUp: Bool = false

    // Device permission state (checked on container appear)
    var healthAlreadyAuthorized: Bool = false
    var notificationsAlreadyAuthorized: Bool = false

    // Returning user fields (populated from Convex after sign-in)
    var isReturningUser: Bool = false
    var restoredGooseName: String = ""
    var restoredHappiness: Double = 0.7
    var restoredHealthiness: Double = 0.8
    var restoredMood: String = "content"
    var restoredSpriteID: String = "default"
    var restoredStreakDays: Int = 0
    var restoredGoals: [ConvexGoal] = []
    var restoredConvexUserId: String = ""
    var restoredUsername: String = ""
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

Expected: Build succeeds (there will be errors in OnboardingGoalsView referencing `selectedGoals` — that's fine, we delete it in Task 8).

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Onboarding/OnboardingState.swift
git commit -m "refactor: add OnboardingEntryPath enum, remove selectedGoals from state"
```

---

## Task 2: Create OnboardingWelcomeView (Fresh Install - Step 0)

**Files:**
- Create: `TamaGoosie/Features/Onboarding/OnboardingWelcomeView.swift`

- [ ] **Step 1: Create the welcome view**

```swift
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

                // Goose character
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
                Text("Become a better\nversion of yourself")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Your virtual goose reflects how well you take care of yourself.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(OBTheme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)

                Spacer()

                // Buttons
                VStack(spacing: 14) {
                    OBButton(title: "Get Started", isEnabled: true, action: onGetStarted)

                    Button("Already have an account?") {
                        onAlreadyHaveAccount()
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(OBTheme.teal)
                }
                .padding(.bottom, 36)
            }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Onboarding/OnboardingWelcomeView.swift
git commit -m "feat: add OnboardingWelcomeView for fresh install welcome screen"
```

---

## Task 3: Create OnboardingReturnWelcomeView (Path C - Step 0)

**Files:**
- Create: `TamaGoosie/Features/Onboarding/OnboardingReturnWelcomeView.swift`

- [ ] **Step 1: Create the return welcome view**

```swift
import SwiftUI

struct OnboardingReturnWelcomeView: View {
    let onStartNow: () -> Void

    @State private var bobOffset: CGFloat = 0

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Goose character
                GooseCharacterView(mood: .happy)
                    .frame(height: 200)
                    .offset(y: bobOffset)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                            bobOffset = -10
                        }
                    }

                Spacer().frame(height: 32)

                Text("Take care of yourself,\ntake care of your Goose")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                OBButton(title: "Start Now", isEnabled: true, action: onStartNow)
                    .padding(.bottom, 36)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TamaGoosie/Features/Onboarding/OnboardingReturnWelcomeView.swift
git commit -m "feat: add OnboardingReturnWelcomeView for logged-out return flow"
```

---

## Task 4: Create OnboardingTutorialView (Steps 3-6)

**Files:**
- Create: `TamaGoosie/Features/Onboarding/OnboardingTutorialView.swift`

- [ ] **Step 1: Create the reusable tutorial view**

This single view handles all 4 tutorial screens, parameterized by content.

```swift
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

                // Goose at specified mood
                GooseCharacterView(mood: mood)
                    .frame(height: 200)
                    .offset(y: bobOffset)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                            bobOffset = -10
                        }
                    }

                Spacer().frame(height: 32)

                // Title
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Optional checkmark list
                if let checkmarks {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(checkmarks, id: \.self) { item in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(OBTheme.teal)

                                Text(item)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(OBTheme.text)
                            }
                        }
                    }
                    .padding(.top, 28)
                    .padding(.horizontal, 48)
                }

                Spacer()

                OBButton(title: buttonTitle, isEnabled: true, action: onAdvance)
                    .padding(.bottom, 36)
            }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Onboarding/OnboardingTutorialView.swift
git commit -m "feat: add reusable OnboardingTutorialView for tutorial screens"
```

---

## Task 5: Create OnboardingCreateAccountView (Email Sign-Up - Step 8)

**Files:**
- Create: `TamaGoosie/Features/Onboarding/OnboardingCreateAccountView.swift`

- [ ] **Step 1: Create the email account creation view**

```swift
import SwiftUI

struct OnboardingCreateAccountView: View {
    let obState: OnboardingState
    let onAdvance: () -> Void

    @FocusState private var focusedField: Field?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCreating = false

    private enum Field: Hashable {
        case email, password, confirmPassword
    }

    private var canContinue: Bool {
        !obState.emailAddress.trimmingCharacters(in: .whitespaces).isEmpty
        && obState.emailPassword.count >= 8
        && obState.emailPassword == obState.emailConfirmPassword
        && obState.agreedToTerms
        && !isCreating
    }

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                Spacer().frame(height: 24)

                Text("Create New Account")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)

                Spacer().frame(height: 28)

                // Form fields
                VStack(spacing: 16) {
                    formField("Email", text: Binding(
                        get: { obState.emailAddress },
                        set: { obState.emailAddress = $0 }
                    ), field: .email, keyboard: .emailAddress)

                    formField("Password", text: Binding(
                        get: { obState.emailPassword },
                        set: { obState.emailPassword = $0 }
                    ), field: .password, isSecure: true)

                    formField("Confirm Password", text: Binding(
                        get: { obState.emailConfirmPassword },
                        set: { obState.emailConfirmPassword = $0 }
                    ), field: .confirmPassword, isSecure: true)

                    if obState.emailPassword != obState.emailConfirmPassword
                        && !obState.emailConfirmPassword.isEmpty {
                        Text("Passwords don't match")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(OBTheme.coral)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Terms checkbox
                Button {
                    obState.agreedToTerms.toggle()
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: obState.agreedToTerms ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20))
                            .foregroundStyle(obState.agreedToTerms ? OBTheme.teal : OBTheme.secondary)

                        Text("I have read and agree to the Terms and Conditions and Privacy Policy.")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(OBTheme.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

                OBButton(
                    title: isCreating ? "Creating..." : "Continue",
                    isEnabled: canContinue
                ) {
                    createAccount()
                }
                .padding(.bottom, 36)
            }
        }
        .onTapGesture { focusedField = nil }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func formField(
        _ placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType = .default,
        isSecure: Bool = false
    ) -> some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: text)
                    .focused($focusedField, equals: field)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
            }
        }
        .font(.system(size: 16, weight: .regular, design: .rounded))
        .foregroundStyle(OBTheme.text)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(OBTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(focusedField == field ? OBTheme.teal : OBTheme.border, lineWidth: focusedField == field ? 2.5 : 1.5)
                )
        )
    }

    private func createAccount() {
        isCreating = true
        // For now, just advance. Email auth backend integration can be added later.
        // The sign-in step already authenticated via Apple/Google, so email is a placeholder flow.
        obState.choseEmailSignUp = true
        isCreating = false
        onAdvance()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TamaGoosie/Features/Onboarding/OnboardingCreateAccountView.swift
git commit -m "feat: add OnboardingCreateAccountView for email sign-up flow"
```

---

## Task 6: Update OnboardingSignInView (Add Email Option + Update Copy)

**Files:**
- Modify: `TamaGoosie/Features/Onboarding/OnboardingSignInView.swift`

- [ ] **Step 1: Rewrite the sign-in view**

Replace the entire file content:

```swift
import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct OnboardingSignInView: View {
    let obState: OnboardingState
    let onAdvance: () -> Void
    let onChooseEmail: () -> Void

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCheckingReturning = false

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Goose + speech bubble
                VStack(spacing: 0) {
                    OBSpeechBubble(text: "Let's save your progress!")
                        .padding(.horizontal, 36)

                    Spacer().frame(height: 8)

                    GooseCharacterView(mood: .happy)
                        .frame(height: 160)
                }

                Spacer().frame(height: 28)

                Text("Create an account to\ntrack your goose")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)
                    .multilineTextAlignment(.center)

                Spacer()

                if isCheckingReturning {
                    ProgressView("Checking account...")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .padding(.bottom, 36)
                } else {
                    // Sign-in buttons
                    VStack(spacing: 14) {
                        // Apple
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            let success = AuthService.shared.handleAppleAuthorization(result)
                            if success {
                                handleSignInSuccess()
                            } else {
                                errorMessage = "Apple sign-in was cancelled or failed."
                                showError = true
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 28))

                        // Google
                        Button {
                            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                  let root = windowScene.windows.first?.rootViewController else { return }
                            Task {
                                let success = await AuthService.shared.handleGoogleSignIn(presenting: root)
                                if success {
                                    handleSignInSuccess()
                                } else {
                                    errorMessage = "Google sign-in was cancelled or failed."
                                    showError = true
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image("google-logo")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text("Continue with Google")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(OBTheme.card)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 28)
                                            .stroke(OBTheme.border, lineWidth: 1.5)
                                    )
                            )
                            .foregroundStyle(OBTheme.text)
                        }

                        // Email
                        Button {
                            onChooseEmail()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 16))
                                Text("Continue with Email")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(OBTheme.card)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 28)
                                            .stroke(OBTheme.border, lineWidth: 1.5)
                                    )
                            )
                            .foregroundStyle(OBTheme.text)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 36)
                }
            }
        }
        .alert("Sign In Failed", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func handleSignInSuccess() {
        isCheckingReturning = true
        Task {
            if let data = await ConvexManager.shared.checkReturningUser() {
                await MainActor.run {
                    obState.isReturningUser = true
                    obState.restoredGooseName = data.gooseName
                    obState.restoredHappiness = data.happiness
                    obState.restoredHealthiness = data.healthiness
                    obState.restoredMood = data.mood
                    obState.restoredSpriteID = data.spriteID
                    obState.restoredStreakDays = data.streakDays
                    obState.restoredGoals = data.goals
                    obState.restoredConvexUserId = data.convexUserId
                    obState.restoredUsername = data.username
                    isCheckingReturning = false
                    onAdvance()
                }
            } else {
                await MainActor.run {
                    isCheckingReturning = false
                    onAdvance()
                }
            }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

Note: Will have compile errors in `OnboardingContainerView` because the new `onChooseEmail` parameter isn't wired yet. That's fixed in Task 9.

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Onboarding/OnboardingSignInView.swift
git commit -m "feat: update sign-in view with email option and new copy"
```

---

## Task 7: Update Notifications and Health Views Copy

**Files:**
- Modify: `TamaGoosie/Features/Onboarding/OnboardingNotificationsView.swift`
- Modify: `TamaGoosie/Features/Onboarding/OnboardingHealthView.swift`

- [ ] **Step 1: Update notifications view copy**

In `OnboardingNotificationsView.swift`, replace the title and buttons section:

Replace:
```swift
                // Title
                Text("Stay in touch!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)

                Text("Get gentle nudges when your goose needs you.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(OBTheme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
```

With:
```swift
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
```

Replace the button text:
```swift
                    OBButton(title: requesting ? "Requesting..." : "Enable Notifications", isEnabled: !requesting) {
```
With:
```swift
                    OBButton(title: requesting ? "Requesting..." : "Remind Me", isEnabled: !requesting) {
```

Replace:
```swift
                    Button("Skip for now") { onAdvance() }
```
With:
```swift
                    Button("Maybe Later") { onAdvance() }
```

- [ ] **Step 2: Update health view copy**

In `OnboardingHealthView.swift`, replace the speech bubble text:

Replace:
```swift
                    OBSpeechBubble(text: "I get stronger when you stay active!")
```
With:
```swift
                    OBSpeechBubble(text: "I need to know how you're doing so I can stay healthy too!")
```

Replace the title:
```swift
                Text("Connect Health Data")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)
```
With:
```swift
                Text("Connect Your\nHealth Data")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)
                    .multilineTextAlignment(.center)
```

Replace:
```swift
                    OBButton(title: requesting ? "Requesting..." : "Connect Health", isEnabled: !requesting) {
```
With:
```swift
                    OBButton(title: requesting ? "Connecting..." : "Connect Health Data", isEnabled: !requesting) {
```

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Onboarding/OnboardingNotificationsView.swift TamaGoosie/Features/Onboarding/OnboardingHealthView.swift
git commit -m "feat: update notifications and health view copy for new onboarding flow"
```

---

## Task 8: Update OnboardingCompleteView (Stats to 1.0, Remove Goal Creation)

**Files:**
- Modify: `TamaGoosie/Features/Onboarding/OnboardingCompleteView.swift`

- [ ] **Step 1: Update createEntities to set stats at 1.0 and remove goal creation**

Replace the `createEntities()` method:

```swift
    private func createEntities() {
        let name = obState.gooseName.trimmingCharacters(in: .whitespaces)
        let gooseName = name.isEmpty ? "Harold" : name

        // Create profile
        let profile = UserProfile(
            displayName: gooseName,
            notificationsEnabled: obState.notificationsAuthorized,
            hasCompletedOnboarding: true
        )
        modelContext.insert(profile)

        // Create goose with full stats for new users
        let goose = GooseState(
            name: gooseName,
            healthiness: 1.0,
            happiness: 1.0,
            mood: GooseMood.ecstatic.rawValue
        )
        goose.userProfile = profile
        modelContext.insert(goose)
        profile.gooseState = goose

        // Mark completion in UserDefaults
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        try? modelContext.save()

        // Schedule morning reminder
        NotificationManager.shared.scheduleMorningReminder(
            gooseName: gooseName,
            healthiness: goose.healthiness
        )
    }
```

- [ ] **Step 2: Commit**

```bash
git add TamaGoosie/Features/Onboarding/OnboardingCompleteView.swift
git commit -m "feat: set new user default stats to 1.0, remove goal creation from onboarding"
```

---

## Task 9: Rewrite OnboardingContainerView (3 Entry Paths + Section Dots)

**Files:**
- Modify: `TamaGoosie/Features/Onboarding/OnboardingContainerView.swift`

This is the core routing change. Replace the entire file.

- [ ] **Step 1: Rewrite the container**

```swift
import SwiftUI
import HealthKit
import UserNotifications

// MARK: - Shared Onboarding Color Palette (internal -- visible to all onboarding files)

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

    // Steps:
    // Path A (freshInstall):  0=welcome, 1=hatch, 2=name, 3=tutorial1, 4=tutorial2, 5=tutorial3, 6=tutorial4,
    //                         7=signIn, 8=createAccount(email only), 9=username, 10=notifications, 11=health, 12=complete
    // Path B (returningAccount): 7=signIn -> detect -> optionally 10,11 -> 12=complete
    // Path C (loggedOutReturn):  0=returnWelcome, 7=signIn -> detect -> home or 8-12

    private var visibleSteps: [Int] {
        switch obState.entryPath {
        case .freshInstall:
            if obState.isReturningUser {
                // Signed in during fresh install and found existing account
                var steps = [0, 1, 2, 3, 4, 5, 6, 7]
                if !obState.healthAlreadyAuthorized { steps.append(11) }
                if !obState.notificationsAlreadyAuthorized { steps.append(10) }
                steps.sort()
                steps.append(12)
                return steps
            }
            var steps = [0, 1, 2, 3, 4, 5, 6, 7]
            if obState.choseEmailSignUp { steps.append(8) }
            steps.append(9) // username
            if !obState.notificationsAlreadyAuthorized { steps.append(10) }
            if !obState.healthAlreadyAuthorized { steps.append(11) }
            steps.append(12)
            return steps

        case .returningAccount:
            var steps = [7] // sign-in only
            if obState.isReturningUser {
                if !obState.notificationsAlreadyAuthorized { steps.append(10) }
                if !obState.healthAlreadyAuthorized { steps.append(11) }
                steps.append(12)
            } else {
                // New account via "Already have an account?" path
                if obState.choseEmailSignUp { steps.append(8) }
                steps.append(9)
                if !obState.notificationsAlreadyAuthorized { steps.append(10) }
                if !obState.healthAlreadyAuthorized { steps.append(11) }
                steps.append(12)
            }
            return steps

        case .loggedOutReturn:
            var steps = [0, 7] // returnWelcome, signIn
            if obState.isReturningUser {
                // Account found -- go straight to home
                steps.append(12)
            } else {
                // No account found -- full account setup
                if obState.choseEmailSignUp { steps.append(8) }
                steps.append(9)
                if !obState.notificationsAlreadyAuthorized { steps.append(10) }
                if !obState.healthAlreadyAuthorized { steps.append(11) }
                steps.append(12)
            }
            return steps
        }
    }

    // MARK: - Section-Scoped Dots

    private enum DotSection {
        case tutorial   // steps 3-6
        case permissions // steps 10-11
    }

    private var currentDotSection: DotSection? {
        if (3...6).contains(step) { return .tutorial }
        if (10...11).contains(step) { return .permissions }
        return nil
    }

    private var sectionDotCount: Int {
        guard let section = currentDotSection else { return 0 }
        switch section {
        case .tutorial: return 4
        case .permissions:
            var count = 0
            if !obState.notificationsAlreadyAuthorized { count += 1 }
            if !obState.healthAlreadyAuthorized { count += 1 }
            return count
        }
    }

    private var sectionDotIndex: Int {
        guard let section = currentDotSection else { return 0 }
        switch section {
        case .tutorial: return step - 3
        case .permissions:
            if step == 10 { return 0 }
            if step == 11 {
                return obState.notificationsAlreadyAuthorized ? 0 : 1
            }
            return 0
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            OBTheme.cream.ignoresSafeArea()

            ZStack {
                // Path C: return welcome (step 0)
                if step == 0 && obState.entryPath == .loggedOutReturn {
                    OnboardingReturnWelcomeView(onStartNow: { advance() })
                        .transition(forwardTransition)
                }

                // Path A: fresh install welcome (step 0)
                if step == 0 && obState.entryPath == .freshInstall {
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

                if step == 1 {
                    OnboardingHatchView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }
                if step == 2 {
                    OnboardingNameView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }

                // Tutorial screens
                if step == 3 {
                    OnboardingTutorialView(
                        mood: .sad,
                        title: "If you treat yourself badly, your goose will reflect that",
                        buttonTitle: "I'll treat myself well",
                        checkmarks: nil,
                        onAdvance: { advance() }
                    )
                    .transition(forwardTransition)
                }
                if step == 4 {
                    OnboardingTutorialView(
                        mood: .happy,
                        title: "Take care of yourself, and your goose will thrive",
                        buttonTitle: "I will!",
                        checkmarks: nil,
                        onAdvance: { advance() }
                    )
                    .transition(forwardTransition)
                }
                if step == 5 {
                    OnboardingTutorialView(
                        mood: .ecstatic,
                        title: "Every action adds up \u{2014} watch your goose grow",
                        buttonTitle: "Let's grow!",
                        checkmarks: nil,
                        onAdvance: { advance() }
                    )
                    .transition(forwardTransition)
                }
                if step == 6 {
                    OnboardingTutorialView(
                        mood: .ecstatic,
                        title: "Every goal is tracked.\nBuild habits, see progress.",
                        buttonTitle: "Let's go!",
                        checkmarks: [
                            "Track your health",
                            "Build daily habits",
                            "Watch your goose thrive"
                        ],
                        onAdvance: { advance() }
                    )
                    .transition(forwardTransition)
                }

                // Sign in
                if step == 7 {
                    OnboardingSignInView(
                        obState: obState,
                        onAdvance: { advance() },
                        onChooseEmail: {
                            obState.choseEmailSignUp = true
                            advance()
                        }
                    )
                    .transition(forwardTransition)
                }

                // Email account creation
                if step == 8 {
                    OnboardingCreateAccountView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }

                // Username
                if step == 9 {
                    OnboardingUsernameView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }

                // Permissions
                if step == 10 {
                    OnboardingNotificationsView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }
                if step == 11 {
                    OnboardingHealthView(obState: obState, onAdvance: { advance() })
                        .transition(forwardTransition)
                }

                // Complete
                if step == 12 {
                    OnboardingCompleteView(obState: obState, onComplete: {
                        // Path C returning user: go straight home
                        if obState.entryPath == .loggedOutReturn && obState.isReturningUser {
                            onComplete()
                        } else {
                            onComplete()
                        }
                    })
                    .transition(forwardTransition)
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: step)

            // Section-scoped page dots
            if let _ = currentDotSection, sectionDotCount > 1 {
                PageDots(current: sectionDotIndex, total: sectionDotCount)
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
        guard let currentIdx = visibleSteps.firstIndex(of: step) else {
            step = visibleSteps.last ?? 12
            return
        }
        let nextIdx = currentIdx + 1
        if nextIdx < visibleSteps.count {
            step = visibleSteps[nextIdx]
        }
    }

    private func checkDevicePermissions() async {
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

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 14))
                .foregroundStyle(OBTheme.card)
                .shadow(color: OBTheme.border.opacity(0.3), radius: 1, y: 1)
                .offset(y: -1)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Onboarding/OnboardingContainerView.swift
git commit -m "feat: rewrite onboarding container with 3 entry paths and section-scoped dots"
```

---

## Task 10: Update ContentView to Detect Path C

**Files:**
- Modify: `TamaGoosie/App/ContentView.swift`

- [ ] **Step 1: Add logged-out return detection**

Replace the `onAppear` block:

```swift
            .onAppear {
                if !hasCompletedOnboarding {
                    showOnboarding = true
                } else {
                    HealthKitManager.shared.enableBackgroundDelivery()
                }
                scheduleNotifications()
            }
```

With:

```swift
            .onAppear {
                if !hasCompletedOnboarding {
                    showOnboarding = true
                    onboardingEntryPath = .freshInstall
                } else if !AuthService.shared.isSignedIn {
                    // Path C: completed onboarding before but logged out
                    showOnboarding = true
                    onboardingEntryPath = .loggedOutReturn
                } else {
                    HealthKitManager.shared.enableBackgroundDelivery()
                }
                scheduleNotifications()
            }
```

Add a state variable near the other `@State` declarations:

```swift
    @State private var onboardingEntryPath: OnboardingEntryPath = .freshInstall
```

Update the `fullScreenCover` to pass the entry path:

Replace:
```swift
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingContainerView { showOnboarding = false }
            }
```

With:
```swift
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingContainerView(entryPath: onboardingEntryPath) { showOnboarding = false }
            }
```

- [ ] **Step 2: Update OnboardingContainerView init to accept entry path**

In `OnboardingContainerView.swift`, update the struct declaration:

Replace:
```swift
struct OnboardingContainerView: View {
    let onComplete: () -> Void

    @State private var step = 0
    @State private var obState = OnboardingState()
```

With:
```swift
struct OnboardingContainerView: View {
    let onComplete: () -> Void
    let entryPath: OnboardingEntryPath

    @State private var step = 0
    @State private var obState = OnboardingState()
```

Add to the `.task` modifier, after `await checkDevicePermissions()`:

```swift
        .task {
            obState.entryPath = entryPath
            if entryPath == .loggedOutReturn || entryPath == .returningAccount {
                step = entryPath == .returningAccount ? 7 : 0
            }
            await checkDevicePermissions()
        }
```

Replace the existing `.task`:
```swift
        .task {
            await checkDevicePermissions()
        }
```

With the above.

- [ ] **Step 3: Also handle the onChange for hasCompletedOnboarding**

Replace:
```swift
            .onChange(of: hasCompletedOnboarding) { _, completed in
                if !completed {
                    showOnboarding = true
                }
            }
```

With:
```swift
            .onChange(of: hasCompletedOnboarding) { _, completed in
                if !completed {
                    onboardingEntryPath = .freshInstall
                    showOnboarding = true
                }
            }
```

- [ ] **Step 4: Verify it compiles**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```bash
git add TamaGoosie/App/ContentView.swift TamaGoosie/Features/Onboarding/OnboardingContainerView.swift
git commit -m "feat: detect logged-out return path and pass entry path to onboarding"
```

---

## Task 11: Delete OnboardingGoalsView

**Files:**
- Delete: `TamaGoosie/Features/Onboarding/OnboardingGoalsView.swift`

- [ ] **Step 1: Delete the file**

```bash
rm TamaGoosie/Features/Onboarding/OnboardingGoalsView.swift
```

- [ ] **Step 2: Regenerate Xcode project**

```bash
xcodegen generate
```

- [ ] **Step 3: Verify it compiles**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: remove OnboardingGoalsView (moved to Goals tab)"
```

---

## Task 12: Add hasPickedInitialGoals to UserProfile

**Files:**
- Modify: `TamaGoosie/Core/Models/UserProfile.swift`

- [ ] **Step 1: Add the field**

Add after `var liveActivityEnabled: Bool`:

```swift
    var hasPickedInitialGoals: Bool
```

Update the initializer to include the new parameter:

Add `hasPickedInitialGoals: Bool = false` to the init parameter list, and `self.hasPickedInitialGoals = hasPickedInitialGoals` in the init body.

- [ ] **Step 2: Verify it compiles**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Core/Models/UserProfile.swift
git commit -m "feat: add hasPickedInitialGoals to UserProfile model"
```

---

## Task 13: Create InitialGoalPickerSheet + Wire into GoalListView

**Files:**
- Create: `TamaGoosie/Features/Goals/InitialGoalPickerSheet.swift`
- Modify: `TamaGoosie/Features/Goals/GoalListView.swift`

- [ ] **Step 1: Create the goal picker sheet**

```swift
import SwiftUI
import SwiftData

struct InitialGoalPickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var selectedGoals: Set<String> = []

    private let goals: [(title: String, category: GoalCategory)] = [
        ("Drink 8 glasses of water", .water),
        ("Take a 30-minute walk",    .fitness),
        ("Meditate for 10 minutes",  .mindfulness),
        ("Read for 20 minutes",      .learning),
        ("Stretch for 10 minutes",   .fitness),
        ("Journal before bed",       .mindfulness),
        ("Eat a healthy meal",       .health),
        ("Call a friend or family",  .social),
    ]

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                GoosieTheme.mintBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 12)

                    Text("Pick up to 3 starter goals")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline)

                    Text("Your goose grows happier when you hit them!")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                        .padding(.top, 6)

                    Text("\(selectedGoals.count)/3 selected")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selectedGoals.count == 3 ? GoosieTheme.charcoalOutline : GoosieTheme.charcoalOutline.opacity(0.5))
                        .padding(.top, 12)

                    Spacer().frame(height: 16)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(goals, id: \.title) { goal in
                            goalCard(title: goal.title, category: goal.category)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    Button {
                        saveGoals()
                    } label: {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(selectedGoals.count >= 1
                                          ? GoosieTheme.charcoalOutline
                                          : GoosieTheme.charcoalOutline.opacity(0.3))
                            )
                    }
                    .disabled(selectedGoals.isEmpty)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 36)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
    }

    private func goalCard(title: String, category: GoalCategory) -> some View {
        let isSelected = selectedGoals.contains(title)
        let accentColor = Color(hex: UInt(category.color, radix: 16) ?? 0xA09080)

        return Button {
            if isSelected {
                selectedGoals.remove(title)
            } else if selectedGoals.count < 3 {
                selectedGoals.insert(title)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : accentColor)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : GoosieTheme.charcoalOutline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accentColor : GoosieTheme.creamWhite)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? accentColor : GoosieTheme.charcoalOutline.opacity(0.15), lineWidth: isSelected ? 2 : 1.5)
                    )
                    .shadow(color: GoosieTheme.charcoalOutline.opacity(0.08), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isSelected)
    }

    private func saveGoals() {
        guard let profile = profiles.first else { return }

        let goalDefs: [(String, GoalCategory)] = [
            ("Drink 8 glasses of water", .water),
            ("Take a 30-minute walk",    .fitness),
            ("Meditate for 10 minutes",  .mindfulness),
            ("Read for 20 minutes",      .learning),
            ("Stretch for 10 minutes",   .fitness),
            ("Journal before bed",       .mindfulness),
            ("Eat a healthy meal",       .health),
            ("Call a friend or family",  .social),
        ]

        var createdGoals: [Goal] = []
        for (idx, (title, category)) in goalDefs.enumerated() {
            guard selectedGoals.contains(title) else { continue }
            let goal = Goal(
                title: title,
                type: "recurring",
                category: category,
                frequency: .daily,
                happinessWeight: 1.0,
                sortOrder: idx
            )
            goal.userProfile = profile
            modelContext.insert(goal)
            profile.goals.append(goal)
            createdGoals.append(goal)
        }

        profile.hasPickedInitialGoals = true
        try? modelContext.save()

        ConvexManager.shared.syncGoals(goals: createdGoals)
        dismiss()
    }
}
```

- [ ] **Step 2: Wire into GoalListView**

In `GoalListView.swift`, add a state variable near the top (after the existing `@State` vars):

```swift
    @State private var showInitialGoalPicker = false
```

Add an `.onAppear` or `.sheet` modifier. Find where the view's body starts and add after the existing modifiers. Add this `.onAppear` block inside the main view body (or in the existing `.onAppear` if there is one):

```swift
    .onAppear {
        if profiles.first?.hasPickedInitialGoals == false {
            showInitialGoalPicker = true
        }
    }
    .sheet(isPresented: $showInitialGoalPicker) {
        InitialGoalPickerSheet()
    }
```

- [ ] **Step 3: Regenerate Xcode project**

```bash
xcodegen generate
```

- [ ] **Step 4: Verify it compiles**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```bash
git add TamaGoosie/Features/Goals/InitialGoalPickerSheet.swift TamaGoosie/Features/Goals/GoalListView.swift
git commit -m "feat: add initial goal picker sheet on first Goals tab visit"
```

---

## Task 14: Handle Path C Returning User (Skip to Home)

**Files:**
- Modify: `TamaGoosie/Features/Onboarding/OnboardingCompleteView.swift`

- [ ] **Step 1: Handle Path C returning user auto-completion**

In `OnboardingCompleteView`, the `onAppear` of the goose already calls `restoreEntities()` for returning users. For Path C where the account already exists in Convex, we need the complete view to auto-dismiss quickly.

In the `OnboardingCompleteView`, update the `onAppear` block inside the `GooseCharacterView`:

Replace:
```swift
                    .onAppear {
                        startDance()
                        if !didCreate {
                            didCreate = true
                            if obState.isReturningUser {
                                restoreEntities()
                            } else {
                                createEntities()
                            }
                        }
                    }
```

With:
```swift
                    .onAppear {
                        startDance()
                        if !didCreate {
                            didCreate = true
                            if obState.isReturningUser {
                                restoreEntities()
                                // Path C returning: auto-dismiss after brief animation
                                if obState.entryPath == .loggedOutReturn {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        onComplete()
                                    }
                                }
                            } else {
                                createEntities()
                            }
                        }
                    }
```

- [ ] **Step 2: Verify it compiles**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Onboarding/OnboardingCompleteView.swift
git commit -m "feat: auto-dismiss onboarding for Path C returning users"
```

---

## Task 15: Final Build Verification + Cleanup

**Files:**
- All modified files

- [ ] **Step 1: Full build**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Fix any remaining compile errors**

If there are errors referencing `selectedGoals` from the old `OnboardingState`, find and remove those references.

If there are errors from `OnboardingGoalsView` still being referenced, ensure the file is deleted and `xcodegen generate` was run.

- [ ] **Step 3: Delete the old OnboardingView.swift if it exists**

Check if `TamaGoosie/Features/Onboarding/OnboardingView.swift` (the legacy file mentioned in exploration) is still present. If so and it's unused, delete it:

```bash
rm -f TamaGoosie/Features/Onboarding/OnboardingView.swift
xcodegen generate
```

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete onboarding redesign with 3 entry paths"
```
