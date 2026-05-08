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

    private var displayName: String {
        obState.isReturningUser ? obState.restoredGooseName : obState.gooseName
    }

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Dancing goose
                GooseCharacterView(mood: .ecstatic)
                    .frame(height: 200)
                    .offset(y: danceOffset)
                    .rotationEffect(.degrees(danceRotation))
                    .onAppear {
                        startDance()
                        if !didCreate {
                            didCreate = true
                            if obState.isReturningUser {
                                restoreEntities()
                            } else {
                                createEntities()
                            }
                        }
                    }

                Spacer().frame(height: 28)

                if obState.isReturningUser {
                    Text("Welcome back!")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(OBTheme.text)

                    Text("\(displayName) missed you!")
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundStyle(OBTheme.secondary)
                        .padding(.top, 8)
                } else {
                    Text("You're all set!")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(OBTheme.text)

                    Text("\(displayName) is ready to go!")
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundStyle(OBTheme.secondary)
                        .padding(.top, 8)
                }

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

    // MARK: - SwiftData entity creation (new user)

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

        // Create goose with full stats for new users
        let goose = GooseState(
            name: gooseName,
            healthiness: 1.0,
            happiness: 1.0,
            mood: GooseMood.ecstatic.rawValue
        )
        goose.userProfile = profile
        modelContext.insert(goose)
        profile.gooseState = goose

        // Mark completion in UserDefaults
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        try? modelContext.save()

        // Schedule morning reminder
        NotificationManager.shared.scheduleMorningReminder(
            gooseName: gooseName,
            healthiness: goose.healthiness
        )
    }

    // MARK: - Restore entities from Convex (returning user)

    private func restoreEntities() {
        let gooseName = obState.restoredGooseName.isEmpty ? "Harold" : obState.restoredGooseName

        // Create profile
        let profile = UserProfile(
            displayName: gooseName,
            notificationsEnabled: obState.notificationsAuthorized,
            hasCompletedOnboarding: true
        )
        modelContext.insert(profile)

        // Create goose with restored stats
        let goose = GooseState(
            name: gooseName,
            healthiness: obState.restoredHealthiness,
            happiness: obState.restoredHappiness,
            mood: obState.restoredMood,
            streakDays: obState.restoredStreakDays
        )
        goose.spriteID = obState.restoredSpriteID
        goose.userProfile = profile
        modelContext.insert(goose)
        profile.gooseState = goose

        // Create goals from restored Convex data
        for convexGoal in obState.restoredGoals {
            let goal = Goal(
                title: convexGoal.title,
                type: convexGoal.type,
                category: GoalCategory(rawValue: convexGoal.category) ?? .custom,
                frequency: GoalFrequency(rawValue: convexGoal.frequency) ?? .daily,
                targetCount: convexGoal.targetCount,
                happinessWeight: convexGoal.happinessWeight,
                sortOrder: convexGoal.sortOrder
            )
            goal.isActive = convexGoal.isActive
            if let days = convexGoal.customDays {
                goal.customDays = days
            }
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
