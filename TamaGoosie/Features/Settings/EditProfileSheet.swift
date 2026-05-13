import SwiftUI
import SwiftData

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var gooseStates: [GooseState]
    @Query private var profiles: [UserProfile]

    @State private var editedName: String = ""

    private var gooseState: GooseState? { gooseStates.first }
    private var profile: UserProfile? { profiles.first }

    private let accentGreen = Color(hex: 0x4CAF50)
    private let lightGreen = Color(hex: 0x81C784)

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            LinearGradient(
                colors: [Color(hex: 0xC8E6C9).opacity(0.4), Color(hex: 0xF5F5F0)],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Title pill
                    Text("Edit Profile")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(accentGreen))
                        .padding(.top, 20)

                    // Goose avatar
                    profileAvatar
                        .padding(.top, 24)

                    // Name field
                    nameSection
                        .padding(.top, 24)

                    // Account info
                    if let username = ConvexManager.shared.currentUsername {
                        accountSection(username: username)
                            .padding(.top, 16)
                    }

                    // App info
                    appInfoSection
                        .padding(.top, 16)

                    Spacer(minLength: 100)
                }
            }

            // Bottom bar with Save button
            Button {
                saveName()
                dismiss()
            } label: {
                Text("Save")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(.white)
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 16)
            .background(
                LinearGradient(
                    colors: [accentGreen, lightGreen],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 90)
                .ignoresSafeArea(edges: .bottom)
            )
        }
        .onAppear {
            editedName = gooseState?.name ?? "Harold"
        }
    }

    // MARK: - Avatar

    private var profileAvatar: some View {
        VStack(spacing: 12) {
            ZStack {
                // Gold ring
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(hex: 0xFFD54F), Color(hex: 0xFFA726), Color(hex: 0xFFD54F)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 110, height: 110)

                // Inner circle
                Circle()
                    .fill(Color(hex: 0xF5F5F0))
                    .frame(width: 100, height: 100)

                // Goose
                GooseCharacterView(
                    mood: gooseState.map {
                        GooseMood.deriveMood(healthiness: $0.healthiness, happiness: $0.happiness)
                    } ?? .content
                )
                .frame(width: 80, height: 80)
                .clipShape(Circle())

                // Score badge
                if let state = gooseState {
                    Text("\(Int((state.healthiness + state.happiness) / 2.0 * 100))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color(hex: 0x42A5F5)))
                        .offset(x: -38, y: 38)
                }
            }
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Goose Name")

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image("goose_icon")
                        .resizable()
                        .frame(width: 20, height: 20)

                    TextField("Name your goose", text: $editedName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline)

                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.3))
                }
            }
            .padding(16)
            .background(whiteCard)
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)
        }
    }

    // MARK: - Account Section

    private func accountSection(username: String) -> some View {
        VStack(spacing: 0) {
            sectionHeader("Account")

            VStack(spacing: 0) {
                infoRow(icon: "person.fill", label: "Username", value: "@\(username)")

                Divider().padding(.leading, 52)

                if let provider = AuthService.shared.authProvider {
                    infoRow(
                        icon: provider == "apple" ? "apple.logo" : "globe",
                        label: "Signed in with",
                        value: provider == "apple" ? "Apple" : "Google"
                    )
                }
            }
            .padding(16)
            .background(whiteCard)
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)
        }
    }

    // MARK: - App Info

    private var appInfoSection: some View {
        VStack(spacing: 0) {
            sectionHeader("About")

            VStack(spacing: 0) {
                infoRow(icon: "info.circle.fill", label: "App", value: "TamaGoosie")

                Divider().padding(.leading, 52)

                infoRow(icon: "tag.fill", label: "Version", value: "1.0")

                if let state = gooseState {
                    Divider().padding(.leading, 52)

                    infoRow(
                        icon: "calendar",
                        label: "Joined",
                        value: state.createdAt.formatted(.dateTime.month(.abbreviated).day().year())
                    )

                    Divider().padding(.leading, 52)

                    infoRow(icon: "flame.fill", label: "Longest Streak", value: "\(state.longestStreak) days")
                }
            }
            .padding(16)
            .background(whiteCard)
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentGreen)
                .frame(width: 4, height: 20)
                .padding(.trailing, 10)

            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, GoosieTheme.padding)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x66BB6A), accentGreen],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(accentGreen)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)
        }
        .padding(.vertical, 6)
    }

    private var whiteCard: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.white)
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }

    private func saveName() {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        gooseState?.name = trimmed
    }
}
