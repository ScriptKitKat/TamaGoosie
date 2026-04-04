import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gooseStates: [GooseState]
    @Query private var profiles: [UserProfile]

    @State private var gooseName = ""
    @State private var morningReminderEnabled = true
    @State private var morningReminderHour = 8
    @State private var morningReminderMinute = 0
    @State private var morningReminderTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0))!
    @State private var decayWarningsEnabled = true
    @State private var goalRemindersEnabled = true
    @State private var showResetConfirmation = false
    @State private var debugGoalTitle = "Read for 30 minutes"
    @State private var debugPushLevel = 1
    @State private var debugPushSent = false
    @State private var debugReminderSent = false
    @State private var debugResetSent = false

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

                    // Distraction Apps
                    GoosieCard {
                        NavigationLink(destination: DistractionConfigView()) {
                            HStack {
                                Label("Distraction Apps", systemImage: "iphone.slash")
                                    .font(GoosieTheme.bodyFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
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
        }
        .alert("Reset Goose?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetGoose() }
        } message: {
            Text("This will reset your goose to a fresh egg. Your longest streak and revive count will be preserved.")
        }
    }

    // MARK: - Debug Panel

    private var debugPanel: some View {
        GoosieCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Notification Debug", systemImage: "ant.fill")
                    .font(GoosieTheme.bodyFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline)

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
