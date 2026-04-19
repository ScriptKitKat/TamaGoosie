import Foundation
import Observation

@Observable
final class OnboardingState {
    var gooseName: String = "Harold"
    var selectedGoals: Set<String> = []
    var healthAuthorized: Bool = false
    var notificationsAuthorized: Bool = false
    var username: String = ""

    // Device permission state (checked on container appear)
    var healthAlreadyAuthorized: Bool = false
    var notificationsAlreadyAuthorized: Bool = false

    // Returning user fields (populated from Convex after sign-in)
    var isReturningUser: Bool = false
    var restoredGooseName: String = ""
    var restoredHappiness: Double = 0.7
    var restoredHealthiness: Double = 0.8
    var restoredMood: String = "content"
    var restoredSpriteID: String = "default"
    var restoredStreakDays: Int = 0
    var restoredGoals: [ConvexGoal] = []
    var restoredConvexUserId: String = ""
    var restoredUsername: String = ""
}
