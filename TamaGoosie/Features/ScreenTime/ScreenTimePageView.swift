import SwiftUI
import SwiftData

/// Preference key to track scroll offset within the screen time page.
private struct STScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScreenTimePageView: View {
    @State private var manager = ScreenTimeManager.shared
    @Query private var gooseStates: [GooseState]
    @Query(sort: \ScreenBlock.createdAt, order: .reverse) private var allBlocks: [ScreenBlock]

    @State private var selectedTab: ScreenTimeTab = .stats
    @State private var selectedPeriod: ScreenTimePeriod = .today
    @State private var showBlockNow = false
    @State private var scrolledDown = false

    // Green palette
    private let greenTop = Color(hex: 0x6BAE6B)
    private let greenBottom = Color(hex: 0x95D095)
    private let accentGreen = Color(hex: 0x4A8F4A)

    private var gooseName: String {
        gooseStates.first?.name ?? "Harold"
    }

    var body: some View {
        ZStack {
            if manager.isSetupComplete {
                LinearGradient(
                    colors: [greenTop, greenBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            } else {
                GrassyBackgroundView()
            }

            VStack(spacing: 0) {
                if manager.isSetupComplete {
                    // Fixed tab picker
                    ScreenTimeTabPicker(selected: $selectedTab, period: $selectedPeriod)
                        .padding(.horizontal, GoosieTheme.padding)
                        .padding(.top, 52)
                        .padding(.bottom, 10)

                    ScrollView {
                        VStack(spacing: 14) {
                            switch selectedTab {
                            case .stats:
                                ScreenTimeStatsTab(period: selectedPeriod)
                            case .blocks:
                                ScreenTimeBlocksTab()
                            }
                        }
                        .padding(.horizontal, GoosieTheme.padding)
                        .padding(.bottom, 80)
                    }
                    .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
                        manager.triggerRefresh()
                    }

                } else {
                    ScreenTimeOnboardingView(gooseName: gooseName) {
                        // onComplete
                    }
                }
            }

            // Floating "Start Focus Session" bar
            if manager.isSetupComplete && selectedTab == .stats {
                VStack {
                    Spacer()
                    if !scrolledDown {
                        Button {
                            showBlockNow = true
                        } label: {
                            HStack {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 16))
                                Text("Start Focus Session")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Spacer()
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16))
                                    .frame(width: 36, height: 36)
                                    .background(.white.opacity(0.2), in: Circle())
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(accentGreen)
                                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                            )
                        }
                        .padding(.horizontal, GoosieTheme.padding)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
        .fullScreenCover(isPresented: $showBlockNow) {
            BlockNowSheet(existingBlock: nil)
        }
        .onAppear {
            let activeBlocks = allBlocks.filter { !$0.isPast }
            ScreenTimeManager.shared.reconcileBlocks(activeBlocks)
        }
    }
}
