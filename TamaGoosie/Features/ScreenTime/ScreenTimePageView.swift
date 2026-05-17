import SwiftUI
import SwiftData

struct ScreenTimePageView: View {
    @State private var manager = ScreenTimeManager.shared
    @Query private var gooseStates: [GooseState]
    @Query(sort: \ScreenBlock.createdAt, order: .reverse) private var allBlocks: [ScreenBlock]

    @State private var selectedTab: ScreenTimeTab = .stats

    private var gooseName: String {
        gooseStates.first?.name ?? "Harold"
    }

    var body: some View {
        ZStack {
            GrassyBackgroundView()

            VStack(spacing: 0) {
                if manager.isSetupComplete {
                    ScrollView {
                        VStack(spacing: 16) {
                            ScreenTimeTabPicker(selected: $selectedTab)

                            switch selectedTab {
                            case .stats:
                                ScreenTimeStatsTab()
                            case .blocks:
                                ScreenTimeBlocksTab()
                            }
                        }
                        .padding(.horizontal, GoosieTheme.padding)
                        .padding(.top, 52)
                        .padding(.bottom, 20)
                        .trackScrollOffset()
                    }
                } else {
                    ScreenTimeOnboardingView(gooseName: gooseName) {
                        // onComplete — setup is done
                    }
                }
            }
        }
        .onAppear {
            let activeBlocks = allBlocks.filter { !$0.isPast }
            ScreenTimeManager.shared.refreshAllBlocks(activeBlocks)
        }
    }
}
