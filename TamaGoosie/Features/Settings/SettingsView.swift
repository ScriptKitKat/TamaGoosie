import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gooseStates: [GooseState]
    @Query private var profiles: [UserProfile]

    @AppStorage("chatProvider") private var chatProvider: String = "apple"
    @AppStorage("geminiAPIKey") private var geminiAPIKey: String = ""
    @State private var geminiAPIKeyInput: String = ""
    @State private var showGeminiKey: Bool = false

    @State private var morningReminderEnabled = true
    @State private var morningReminderHour = 8
    @State private var morningReminderMinute = 0
    @State private var morningReminderTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0))!
    @State private var decayWarningsEnabled = true
    @State private var goalRemindersEnabled = true
    @State private var showResetConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showEditProfile = false

    private var gooseState: GooseState? { gooseStates.first }
    private var profile: UserProfile? { profiles.first }

    private let pokGreen = Color(hex: 0x4CAF50)
    private let pokLightGreen = Color(hex: 0x81C784)
    private let pokBg = Color(hex: 0xF5F5F0)

    var body: some View {
        ZStack {
            pokBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Profile header card
                    profileHeader
                        .padding(.horizontal, GoosieTheme.padding)

                    // Records section
                    recordsSection
                        .padding(.top, 20)

                    // Settings section
                    settingsSection
                        .padding(.top, 20)

                    // Danger section
                    dangerSection
                        .padding(.top, 20)
                }
                .padding(.top, 52)
                .padding(.bottom, 20)
                .trackScrollOffset()
            }
        }
        .onAppear {
            geminiAPIKeyInput = geminiAPIKey
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet()
        }
        .alert("Reset Goose?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetGoose() }
        } message: {
            Text("This will reset your goose to a fresh egg. Your longest streak and revive count will be preserved.")
        }
        .alert("Sign Out?", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) { signOutAndReset() }
        } message: {
            Text("This will sign you out and return to the welcome screen. Your local data will be cleared.")
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Goose avatar with gold ring
                ZStack {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(hex: 0xFFD54F), Color(hex: 0xFFA726), Color(hex: 0xFFD54F)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3.5
                        )
                        .frame(width: 80, height: 80)

                    Circle()
                        .fill(Color(hex: 0xF5F5F0))
                        .frame(width: 72, height: 72)

                    GooseCharacterView(
                        mood: gooseState.map {
                            GooseMood.deriveMood(healthiness: $0.healthiness, happiness: $0.happiness)
                        } ?? .content
                    )
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())

                    // Score badge
                    if let state = gooseState {
                        Text("\(Int((state.healthiness + state.happiness) / 2.0 * 100))")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color(hex: 0x42A5F5)))
                            .offset(x: -28, y: 28)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let username = ConvexManager.shared.currentUsername {
                        Text("@\(username)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.45))
                    }

                    HStack {
                        Text(gooseState?.name ?? "Harold")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(GoosieTheme.charcoalOutline)

                        Spacer()

                        // Edit pencil button
                        Button {
                            showEditProfile = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.3))
                        }
                    }

                    // Streak bar
                    if let state = gooseState {
                        HStack(spacing: 6) {
                            Text("Streak")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(pokGreen)

                            Text("\(state.streakDays)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(GoosieTheme.charcoalOutline)

                            // Mini progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: 0xE0E0E0))

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: 0x42A5F5))
                                        .frame(width: geo.size.width * min(Double(state.streakDays) / max(Double(state.longestStreak), 1.0), 1.0))
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            )
        }
    }

    // MARK: - Records Section

    private var recordsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Records")

            VStack(spacing: 0) {
                if let state = gooseState {
                    recordRow(label: "Current Streak", value: "\(state.streakDays) days", icon: "flame.fill", iconColor: Color(hex: 0xFF6D00))

                    Divider().padding(.leading, 52)

                    recordRow(label: "Longest Streak", value: "\(state.longestStreak) days", icon: "trophy.fill", iconColor: Color(hex: 0xF5A623))

                    Divider().padding(.leading, 52)

                    recordRow(label: "Health Score", value: "\(Int(state.healthiness * 100))%", icon: "heart.fill", iconColor: GoosieTheme.healthRed)

                    Divider().padding(.leading, 52)

                    recordRow(label: "Happiness Score", value: "\(Int(state.happiness * 100))%", icon: "face.smiling.fill", iconColor: GoosieTheme.happinessYellow)

                    Divider().padding(.leading, 52)

                    recordRow(
                        label: "Days Since Joined",
                        value: "\(Calendar.current.dateComponents([.day], from: state.createdAt, to: Date()).day ?? 0)",
                        icon: "calendar",
                        iconColor: Color(hex: 0x5C6BC0)
                    )
                }
            }
            .padding(16)
            .background(whiteCard)
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Settings")

            // Notifications card
            VStack(spacing: 0) {
                Toggle(isOn: $morningReminderEnabled) {
                    settingLabel(icon: "bell.fill", text: "Morning Reminder", color: Color(hex: 0x42A5F5))
                }
                .tint(pokGreen)
                .padding(.vertical, 4)

                if morningReminderEnabled {
                    DatePicker("Time", selection: $morningReminderTime, displayedComponents: .hourAndMinute)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .padding(.leading, 36)
                        .padding(.vertical, 4)
                        .onChange(of: morningReminderTime) { _, newTime in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                            morningReminderHour = comps.hour ?? 8
                            morningReminderMinute = comps.minute ?? 0
                            rescheduleMorningReminder()
                        }
                }

                Divider().padding(.leading, 36)

                Toggle(isOn: $decayWarningsEnabled) {
                    settingLabel(icon: "exclamationmark.triangle.fill", text: "Decay Warnings", color: Color(hex: 0xFFA726))
                }
                .tint(pokGreen)
                .padding(.vertical, 4)

                Divider().padding(.leading, 36)

                Toggle(isOn: $goalRemindersEnabled) {
                    settingLabel(icon: "target", text: "Goal Reminders", color: pokGreen)
                }
                .tint(pokGreen)
                .padding(.vertical, 4)
            }
            .padding(16)
            .background(whiteCard)
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)

            // AI Model card
            aiModelCard
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 12)

            // Live Activity card
            if let profile {
                VStack(spacing: 0) {
                    Toggle(isOn: Binding(
                        get: { profile.liveActivityEnabled },
                        set: { enabled in
                            profile.liveActivityEnabled = enabled
                            let manager = GooseLiveActivityManager.shared
                            if enabled {
                                if !manager.isActive, let state = gooseState {
                                    manager.startPetActivity(gooseName: state.name, state: state)
                                }
                            } else {
                                manager.endActivity()
                            }
                        }
                    )) {
                        settingLabel(icon: "iphone.radiowaves.left.and.right", text: "Dynamic Island", color: Color(hex: 0x5C6BC0))
                    }
                    .tint(pokGreen)
                    .padding(.vertical, 4)
                }
                .padding(16)
                .background(whiteCard)
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 12)
            }

            // Health card
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    Task { try? await HealthKitManager.shared.requestAuthorization() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(GoosieTheme.healthRed)
                            .frame(width: 24)

                        Text("Manage HealthKit Permissions")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(GoosieTheme.charcoalOutline)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.3))
                    }
                }
            }
            .padding(16)
            .background(whiteCard)
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)
        }
    }

    // MARK: - Danger Section

    private var dangerSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Account")

            VStack(spacing: 0) {
                Button { showResetConfirmation = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: 0xEF5350))
                            .frame(width: 24)

                        Text("Reset Goose")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: 0xEF5350))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.3))
                    }
                }
                .padding(.vertical, 4)

                if ConvexManager.shared.currentUsername != nil {
                    Divider().padding(.leading, 36)

                    Button { showSignOutConfirmation = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(hex: 0xEF5350))
                                .frame(width: 24)

                            Text("Sign Out")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: 0xEF5350))

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.3))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(16)
            .background(whiteCard)
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)
        }
    }

    // MARK: - AI Model Card

    private var aiModelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingLabel(icon: "brain.head.profile.fill", text: "AI Model", color: Color(hex: 0x9C27B0))

            Picker("", selection: $chatProvider) {
                Text("Apple Intelligence").tag("apple")
                Text("Gemini").tag("gemini")
            }
            .pickerStyle(.segmented)

            if chatProvider == "gemini" {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Gemini API Key")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

                    HStack {
                        if showGeminiKey {
                            TextField("paste your api key", text: $geminiAPIKeyInput)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("paste your api key", text: $geminiAPIKeyInput)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        Button { showGeminiKey.toggle() } label: {
                            Image(systemName: showGeminiKey ? "eye.slash" : "eye")
                                .font(.system(size: 13))
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(GoosieTheme.charcoalOutline.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(GoosieTheme.charcoalOutline.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .onChange(of: geminiAPIKeyInput) { _, newValue in
                        geminiAPIKey = newValue
                    }

                    Text("uses gemini-2.5-flash-lite. your key is stored locally.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.35))
                }
            }
        }
        .padding(16)
        .background(whiteCard)
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(pokGreen)
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
                colors: [pokLightGreen, pokGreen],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private func recordRow(label: String, value: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)
        }
        .padding(.vertical, 6)
    }

    private func settingLabel(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)
        }
    }

    private var whiteCard: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.white)
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }

    // MARK: - Actions

    private func resetGoose() {
        guard let state = gooseState else { return }
        GooseEngine.shared.resetGoose(state: state)
    }

    private func signOutAndReset() {
        ConvexManager.shared.signOut()

        for state in gooseStates { modelContext.delete(state) }
        for profile in profiles { modelContext.delete(profile) }
        let allGoals = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []
        for goal in allGoals { modelContext.delete(goal) }
        let allLogs = (try? modelContext.fetch(FetchDescriptor<DailyLog>())) ?? []
        for log in allLogs { modelContext.delete(log) }

        try? modelContext.save()
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
    }

    private func rescheduleMorningReminder() {
        guard let state = gooseState, morningReminderEnabled else { return }
        NotificationManager.shared.scheduleMorningReminder(
            gooseName: state.name,
            healthiness: state.healthiness,
            hour: morningReminderHour,
            minute: morningReminderMinute
        )
    }
}
