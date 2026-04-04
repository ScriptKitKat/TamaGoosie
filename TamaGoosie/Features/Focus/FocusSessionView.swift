import SwiftUI
import SwiftData

struct FocusSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gooseStates: [GooseState]

    @State private var timer = FocusTimer()
    @State private var showDurationPicker = false

    private var gooseState: GooseState? {
        gooseStates.first
    }

    private var gooseMood: GooseMood {
        if timer.isCompleted { return .ecstatic }
        if timer.isRunning {
            return timer.progress > 0.5 ? .happy : .content
        }
        return gooseState?.currentMood ?? .neutral
    }

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Let's Focus")
                    .font(GoosieTheme.titleFont(28))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Spacer()

                // Timer ring with goose
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(GoosieTheme.charcoalOutline.opacity(0.1), lineWidth: 8)
                        .frame(width: 260, height: 260)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: timer.progress)
                        .stroke(
                            LinearGradient(
                                colors: [GoosieTheme.mintBackground, GoosieTheme.coralAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 260, height: 260)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timer.progress)

                    // Goose in center
                    GooseCharacterView(
                        mood: gooseMood,
                        phase: gooseState?.currentPhase ?? .baby
                    )
                    .scaleEffect(0.7)
                }

                // Timer display
                Text(timer.displayTime)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                    .contentTransition(.numericText())

                // Duration picker button
                if !timer.isRunning {
                    Button {
                        showDurationPicker = true
                    } label: {
                        Text("\(timer.targetMinutes) min")
                            .font(GoosieTheme.bodyFont(16))
                            .foregroundStyle(GoosieTheme.coralAccent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(GoosieTheme.coralAccent.opacity(0.15))
                            )
                    }
                }

                Spacer()

                // Controls
                HStack(spacing: 20) {
                    if timer.isRunning {
                        PillButton(title: "Pause", icon: "pause.fill", color: GoosieTheme.warmOrange) {
                            timer.pause()
                        }
                    } else if timer.isCompleted {
                        PillButton(title: "Done!", icon: "checkmark", color: GoosieTheme.hygieneGreen) {
                            finishSession(completed: true)
                        }
                    } else {
                        if timer.remainingSeconds < timer.targetMinutes * 60 {
                            PillButton(title: "Reset", icon: "arrow.counterclockwise", color: GoosieTheme.charcoalOutline.opacity(0.5)) {
                                timer.reset()
                            }
                        }

                        PillButton(title: "Start", icon: "play.fill", color: GoosieTheme.coralAccent) {
                            timer.start()
                        }
                    }
                }

                // Encouragement text
                if timer.isRunning {
                    Text("Your goose is cheering you on!")
                        .font(GoosieTheme.captionFont())
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                }
            }
            .padding(GoosieTheme.padding)
        }
        .sheet(isPresented: $showDurationPicker) {
            durationPicker
        }
    }

    // MARK: - Duration Picker

    private var durationPicker: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Focus Duration")
                    .font(GoosieTheme.titleFont(22))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                let durations = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120]
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(durations, id: \.self) { minutes in
                        Button {
                            timer.setDuration(minutes)
                            showDurationPicker = false
                        } label: {
                            Text("\(minutes)m")
                                .font(GoosieTheme.bodyFont(16))
                                .foregroundStyle(timer.targetMinutes == minutes ? .white : GoosieTheme.charcoalOutline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(timer.targetMinutes == minutes ? GoosieTheme.coralAccent : GoosieTheme.creamWhite)
                                )
                        }
                    }
                }
                .padding()
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Session Completion

    private func finishSession(completed: Bool) {
        let session = FocusSession(targetMinutes: timer.targetMinutes)
        session.finish(completed: completed)
        modelContext.insert(session)

        if completed, let state = gooseState {
            GooseEngine.shared.completeFocusSession(minutes: timer.elapsedMinutes, state: state)
        }

        timer.reset()
    }
}
