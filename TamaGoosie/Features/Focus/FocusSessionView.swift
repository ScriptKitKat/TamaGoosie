import SwiftUI
import SwiftData

struct FocusSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gooseStates: [GooseState]

    @State private var timer = FocusTimer()
    @State private var showDurationPicker = false
    @State private var showDistractionOverlay = false

    private var gooseState: GooseState? {
        gooseStates.first
    }

    private var gooseMood: GooseMood {
        if timer.isCompleted { return .happy }
        if timer.isRunning {
            return timer.progress > 0.5 ? .happy : .content
        }
        return gooseState?.currentMood ?? .content
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

                ZStack {
                    Circle()
                        .stroke(GoosieTheme.charcoalOutline.opacity(0.1), lineWidth: 8)
                        .frame(width: 260, height: 260)

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

                    GooseCharacterView(mood: gooseMood)
                    .scaleEffect(0.7)
                }

                Text(timer.displayTime)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                    .contentTransition(.numericText())

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

                HStack(spacing: 20) {
                    if timer.isRunning {
                        PillButton(title: "Pause", icon: "pause.fill", color: GoosieTheme.warmOrange) {
                            timer.pause()
                        }
                    } else if timer.isCompleted {
                        PillButton(title: "Done!", icon: "checkmark", color: GoosieTheme.happinessYellow) {
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

                if timer.isRunning {
                    VStack(spacing: 6) {
                        Text("Your goose is cheering you on!")
                            .font(GoosieTheme.captionFont())
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

                        Button {
                            showDistractionOverlay = true
                        } label: {
                            Text("I got distracted...")
                                .font(GoosieTheme.captionFont(12))
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.35))
                                .underline()
                        }
                    }
                }
            }
            .padding(GoosieTheme.padding)
        }
        .sheet(isPresented: $showDurationPicker) {
            durationPicker
        }
        .fullScreenCover(isPresented: $showDistractionOverlay) {
            DistractionOverlay()
        }
        // Start Live Activity when timer begins, end when session ends
        .onChange(of: timer.isRunning) { _, isRunning in
            guard let state = gooseState else { return }
            let manager = GooseLiveActivityManager.shared
            if isRunning {
                if !manager.isActive {
                    manager.startPetActivity(gooseName: state.name, state: state)
                }
                manager.startFocusMode(state: state, minutesRemaining: timer.remainingSeconds / 60)
            }
        }
        // Update the minute countdown every minute
        .onChange(of: timer.remainingSeconds / 60) { _, minutes in
            guard timer.isRunning, let state = gooseState else { return }
            GooseLiveActivityManager.shared.startFocusMode(state: state, minutesRemaining: minutes)
        }
        // End when session completes
        .onChange(of: timer.isCompleted) { _, completed in
            if completed { GooseLiveActivityManager.shared.endActivity() }
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

        GooseLiveActivityManager.shared.endActivity()
        timer.reset()
    }
}
