import SwiftUI
import SwiftData

struct DistractionOverlay: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Goal> { $0.isActive && !$0.isCompleted }, sort: \Goal.sortOrder)
    private var incompleteGoals: [Goal]

    @State private var elapsedSeconds = 0
    @State private var countdownTimer: Timer?

    private let cooldownSeconds = 60

    private var canDismiss: Bool { elapsedSeconds >= cooldownSeconds }
    private var progress: Double { min(1.0, Double(elapsedSeconds) / Double(cooldownSeconds)) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Countdown indicator
                Text(canDismiss ? "Time's up!" : "\(cooldownSeconds - elapsedSeconds)s")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                // Goose
                GooseCharacterView(mood: .sad)
                .frame(height: 160)
                .saturation(0.4)

                Text("Hey! Come back! 🪿")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("You still have these to do:")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))

                // Incomplete goals (up to 3)
                VStack(spacing: 8) {
                    ForEach(Array(incompleteGoals.prefix(3)), id: \.id) { goal in
                        HStack(spacing: 10) {
                            Image(systemName: goal.goalCategory.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 20)
                            Text(goal.title)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Progress bar or dismiss button
                if canDismiss {
                    PillButton(title: "OK, I'll do better!", icon: "checkmark", color: GoosieTheme.coralAccent) {
                        dismiss()
                    }
                } else {
                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.15))
                                Capsule().fill(GoosieTheme.coralAccent)
                                    .frame(width: geo.size.width * progress)
                                    .animation(.linear(duration: 1), value: progress)
                            }
                        }
                        .frame(height: 6)
                        .padding(.horizontal, 40)

                        Text("Please wait \(cooldownSeconds - elapsedSeconds) seconds")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Spacer().frame(height: 20)
            }
        }
        .onAppear(perform: startTracking)
        .onDisappear(perform: stopTracking)
    }

    // MARK: - Tracking

    private func startTracking() {
        let log = fetchOrCreateTodayLog()
        log.distractionOpens += 1

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
            if elapsedSeconds % 60 == 0 {
                let log = fetchOrCreateTodayLog()
                log.distractionMinutes += 1
                GooseEngine.shared.updateDistractMinutes(log.distractionMinutes)
            }
        }
    }

    private func stopTracking() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func fetchOrCreateTodayLog() -> DailyLog {
        let today = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == today }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let log = DailyLog(date: .now)
        modelContext.insert(log)
        return log
    }
}
