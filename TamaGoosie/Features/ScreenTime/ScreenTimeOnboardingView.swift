import SwiftUI
import FamilyControls

struct ScreenTimeOnboardingView: View {
    let gooseName: String
    let onComplete: () -> Void

    @State private var step = 0
    @State private var manager = ScreenTimeManager.shared
    @State private var showPicker = false
    @State private var draftSelection = FamilyActivitySelection()

    private let totalSteps = 6

    var body: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 12)

            ZStack {
                switch step {
                case 0: awarenessStep
                case 1: problemStep
                case 2: solutionStep
                case 3: permissionsStep
                case 4: appSelectionStep
                case 5: scheduleStep
                default: EmptyView()
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $draftSelection)
        .onChange(of: showPicker) { wasShowing, isShowing in
            if wasShowing && !isShowing {
                if !draftSelection.applicationTokens.isEmpty || !draftSelection.categoryTokens.isEmpty {
                    manager.saveSelection(draftSelection)
                }
            }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            if step > 0 {
                Button {
                    step -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                }
            }

            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? GoosieTheme.skyBlue : GoosieTheme.charcoalOutline.opacity(0.15))
                    .frame(height: 4)
            }
        }
    }

    private var awarenessStep: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Do you know how long\nyou scroll each day?")
                .font(GoosieTheme.titleFont(24))
                .foregroundStyle(GoosieTheme.charcoalOutline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer().frame(height: 32)
            GooseCharacterView(mood: .content)
                .frame(height: 200)
            Spacer()
            stepButton(title: "probably... too long?") { step = 1 }
        }
    }

    private var problemStep: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("One quick scroll...\nand 30 minutes are gone.")
                .font(GoosieTheme.titleFont(24))
                .foregroundStyle(GoosieTheme.charcoalOutline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer().frame(height: 32)
            GooseCharacterView(mood: .sad)
                .frame(height: 200)
            Spacer()
            stepButton(title: "that's me...") { step = 2 }
        }
    }

    private var solutionStep: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("\(gooseName) will help\nguard your time!")
                .font(GoosieTheme.titleFont(24))
                .foregroundStyle(GoosieTheme.charcoalOutline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer().frame(height: 32)
            GooseCharacterView(mood: .happy)
                .frame(height: 200)
            Spacer()
            stepButton(title: "Let's set it up!") { step = 3 }
        }
    }

    private var permissionsStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Text("Enable Screen Time Guard")
                    .font(GoosieTheme.titleFont(22))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                Text("Just a few quick steps to start guarding your time:")
                    .font(GoosieTheme.captionFont(14))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GoosieTheme.padding)

            Spacer().frame(height: 32)

            VStack(spacing: 16) {
                GoosieCard {
                    HStack(spacing: 12) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 22))
                            .foregroundStyle(GoosieTheme.skyBlue)
                            .frame(width: 40, height: 40)
                            .background(GoosieTheme.skyBlue.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Screen Time")
                                .font(GoosieTheme.bodyFont(15))
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                            Text("Let TamaGoosie access your app-usage data.")
                                .font(GoosieTheme.captionFont(12))
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                        }
                        Spacer()
                        Toggle("", isOn: .init(
                            get: { manager.isAuthorized },
                            set: { _ in Task { await manager.requestAuthorization() } }
                        ))
                        .labelsHidden()
                        .tint(GoosieTheme.skyBlue)
                    }
                }
            }
            .padding(.horizontal, GoosieTheme.padding)

            Spacer()

            Text("Data is stored only on your device.")
                .font(GoosieTheme.captionFont(12))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                .padding(.bottom, 8)

            stepButton(title: "Let's Go", isEnabled: manager.isAuthorized) { step = 4 }
        }
    }

    private var appSelectionStep: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Choose apps to limit")
                .font(GoosieTheme.titleFont(24))
                .foregroundStyle(GoosieTheme.charcoalOutline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer().frame(height: 16)
            Text("Pick the apps that distract you most.\n\(gooseName) will keep an eye on them.")
                .font(GoosieTheme.captionFont(14))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer().frame(height: 32)
            GooseCharacterView(mood: .happy)
                .frame(height: 160)
            Spacer().frame(height: 24)
            PillButton(
                title: manager.hasSelection ? "Change Selected Apps" : "Select Apps",
                icon: "app.badge",
                color: GoosieTheme.coralAccent
            ) {
                draftSelection = manager.selection
                showPicker = true
            }
            if manager.hasSelection {
                let count = manager.selection.applicationTokens.count + manager.selection.categoryTokens.count
                Text("\(count) item\(count == 1 ? "" : "s") selected")
                    .font(GoosieTheme.captionFont(12))
                    .foregroundStyle(GoosieTheme.skyBlue)
                    .padding(.top, 8)
            }
            Spacer()
            stepButton(title: "Continue", isEnabled: manager.hasSelection) { step = 5 }
        }
    }

    private var scheduleStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Set your limits")
                    .font(GoosieTheme.titleFont(24))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                    .padding(.top, 20)

                ScreenTimeScheduleView {
                    manager.isSetupComplete = true
                    onComplete()
                }
            }
            .padding(.horizontal, GoosieTheme.padding)
        }
    }

    private func stepButton(title: String, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(GoosieTheme.bodyFont(16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: GoosieTheme.cornerRadius)
                        .fill(isEnabled ? GoosieTheme.skyBlue : GoosieTheme.charcoalOutline.opacity(0.2))
                )
        }
        .disabled(!isEnabled)
        .padding(.horizontal, GoosieTheme.padding)
        .padding(.bottom, 36)
    }
}
