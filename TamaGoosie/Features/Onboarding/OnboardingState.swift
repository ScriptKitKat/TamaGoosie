import Foundation
import Observation

enum OnboardingEntryPath {
    case freshInstall
    case returningAccount
    case loggedOutReturn
}

@Observable
final class OnboardingState {
    var entryPath: OnboardingEntryPath = .freshInstall

    var gooseName: String = "Harold"
    var healthAuthorized: Bool = false
    var notificationsAuthorized: Bool = false
    var username: String = ""

    // Email sign-up fields
    var emailAddress: String = ""
    var emailPassword: String = ""
    var emailConfirmPassword: String = ""
    var agreedToTerms: Bool = false
    var choseEmailSignUp: Bool = false

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
