import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct SignInView: View {
    @State private var authService = AuthService.shared
    @State private var showError = false
    @State private var errorMessage = ""
    var onSignedIn: () -> Void

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                GooseCharacterView(mood: .happy)
                    .scaleEffect(0.6)
                    .frame(height: 140)

                Text("Sign in to TamaGoosie")
                    .font(GoosieTheme.titleFont(26))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Text("Link your account to save progress and add friends")
                    .font(GoosieTheme.bodyFont(14))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 14) {
                    // Apple — native button (required by App Store review)
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        let success = authService.handleAppleAuthorization(result)
                        if success {
                            onSignedIn()
                        } else {
                            errorMessage = "Apple sign-in was cancelled or failed."
                            showError = true
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Google
                    Button {
                        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                              let root = windowScene.windows.first?.rootViewController else { return }
                        Task {
                            let success = await authService.handleGoogleSignIn(presenting: root)
                            if success {
                                onSignedIn()
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
                        .background(GoosieTheme.creamWhite)
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(GoosieTheme.charcoalOutline.opacity(0.15), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 60)
            }
            .padding(GoosieTheme.padding)
        }
        .alert("Sign In Failed", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
}
