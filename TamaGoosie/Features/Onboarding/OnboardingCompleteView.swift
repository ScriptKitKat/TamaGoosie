import SwiftUI
import SwiftData

struct OnboardingCompleteView: View {
    let obState: OnboardingState
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var danceOffset: CGFloat = 0
    @State private var danceRotation: Double = 0
    @State private var showConfetti = false
    @State private var didCreate = false

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Dancing goose
                GooseCharacterView(mood: .ecstatic, phase: .baby)
                    .frame(height: 200)
                    .offset(y: danceOffset)
                    .rotationEffect(.degrees(danceRotation))
                    .onAppear {
                        startDance()
                        if !didCreate {
                            didCreate = true
                            createEntities()
                        }
                    }

                Spacer().frame(height: 28)

                Text("You're all set!")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)

                Text("\(obState.gooseName) is ready to go!")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(OBTheme.secondary)
                    .padding(.top, 8)

                Spacer()

                OBButton(title: "Let's go!", isEnabled: true, action: onComplete)
                    .padding(.bottom, 36)
            }
        }
    }

    // MARK: - Dance

    private func startDance() {
        let bounce = Animation.easeInOut(duration: 0.45).repeatForever(autoreverses: true)
        let twist  = Animation.easeInOut(duration: 0.60).repeatForever(autoreverses: true)
        withAnimation(bounce) { danceOffset = -14 }
        withAnimation(twist)  { danceRotation = 8 }
    }

    // MARK: - SwiftData entity creation

    private func createEntities() {
        let name = obState.gooseName.trimmingCharacters(in: .whitespaces)
        let gooseName = name.isEmpty ? "Harold" : name

        // Create profile
        let profile = UserProfile(
            displayName: gooseName,
            notificationsEnabled: obState.notificationsAuthorized,
            hasCompletedOnboarding: true
        )
        modelContext.insert(profile)

        // Create goose
        let goose = GooseState(name: gooseName)
        goose.userProfile = profile
        modelContext.insert(goose)
        profile.gooseState = goose

        // Create goals
        let goalDefs: [(String, GoalCategory)] = [
            ("Drink 8 glasses of water", .water),
            ("Take a 30-minute walk",    .fitness),
            ("Meditate for 10 minutes",  .mindfulness),
            ("Read for 20 minutes",      .learning),
            ("Stretch for 10 minutes",   .fitness),
            ("Journal before bed",       .mindfulness),
            ("Eat a healthy meal",       .health),
            ("Call a friend or family",  .social),
        ]

        for (idx, (title, category)) in goalDefs.enumerated() {
            guard obState.selectedGoals.contains(title) else { continue }
            let goal = Goal(
                title: title,
                type: "recurring",
                category: category,
                frequency: .daily,
                happinessWeight: 1.0,
                sortOrder: idx
            )
            goal.userProfile = profile
            modelContext.insert(goal)
            profile.goals.append(goal)
        }

        // Mark completion in UserDefaults
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        try? modelContext.save()

        // Schedule morning reminder
        NotificationManager.shared.scheduleMorningReminder(
            gooseName: gooseName,
            healthiness: goose.healthiness
        )
    }
}
