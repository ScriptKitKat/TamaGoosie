import SwiftUI

struct OnboardingUsernameView: View {
    let obState: OnboardingState
    let onAdvance: () -> Void

    @State private var viewModel = AccountCreationViewModel()
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Duck + speech bubble
                VStack(spacing: 0) {
                    OBSpeechBubble(text: "What should your friends call you?")
                        .padding(.horizontal, 36)

                    Spacer().frame(height: 8)

                    GooseCharacterView(mood: .happy)
                        .frame(height: 160)
                }

                Spacer().frame(height: 28)

                Text("Pick a username")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)

                Spacer().frame(height: 20)

                // Username input
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("@")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(OBTheme.secondary)
                        TextField("username", text: $viewModel.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(OBTheme.text)
                            .focused($isFocused)
                            .submitLabel(.done)
                            .onSubmit { isFocused = false }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(OBTheme.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(usernameBorderColor, lineWidth: isFocused ? 2.5 : 1.5)
                            )
                    )

                    // Validation feedback
                    if !viewModel.username.isEmpty {
                        HStack(spacing: 4) {
                            if viewModel.isChecking {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Checking...")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(OBTheme.secondary)
                            } else if let error = viewModel.validationError {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(OBTheme.coral)
                                    .font(.system(size: 12))
                                Text(error)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(OBTheme.coral)
                            } else if viewModel.isAvailable {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(OBTheme.teal)
                                    .font(.system(size: 12))
                                Text("Available!")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(OBTheme.teal)
                            }
                        }
                    }

                    Text("3-20 characters. Letters, numbers, underscores only.")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(OBTheme.secondary)
                }
                .padding(.horizontal, 40)

                Spacer()

                // Create button
                VStack(spacing: 12) {
                    OBButton(
                        title: viewModel.isCreating ? "Creating..." : "Continue",
                        isEnabled: viewModel.canCreate
                    ) {
                        Task {
                            viewModel.gooseName = obState.gooseName
                            let success = await viewModel.createAccount()
                            if success {
                                obState.username = viewModel.username
                                onAdvance()
                            }
                        }
                    }
                }
                .padding(.bottom, 36)
            }
        }
        .onTapGesture { isFocused = false }
        .onChange(of: viewModel.username) { _, newValue in
            viewModel.onUsernameChanged(newValue)
        }
    }

    private var usernameBorderColor: Color {
        if viewModel.username.isEmpty { return isFocused ? OBTheme.teal : OBTheme.border }
        if viewModel.validationError != nil { return OBTheme.coral }
        if viewModel.isAvailable { return OBTheme.teal }
        return OBTheme.border
    }
}
