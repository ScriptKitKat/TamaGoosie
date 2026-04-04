import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gooseStates: [GooseState]

    @State private var gooseName = ""
    @State private var morningReminderEnabled = true
    @State private var morningReminderTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0))!
    @State private var decayWarningsEnabled = true
    @State private var goalRemindersEnabled = true
    @State private var showResetConfirmation = false

    private var gooseState: GooseState? {
        gooseStates.first
    }

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Text("Settings")
                        .font(GoosieTheme.titleFont(28))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Goose Name
                    GoosieCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Goose Name")
                                .font(GoosieTheme.captionFont())
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                            TextField("Name", text: $gooseName)
                                .font(GoosieTheme.bodyFont())
                                .textFieldStyle(.plain)
                                .onSubmit { saveGooseName() }
                        }
                    }

                    // Vacation Mode
                    GoosieCard {
                        Toggle(isOn: Binding(
                            get: { gooseState?.isVacationMode ?? false },
                            set: { gooseState?.isVacationMode = $0 }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Vacation Mode")
                                    .font(GoosieTheme.bodyFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                                Text("Pauses decay and notifications")
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
                            }

                            Toggle("Decay Warnings", isOn: $decayWarningsEnabled)
                                .font(GoosieTheme.captionFont())
                                .tint(GoosieTheme.mintBackground)

                            Toggle("Goal Reminders", isOn: $goalRemindersEnabled)
                                .font(GoosieTheme.captionFont())
                                .tint(GoosieTheme.mintBackground)
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
            gooseName = gooseState?.name ?? "Harnold"
        }
        .alert("Reset Goose?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetGoose() }
        } message: {
            Text("This will reset your goose to a fresh egg. Cosmetics and stats history will be preserved.")
        }
    }

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
}
