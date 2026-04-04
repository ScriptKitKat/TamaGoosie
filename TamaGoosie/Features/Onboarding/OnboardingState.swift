import Foundation
import Observation

@Observable
final class OnboardingState {
    var gooseName: String = "Harold"
    var selectedGoals: Set<String> = []
    var healthAuthorized: Bool = false
    var notificationsAuthorized: Bool = false
}
