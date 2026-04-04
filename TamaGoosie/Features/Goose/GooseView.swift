import SwiftUI
import SwiftData

struct GooseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gooseStates: [GooseState]
    @Query(filter: #Predicate<Goal> { $0.isActive && !$0.isCompleted })
    private var activeGoals: [Goal]

    @State private var viewModel = GooseViewModel()

    private var gooseState: GooseState {
        gooseStates.first ?? GooseState()
    }

    var body: some View {
        ZStack {
            // Background
            GoosieTheme.mintBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    header

                    // Goose Character
                    GooseCharacterView(
                        mood: viewModel.mood,
                        phase: viewModel.phase,
                        showReaction: viewModel.currentReaction
                    )
                    .frame(height: 220)

                    // Mood label
                    moodLabel

                    // Stat bars
                    statBars

                    // Quick actions
                    quickActions
                }
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            ensureGooseExists()
            viewModel.onAppear(state: gooseState)
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .sheet(isPresented: $viewModel.showDeathScreen) {
            DeathScreen(viewModel: viewModel)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.gooseName)
                    .font(GoosieTheme.titleFont(28))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                LevelBadge(level: viewModel.level)
            }

            Spacer()

            StreakFlame(days: viewModel.streakDays)
        }
        .padding(.top, 8)
    }

    // MARK: - Mood Label

    private var moodLabel: some View {
        Text(viewModel.moodText)
            .font(GoosieTheme.bodyFont(18))
            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(GoosieTheme.creamWhite)
            )
    }

    // MARK: - Stat Bars

    private var statBars: some View {
        GoosieCard {
            VStack(spacing: 12) {
                StatBar(label: "Health", icon: "heart.fill", value: viewModel.healthPercent, color: GoosieTheme.healthRed)
                StatBar(label: "Happy", icon: "face.smiling.fill", value: viewModel.happinessPercent, color: GoosieTheme.happinessYellow)
                StatBar(label: "Energy", icon: "bolt.fill", value: viewModel.energyPercent, color: GoosieTheme.energyBlue)
                StatBar(label: "Hygiene", icon: "drop.fill", value: viewModel.hygienePercent, color: GoosieTheme.hygieneGreen)
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 16) {
            CircleActionButton(icon: "fork.knife", label: "Feed", color: GoosieTheme.coralAccent) {
                viewModel.feedGoose()
            }

            CircleActionButton(icon: "checkmark.circle", label: "Goals", color: GoosieTheme.hygieneGreen) {
                if let goal = activeGoals.first {
                    viewModel.completeGoal(goal)
                }
            }

            CircleActionButton(icon: "figure.run", label: "Exercise", color: GoosieTheme.energyBlue) {
                // Navigate to health tab
            }

            CircleActionButton(icon: "shower.fill", label: "Clean", color: GoosieTheme.skyBlue) {
                viewModel.cleanGoose()
            }
        }
    }

    // MARK: - Helpers

    private func ensureGooseExists() {
        if gooseStates.isEmpty {
            let newGoose = GooseState()
            modelContext.insert(newGoose)
        }
    }
}

// MARK: - Death Screen

struct DeathScreen: View {
    let viewModel: GooseViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Oh no...")
                    .font(GoosieTheme.titleFont(32))
                    .foregroundStyle(.white)

                GooseCharacterView(mood: .dead, phase: .adult)
                    .frame(height: 180)
                    .saturation(0)

                Text("\(viewModel.gooseName) has passed away")
                    .font(GoosieTheme.bodyFont(18))
                    .foregroundStyle(.white.opacity(0.8))

                // Memorial stats
                GoosieCard {
                    VStack(spacing: 8) {
                        memorialStat("Days alive", value: "\(viewModel.gooseState?.daysAlive ?? 0)")
                        memorialStat("Goals completed", value: "\(viewModel.gooseState?.totalGoalsCompleted ?? 0)")
                        memorialStat("Longest streak", value: "\(viewModel.gooseState?.longestStreak ?? 0) days")
                    }
                }
                .padding(.horizontal, 40)

                VStack(spacing: 12) {
                    PillButton(title: "Revive", icon: "heart.fill", color: GoosieTheme.coralAccent) {
                        _ = viewModel.reviveGoose()
                    }

                    PillButton(title: "Hatch New Egg", icon: "egg.fill", color: GoosieTheme.mintBackground) {
                        viewModel.hatchNewGoose()
                    }
                }
            }
            .padding()
        }
    }

    private func memorialStat(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(GoosieTheme.captionFont())
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
            Spacer()
            Text(value)
                .font(GoosieTheme.bodyFont(14))
                .foregroundStyle(GoosieTheme.charcoalOutline)
        }
    }
}
