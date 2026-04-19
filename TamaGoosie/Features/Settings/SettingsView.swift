import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gooseStates: [GooseState]
    @Query private var profiles: [UserProfile]

    @AppStorage("chatProvider") private var chatProvider: String = "apple"
    @AppStorage("geminiAPIKey") private var geminiAPIKey: String = ""
    @State private var geminiAPIKeyInput: String = ""
    @State private var showGeminiKey: Bool = false

    @State private var gooseName = ""
    @State private var morningReminderEnabled = true
    @State private var morningReminderHour = 8
    @State private var morningReminderMinute = 0
    @State private var morningReminderTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0))!
    @State private var decayWarningsEnabled = true
    @State private var goalRemindersEnabled = true
    @State private var showResetConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var debugGoalTitle = "Read for 30 minutes"
    @State private var debugPushLevel = 1
    @State private var debugPushSent = false
    @State private var debugReminderSent = false
    @State private var debugResetSent = false
    @State private var debugStatOverrideEnabled = false
    @State private var debugHealthSlider: Double = 1.0
    @State private var debugHappinessSlider: Double = 1.0

    private var gooseState: GooseState? { gooseStates.first }
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Text("Settings")
                        .font(GoosieTheme.titleFont(28))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Account
                    if let username = ConvexManager.shared.currentUsername {
                        GoosieCard {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(GoosieTheme.coralAccent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("@\(username)")
                                            .font(GoosieTheme.bodyFont())
                                            .foregroundStyle(GoosieTheme.charcoalOutline)
                                        if let provider = AuthService.shared.authProvider {
                                            Text("Signed in with \(provider == "apple" ? "Apple" : "Google")")
                                                .font(GoosieTheme.captionFont(11))
                                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                                        }
                                    }
                                    Spacer()
                                }

                                Button {
                                    showSignOutConfirmation = true
                                } label: {
                                    Text("Sign Out")
                                        .font(GoosieTheme.captionFont(13))
                                        .foregroundStyle(GoosieTheme.coralAccent)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    // Goose Name
                    GoosieCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Goose Name", systemImage: "bird.fill")
                                .font(GoosieTheme.captionFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                            TextField("Name", text: $gooseName)
                                .font(GoosieTheme.bodyFont())
                                .textFieldStyle(.plain)
                                .onSubmit { saveGooseName() }
                        }
                    }

                    // Baselines
                    if let profile {
                        baselinesCard(profile: profile)
                    }

                    // Duck History
                    DuckHistoryCard()

                    // Notifications
                    GoosieCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notifications")
                                .font(GoosieTheme.bodyFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline)

                            Toggle("Morning Reminder", isOn: $morningReminderEnabled)
                                .font(GoosieTheme.captionFont())
                                .tint(GoosieTheme.mintBackground)

                            if morningReminderEnabled {
                                DatePicker("Time", selection: $morningReminderTime, displayedComponents: .hourAndMinute)
                                    .font(GoosieTheme.captionFont())
                                    .onChange(of: morningReminderTime) { _, newTime in
                                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                                        morningReminderHour = comps.hour ?? 8
                                        morningReminderMinute = comps.minute ?? 0
                                        rescheduleMorningReminder()
                                    }
                            }

                            Toggle("Decay Warnings", isOn: $decayWarningsEnabled)
                                .font(GoosieTheme.captionFont())
                                .tint(GoosieTheme.mintBackground)

                            Toggle("Goal Reminders", isOn: $goalRemindersEnabled)
                                .font(GoosieTheme.captionFont())
                                .tint(GoosieTheme.mintBackground)
                        }
                    }

                    // AI Model
                    aiModelCard

                    // Live Activity
                    if let profile {
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Live Activity")
                                    .font(GoosieTheme.bodyFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline)

                                Toggle("Show Goose in Dynamic Island", isOn: Binding(
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
                                ))
                                .font(GoosieTheme.captionFont())
                                .tint(GoosieTheme.mintBackground)
                            }
                        }
                    }

                    // Health
                    GoosieCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Health Data")
                                .font(GoosieTheme.bodyFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                            Button {
                                Task { try? await HealthKitManager.shared.requestAuthorization() }
                            } label: {
                                Text("Manage HealthKit Permissions")
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.coralAccent)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Danger Zone
                    GoosieCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Danger Zone")
                                .font(GoosieTheme.bodyFont())
                                .foregroundStyle(GoosieTheme.coralAccent)
                            Button {
                                showResetConfirmation = true
                            } label: {
                                Text("Reset Goose")
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.coralAccent)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Debug Panel
                    debugPanel

                    // About
                    GoosieCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TamaGoosie")
                                .font(GoosieTheme.bodyFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                            Text("Version 1.0")
                                .font(GoosieTheme.captionFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(GoosieTheme.padding)
            }
        }
        .onAppear {
            gooseName = gooseState?.name ?? "Harold"
            geminiAPIKeyInput = geminiAPIKey
        }
        .alert("Reset Goose?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetGoose() }
        } message: {
            Text("This will reset your goose to a fresh egg. Your longest streak and revive count will be preserved.")
        }
        .alert("Sign Out?", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                signOutAndReset()
            }
        } message: {
            Text("This will sign you out and return to the welcome screen. Your local data will be cleared.")
        }
    }

    // MARK: - Debug Panel

    private var debugPanel: some View {
        GoosieCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Debug", systemImage: "ant.fill")
                    .font(GoosieTheme.bodyFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                // Stat Override
                Toggle("Override Stats", isOn: $debugStatOverrideEnabled)
                    .font(GoosieTheme.captionFont())
                    .tint(GoosieTheme.coralAccent)
                    .onChange(of: debugStatOverrideEnabled) { _, enabled in
                        if enabled, let state = gooseState {
                            debugHealthSlider = state.healthiness
                            debugHappinessSlider = state.happiness
                        } else if !enabled, let state = gooseState {
                            GooseEngine.shared.update(state: state, log: nil, profile: profile, goals: [])
                        }
                    }

                if debugStatOverrideEnabled, let state = gooseState {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Health")
                                .font(GoosieTheme.captionFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
                                .frame(width: 70, alignment: .leading)
                            Slider(value: $debugHealthSlider, in: 0...1)
                                .tint(.red)
                                .onChange(of: debugHealthSlider) { _, val in
                                    state.healthiness = val
                                    state.updateMood()
                                    GooseLiveActivityManager.shared.updateStats(state: state)
                                }
                            Text("\(Int(debugHealthSlider * 100))%")
                                .font(GoosieTheme.captionFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                                .frame(width: 36, alignment: .trailing)
                        }
                        HStack {
                            Text("Happiness")
                                .font(GoosieTheme.captionFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
                                .frame(width: 70, alignment: .leading)
                            Slider(value: $debugHappinessSlider, in: 0...1)
                                .tint(.yellow)
                                .onChange(of: debugHappinessSlider) { _, val in
                                    state.happiness = val
                                    state.updateMood()
                                    GooseLiveActivityManager.shared.updateStats(state: state)
                                }
                            Text("\(Int(debugHappinessSlider * 100))%")
                                .font(GoosieTheme.captionFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }

                Divider()

                Text("Notifications")
                    .font(GoosieTheme.captionFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                TextField("Goal title", text: $debugGoalTitle)
                    .font(GoosieTheme.captionFont())
                    .textFieldStyle(.roundedBorder)

                // Type 1: Reminder
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Type 1 — Reminder")
                            .font(GoosieTheme.captionFont())
                            .foregroundStyle(GoosieTheme.charcoalOutline)
                        Text("fires in 5s")
                            .font(GoosieTheme.captionFont(11))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.45))
                    }
                    Spacer()
                    Button {
                        debugReminderSent = false
                        fireDebugReminder()
                    } label: {
                        Text(debugReminderSent ? "sent!" : "fire")
                            .font(GoosieTheme.captionFont())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(debugReminderSent ? Color.gray : GoosieTheme.mintBackground))
                    }
                }

                Divider()

                // Type 2: Push
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Type 2 — Push (level \(debugPushLevel))")
                            .font(GoosieTheme.captionFont())
                            .foregroundStyle(GoosieTheme.charcoalOutline)
                        Text("fires in 5s")
                            .font(GoosieTheme.captionFont(11))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.45))
                    }
                    Spacer()
                    Stepper("", value: $debugPushLevel, in: 1...8)
                        .labelsHidden()
                        .frame(width: 90)
                    Button {
                        debugPushSent = false
                        fireDebugPush()
                    } label: {
                        Text(debugPushSent ? "sent!" : "fire")
                            .font(GoosieTheme.captionFont())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(debugPushSent ? Color.gray : GoosieTheme.coralAccent))
                    }
                }

                Divider()

                // Type 3: Reset suggestion
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Type 3 — Reset Suggestion")
                            .font(GoosieTheme.captionFont())
                            .foregroundStyle(GoosieTheme.charcoalOutline)
                        Text("fires in 5s")
                            .font(GoosieTheme.captionFont(11))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.45))
                    }
                    Spacer()
                    Button {
                        debugResetSent = false
                        fireDebugReset()
                    } label: {
                        Text(debugResetSent ? "sent!" : "fire")
                            .font(GoosieTheme.captionFont())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(debugResetSent ? Color.gray : Color.purple.opacity(0.7)))
                    }
                }
            }
        }
    }

    private func fireDebugReminder() {
        let title = debugGoalTitle.isEmpty ? "your goal" : debugGoalTitle
        Task {
            let body = await GooseSpeechGenerator.shared.reminder(goalTitle: title)
            let content = UNMutableNotificationContent()
            content.title = "don't forget!"
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let req = UNNotificationRequest(identifier: "debug_reminder_\(UUID().uuidString)", content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(req)
            await MainActor.run { debugReminderSent = true }
        }
    }

    private func fireDebugPush() {
        let title = debugGoalTitle.isEmpty ? "your goal" : debugGoalTitle
        let level = debugPushLevel
        Task {
            let body = await GooseSpeechGenerator.shared.push(goalTitle: title, level: level, ignored: level > 1)
            let content = UNMutableNotificationContent()
            content.title = debugPushTitle(level)
            content.body = body
            content.sound = .default
            content.categoryIdentifier = "PUSH_CATEGORY"
            content.userInfo = ["goalID": UUID().uuidString, "goalTitle": title, "type": "push", "level": level]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let req = UNNotificationRequest(identifier: "debug_push_\(UUID().uuidString)", content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(req)
            await MainActor.run { debugPushSent = true }
        }
    }

    private func fireDebugReset() {
        let title = debugGoalTitle.isEmpty ? "your goal" : debugGoalTitle
        Task {
            let body = await GooseSpeechGenerator.shared.resetSuggestion(goalTitle: title, failCount: 3, isDeadline: false)
            let content = UNMutableNotificationContent()
            content.title = "maybe time to adjust?"
            content.body = body
            content.sound = .default
            content.categoryIdentifier = "RESET_CATEGORY"
            content.userInfo = ["goalID": UUID().uuidString, "goalTitle": title, "type": "reset"]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let req = UNNotificationRequest(identifier: "debug_reset_\(UUID().uuidString)", content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(req)
            await MainActor.run { debugResetSent = true }
        }
    }

    private func debugPushTitle(_ level: Int) -> String {
        switch level {
        case 1: return "hey, don't forget!"
        case 2: return "still waiting..."
        case 3: return "honk honk!!"
        case 4: return "please!!"
        default: return "honk."
        }
    }

    // MARK: - AI Model Card

    private var aiModelCard: some View {
        GoosieCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("AI Model")
                    .font(GoosieTheme.bodyFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Picker("", selection: $chatProvider) {
                    Text("Apple Intelligence").tag("apple")
                    Text("Gemini").tag("gemini")
                }
                .pickerStyle(.segmented)

                if chatProvider == "gemini" {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Gemini API Key")
                            .font(GoosieTheme.captionFont())
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                        HStack {
                            if showGeminiKey {
                                TextField("paste your api key", text: $geminiAPIKeyInput)
                                    .font(GoosieTheme.captionFont())
                                    .textFieldStyle(.plain)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            } else {
                                SecureField("paste your api key", text: $geminiAPIKeyInput)
                                    .font(GoosieTheme.captionFont())
                                    .textFieldStyle(.plain)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            }

                            Button {
                                showGeminiKey.toggle()
                            } label: {
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
                            .font(GoosieTheme.captionFont(11))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                    }
                }
            }
        }
    }

    // MARK: - Baselines Card

    private func baselinesCard(profile: UserProfile) -> some View {
        GoosieCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Baselines")
                    .font(GoosieTheme.bodyFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Text("Used to normalize your health scores. Auto-updates after 7 days of data.")
                    .font(GoosieTheme.captionFont(11))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

                Divider()

                baselineRow("Sleep", value: "\(String(format: "%.1f", profile.avgSleepHours))h", icon: "moon.fill")
                baselineRow("Steps", value: "\(profile.avgSteps)", icon: "figure.walk")
                baselineRow("Exercise", value: "\(profile.avgExerciseMinutes)min", icon: "heart.fill")
                baselineRow("Sitting", value: "\(String(format: "%.1f", profile.avgSittingHours))h", icon: "chair.lounge.fill")
            }
        }
    }

    private func baselineRow(_ label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(GoosieTheme.coralAccent)
                .frame(width: 16)
            Text(label)
                .font(GoosieTheme.captionFont())
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
            Spacer()
            Text(value)
                .font(GoosieTheme.captionFont())
                .fontWeight(.semibold)
                .foregroundStyle(GoosieTheme.charcoalOutline)
        }
    }

    // MARK: - Actions

    private func saveGooseName() {
        let trimmed = gooseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        gooseState?.name = trimmed
    }

    private func resetGoose() {
        guard let state = gooseState else { return }
        GooseEngine.shared.resetGoose(state: state)
        gooseName = state.name
    }

    private func signOutAndReset() {
        // Sign out of Convex + auth provider
        ConvexManager.shared.signOut()

        // Delete all local SwiftData entities so onboarding triggers again
        for state in gooseStates { modelContext.delete(state) }
        for profile in profiles { modelContext.delete(profile) }
        let allGoals = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []
        for goal in allGoals { modelContext.delete(goal) }
        let allLogs = (try? modelContext.fetch(FetchDescriptor<DailyLog>())) ?? []
        for log in allLogs { modelContext.delete(log) }

        try? modelContext.save()

        // Clear the onboarding UserDefaults flag
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
