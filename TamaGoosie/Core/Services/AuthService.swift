import AuthenticationServices
import GoogleSignIn
import Observation

@Observable
final class AuthService {
    static let shared = AuthService()

    var isSignedIn: Bool = false
    var authProvider: String?      // "apple" | "google"
    var authUserID: String?        // Apple user identifier or Google user ID
    var displayName: String?
    var email: String?
    var avatarURL: String?         // Google provides this

    private init() {
        // Restore from Keychain
        authUserID = KeychainService.read(.authUserID)
        authProvider = KeychainService.read(.authProvider)
        isSignedIn = authUserID != nil

        // Verify credential still valid
        if let uid = authUserID, let provider = authProvider {
            verifyCredential(userID: uid, provider: provider)
        }
    }

    // MARK: - Apple Sign In

    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) -> Bool {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                return false
            }

            let uid = credential.user
            // Apple only sends name + email on FIRST sign-in ever.
            // Store immediately — you will never get them again.
            let fullName = [
                credential.fullName?.givenName,
                credential.fullName?.familyName,
            ].compactMap { $0 }.joined(separator: " ")
            let email = credential.email

            persistAuth(
                userID: uid,
                provider: "apple",
                displayName: fullName.isEmpty ? nil : fullName,
                email: email,
                avatarURL: nil
            )
            return true

        case .failure(let error):
            print("[AuthService] Apple sign-in failed: \(error)")
            return false
        }
    }

    // MARK: - Google Sign In

    func handleGoogleSignIn(presenting viewController: UIViewController) async -> Bool {
        await withCheckedContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { [weak self] result, error in
                guard let user = result?.user, error == nil else {
                    print("[AuthService] Google sign-in failed: \(error?.localizedDescription ?? "")")
                    continuation.resume(returning: false)
                    return
                }

                let uid = user.userID ?? ""
                let name = user.profile?.name
                let email = user.profile?.email
                let avatar = user.profile?.imageURL(withDimension: 200)?.absoluteString

                self?.persistAuth(
                    userID: uid,
                    provider: "google",
                    displayName: name,
                    email: email,
                    avatarURL: avatar
                )
                continuation.resume(returning: true)
            }
        }
    }

    /// Restore a previous Google session silently on app launch.
    func restoreGoogleSession() {
        guard authProvider == "google" else { return }
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if user == nil || error != nil {
                // Token expired — user must re-authenticate
                DispatchQueue.main.async { self.signOut() }
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        if authProvider == "google" {
            GIDSignIn.sharedInstance.signOut()
        }
        authUserID = nil
        authProvider = nil
        displayName = nil
        email = nil
        avatarURL = nil
        isSignedIn = false

        KeychainService.delete(.authUserID)
        KeychainService.delete(.authProvider)
    }

    // MARK: - Private

    private func persistAuth(
        userID: String,
        provider: String,
        displayName: String?,
        email: String?,
        avatarURL: String?
    ) {
        self.authUserID = userID
        self.authProvider = provider
        self.isSignedIn = true
        if let displayName { self.displayName = displayName }
        if let email { self.email = email }
        if let avatarURL { self.avatarURL = avatarURL }

        KeychainService.write(.authUserID, value: userID)
        KeychainService.write(.authProvider, value: provider)
    }

    private func verifyCredential(userID: String, provider: String) {
        if provider == "apple" {
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                DispatchQueue.main.async {
                    if state == .revoked || state == .notFound {
                        self.signOut()
                    }
                }
            }
        } else if provider == "google" {
            restoreGoogleSession()
        }
    }
}
