import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct OnboardingSignInView: View {
    let obState: OnboardingState
    let onAdvance: () -> Void

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCheckingReturning = false

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Duck + speech bubble
                VStack(spacing: 0) {
                    OBSpeechBubble(text: "Let's get you set up!")
                        .padding(.horizontal, 36)

                    Spacer().frame(height: 8)

                    GooseCharacterView(mood: .happy)
                        .frame(height: 160)
                }

                Spacer().frame(height: 28)

                Text("Sign in to TamaGoosie")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)

                Text("Link your account to save progress and add friends")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(OBTheme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)

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
                                Text("Sign in with Google")
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
