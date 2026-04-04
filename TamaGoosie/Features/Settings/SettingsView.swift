import SwiftUI
import SwiftData

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

                    // Vacation Mode
                    GoosieCard {
                        Toggle(isOn: Binding(
                            get: { gooseState?.isVacationMode ?? false },
                            set: { newValue in
                                gooseState?.isVacationMode = newValue
                                profile?.vacationMode = newValue
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Vacation Mode")
                                    .font(GoosieTheme.bodyFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                                Text("Pauses decay, disables reminders, freezes streak")
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                            }
                        }
                        .tint(GoosieTheme.mintBackground)
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
        GooseEngine.shared.hatchNewEgg(state: state)
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
