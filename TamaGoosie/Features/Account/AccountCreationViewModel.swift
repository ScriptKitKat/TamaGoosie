import Foundation
import Observation
import SwiftUI

@Observable
final class AccountCreationViewModel {
    var username = ""
    var gooseName: String?
    var validationError: String?
    var isAvailable = false
    var isChecking = false
    var isCreating = false
    var creationError: String?

    var canCreate: Bool {
        !username.isEmpty && isAvailable && validationError == nil && !isChecking && !isCreating
    }

    var borderColor: Color {
        if username.isEmpty { return GoosieTheme.charcoalOutline.opacity(0.15) }
        if validationError != nil { return GoosieTheme.coralAccent }
        if isAvailable { return GoosieTheme.mintBackground }
        return GoosieTheme.charcoalOutline.opacity(0.15)
    }

    private var debounceTask: Task<Void, Never>?

    // MARK: - Username Changed

    func onUsernameChanged(_ value: String) {
        debounceTask?.cancel()
        isAvailable = false
        creationError = nil

        let normalized = value.lowercased().trimmingCharacters(in: .whitespaces)

        // Local validation
        if normalized.isEmpty {
            validationError = nil
            return
        }
        if normalized.count < 3 {
            validationError = "Too short (min 3)"
            return
        }
        if normalized.count > 20 {
            validationError = "Too long (max 20)"
            return
        }
        if !normalized.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            validationError = "Only letters, numbers, underscores"
            return
        }
        if normalized.first?.isNumber == true {
            validationError = "Can't start with a number"
            return
        }

        validationError = nil
        isChecking = true

        // Debounced availability check
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            let available = await ConvexManager.shared.checkUsernameAvailable(normalized)
            guard !Task.isCancelled else { return }

            isChecking = false
            if available {
                isAvailable = true
            } else {
                validationError = "Username is taken"
            }
        }
    }

    // MARK: - Create Account

    @MainActor
    func createAccount() async -> Bool {
        isCreating = true
        defer { isCreating = false }

        do {
            try await ConvexManager.shared.createAccount(username: username, gooseName: gooseName)
            return true
        } catch {
            creationError = error.localizedDescription
            validationError = "Failed to create account. Try again."
            return false
        }
    }
}
