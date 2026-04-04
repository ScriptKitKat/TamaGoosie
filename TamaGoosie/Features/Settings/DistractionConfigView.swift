import SwiftUI
import SwiftData
import FamilyControls

struct DistractionConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var screenTimeManager = ScreenTimeManager.shared
    @State private var showPicker = false
    @State private var draftSelection = FamilyActivitySelection()

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    infoCard

                    if screenTimeManager.isAuthorized {
                        authorizedContent
                    } else {
                        unauthorizedContent
                    }
                }
                .padding(GoosieTheme.padding)
            }
        }
        .navigationTitle("Distraction Apps")
        .navigationBarTitleDisplayMode(.large)
        .familyActivityPicker(isPresented: $showPicker, selection: $draftSelection)
        .onChange(of: showPicker) { wasShowing, isShowing in
            if wasShowing && !isShowing {
                screenTimeManager.saveSelection(draftSelection)
            }
        }
        .onAppear {
            draftSelection = screenTimeManager.selection
        }
        .task {
            if screenTimeManager.authorizationStatus == .notDetermined {
                await screenTimeManager.requestAuthorization()
            }
        }
    }

    // MARK: - Subviews

    private var infoCard: some View {
        GoosieCard {
            HStack(spacing: 12) {
                Image(systemName: "iphone.slash")
                    .font(.system(size: 24))
                    .foregroundStyle(GoosieTheme.coralAccent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Track Distractions")
                        .font(GoosieTheme.bodyFont(15))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                    Text("Using tracked apps reduces your goose's happiness.")
                        .font(GoosieTheme.captionFont(12))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                }
            }
        }
    }

    private var authorizedContent: some View {
        VStack(spacing: 12) {
            GoosieCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Screen Time Connected")
                            .font(GoosieTheme.bodyFont(15))
                            .foregroundStyle(GoosieTheme.charcoalOutline)
                    }

                    if screenTimeManager.hasSelection {
                        let appCount = screenTimeManager.selection.applicationTokens.count
                        let catCount = screenTimeManager.selection.categoryTokens.count
                        Text(selectionSummary(apps: appCount, categories: catCount))
                            .font(GoosieTheme.captionFont(12))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                    } else {
                        Text("No apps selected yet — tap below to choose.")
                            .font(GoosieTheme.captionFont(12))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                    }
                }
            }

            PillButton(
                title: screenTimeManager.hasSelection ? "Change Selected Apps" : "Choose Apps to Track",
                icon: "app.badge",
                color: GoosieTheme.coralAccent
            ) {
                draftSelection = screenTimeManager.selection
                showPicker = true
            }

            if screenTimeManager.hasSelection {
                thresholdInfoCard
            }
        }
    }

    private var unauthorizedContent: some View {
        VStack(spacing: 12) {
            GoosieCard {
                VStack(spacing: 10) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 36))
                        .foregroundStyle(GoosieTheme.coralAccent.opacity(0.7))
                    Text("Screen Time Access Required")
                        .font(GoosieTheme.bodyFont(15))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                    Text("TamaGoosie uses Screen Time to automatically detect when you use distracting apps — no manual setup needed.")
                        .font(GoosieTheme.captionFont(12))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            PillButton(
                title: "Allow Screen Time Access",
                icon: "lock.open",
                color: GoosieTheme.coralAccent
            ) {
                Task { await screenTimeManager.requestAuthorization() }
            }
        }
    }

    private var thresholdInfoCard: some View {
        GoosieCard {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 14))
                Text("Every \(GoosieConstants.screenTimeThresholdMinutes) minutes on tracked apps reduces your goose's happiness.")
                    .font(GoosieTheme.captionFont(12))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
            }
        }
    }

    // MARK: - Helpers

    private func selectionSummary(apps: Int, categories: Int) -> String {
        switch (apps, categories) {
        case (0, 0): return "Nothing selected"
        case (let a, 0): return "\(a) app\(a == 1 ? "" : "s") selected"
        case (0, let c): return "\(c) categor\(c == 1 ? "y" : "ies") selected"
        default: return "\(apps) app\(apps == 1 ? "" : "s") and \(categories) categor\(categories == 1 ? "y" : "ies") selected"
        }
    }
}
