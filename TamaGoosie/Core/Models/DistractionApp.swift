import Foundation
import SwiftData

@Model
final class DistractionApp {
    var id: UUID
    var bundleID: String
    var displayName: String
    var iconName: String?
    var dailyLimitMinutes: Int

    // Back-reference to owning UserProfile
    var userProfile: UserProfile?

    init(
        bundleID: String,
        displayName: String,
        iconName: String? = nil,
        dailyLimitMinutes: Int = 30
    ) {
        self.id = UUID()
        self.bundleID = bundleID
        self.displayName = displayName
        self.iconName = iconName
        self.dailyLimitMinutes = dailyLimitMinutes
    }
}
