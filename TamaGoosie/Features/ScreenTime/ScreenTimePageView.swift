import SwiftUI
import SwiftData

struct ScreenTimePageView: View {
    @State private var manager = ScreenTimeManager.shared
    @Query private var gooseStates: [GooseState]

    private var gooseName: String {
        gooseStates.first?.name ?? "Harold"
    }

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground
                .ignoresSafeArea()

            if manager.isSetupComplete {
                ScreenTimeDashboardView()
            } else {
                ScreenTimeOnboardingView(gooseName: gooseName) {
                    // onComplete — setup is done, manager.isSetupComplete is now true
                }
            }
        }
    }
}
