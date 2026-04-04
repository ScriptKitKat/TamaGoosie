import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var displayName: String?
    var joinDate: Date

    // Baselines (auto-calculated after first 7 days of data)
    var avgSleepHours: Double
    var avgSteps: Int
    var avgExerciseMinutes: Int
    var avgSittingHours: Double

    // Settings
    var notificationsEnabled: Bool
    var vacationMode: Bool
    var watchPaired: Bool
    var hasCompletedOnboarding: Bool

    // MARK: - Relationships (1:1 and 1:many owned by UserProfile)

    @Relationship(deleteRule: .cascade, inverse: \GooseState.userProfile)
    var gooseState: GooseState?

    @Relationship(deleteRule: .cascade, inverse: \Goal.userProfile)
    var goals: [Goal] = []

@Relationship(deleteRule: .cascade, inverse: \DistractionApp.userProfile)
    var distractionApps: [DistractionApp] = []

    init(
        displayName: String? = nil,
        avgSleepHours: Double = 8.0,
        avgSteps: Int = 6000,
        avgExerciseMinutes: Int = 30,
        avgSittingHours: Double = 8.0,
        notificationsEnabled: Bool = true,
        vacationMode: Bool = false,
        watchPaired: Bool = false,
        hasCompletedOnboarding: Bool = false
    ) {
        self.id = UUID()
        self.joinDate = .now
        self.displayName = displayName
        self.avgSleepHours = avgSleepHours
        self.avgSteps = avgSteps
        self.avgExerciseMinutes = avgExerciseMinutes
        self.avgSittingHours = avgSittingHours
        self.notificationsEnabled = notificationsEnabled
        self.vacationMode = vacationMode
        self.watchPaired = watchPaired
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}
