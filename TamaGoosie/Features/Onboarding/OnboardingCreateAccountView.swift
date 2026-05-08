import SwiftUI

struct OnboardingCreateAccountView: View {
    let obState: OnboardingState
    let onAdvance: () -> Void

    @FocusState private var focusedField: Field?
    @State private var showError = false
    @State private var errorMessage = ""

    private enum Field: Hashable {
        case email, password, confirmPassword
    }

    private var passwordMismatch: Bool {
        !obState.emailConfirmPassword.isEmpty
            && obState.emailConfirmPassword != obState.emailPassword
    }

    private var canContinue: Bool {
        !obState.emailAddress.isEmpty
            && obState.emailPassword.count >= 8
            && obState.emailPassword == obState.emailConfirmPassword
            && obState.agreedToTerms
    }

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("Create New Account")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)

                Spacer().frame(height: 24)

                // Form fields
                VStack(spacing: 14) {
                    formField(
                        placeholder: "Email",
                        text: Binding(
                            get: { obState.emailAddress },
                            set: { obState.emailAddress = $0 }
                        ),
                        field: .email,
                        isSecure: false
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                    formField(
                        placeholder: "Password",
                        text: Binding(
                            get: { obState.emailPassword },
                            set: { obState.emailPassword = $0 }
                        ),
                        field: .password,
                        isSecure: true
                    )

                    formField(
                        placeholder: "Confirm Password",
                        text: Binding(
                            get: { obState.emailConfirmPassword },
                            set: { obState.emailConfirmPassword = $0 }
                        ),
                        field: .confirmPassword,
                        isSecure: true
                    )

                    if passwordMismatch {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(OBTheme.coral)
                                .font(.system(size: 12))
                            Text("Passwords do not match")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(OBTheme.coral)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 20)

                // Terms checkbox
                Button {
                    obState.agreedToTerms.toggle()
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: obState.agreedToTerms
                              ? "checkmark.square.fill"
                              : "square")
                            .font(.system(size: 20))
                            .foregroundStyle(obState.agreedToTerms
                                             ? OBTheme.teal
                                             : OBTheme.secondary)

                        Text("I have read and agree to the Terms and Conditions and Privacy Policy.")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(OBTheme.text)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)

                Spacer()

                OBButton(title: "Continue", isEnabled: canContinue) {
                    obState.choseEmailSignUp = true
                    onAdvance()
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

    @ViewBuilder
    private func formField(
        placeholder: String,
        text: Binding<String>,
        field: Field,
        isSecure: Bool
    ) -> some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .font(.system(size: 16, weight: .regular, design: .rounded))
        .foregroundStyle(OBTheme.text)
        .focused($focusedField, equals: field)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(OBTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            focusedField == field ? OBTheme.teal : OBTheme.border,
                            lineWidth: focusedField == field ? 2.5 : 1.5
                        )
                )
        )
    }
}
