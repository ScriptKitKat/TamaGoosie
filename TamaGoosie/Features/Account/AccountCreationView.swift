import SwiftUI

struct AccountCreationView: View {
    @State private var viewModel = AccountCreationViewModel()
    var onAccountCreated: () -> Void

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                GooseCharacterView(mood: .happy)
                    .scaleEffect(0.6)
                    .frame(height: 140)

                Text("Welcome to TamaGoosie!")
                    .font(GoosieTheme.titleFont(26))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Text("Choose a username to connect with friends")
                    .font(GoosieTheme.bodyFont(14))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                    .multilineTextAlignment(.center)

                // Username input
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "at")
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                        TextField("username", text: $viewModel.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(GoosieTheme.bodyFont())
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(GoosieTheme.creamWhite)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.borderColor, lineWidth: 2)
                    )

                    // Validation feedback
                    if !viewModel.username.isEmpty {
                        HStack(spacing: 4) {
                            if viewModel.isChecking {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Checking...")
                                    .font(GoosieTheme.captionFont(12))
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                            } else if let error = viewModel.validationError {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(GoosieTheme.coralAccent)
                                    .font(.system(size: 12))
                                Text(error)
                                    .font(GoosieTheme.captionFont(12))
                                    .foregroundStyle(GoosieTheme.coralAccent)
                            } else if viewModel.isAvailable {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(GoosieTheme.hygieneGreen)
                                    .font(.system(size: 12))
                                Text("Available!")
                                    .font(GoosieTheme.captionFont(12))
                                    .foregroundStyle(GoosieTheme.hygieneGreen)
                            }
                        }
                    }

                    Text("3–20 characters. Letters, numbers, underscores only.")
                        .font(GoosieTheme.captionFont(11))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                }
                .padding(.horizontal, GoosieTheme.padding)

                Spacer()

                // Create button
                PillButton(
                    title: viewModel.isCreating ? "Creating..." : "Create Account",
                    icon: "person.badge.plus",
                    color: viewModel.canCreate ? GoosieTheme.coralAccent : GoosieTheme.charcoalOutline.opacity(0.3)
                ) {
                    guard viewModel.canCreate else { return }
                    Task {
                        let success = await viewModel.createAccount()
                        if success {
                            onAccountCreated()
                        }
                    }
                }
                .disabled(!viewModel.canCreate || viewModel.isCreating)
                .padding(.bottom, 40)
            }
            .padding(GoosieTheme.padding)
        }
        .onChange(of: viewModel.username) { _, newValue in
            viewModel.onUsernameChanged(newValue)
        }
    }
}
