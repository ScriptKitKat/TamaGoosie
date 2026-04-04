import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @State private var selectedTab = 0
    @State private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainTabView
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .onAppear {
            if let profile = profiles.first, profile.hasCompletedOnboarding {
                hasCompletedOnboarding = true
            }

            WatchSyncService.shared.activate()
            HealthKitManager.shared.enableBackgroundDelivery()
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            GooseView()
                .tabItem {
                    Image(systemName: "bird.fill")
                    Text("Goose")
                }
                .tag(0)

            GoalListView()
                .tabItem {
                    Image(systemName: "checklist")
                    Text("Goals")
                }
                .tag(1)

            FocusSessionView()
                .tabItem {
                    Image(systemName: "timer")
                    Text("Focus")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(3)
        }
        .tint(GoosieTheme.coralAccent)
    }
}
