import Foundation
import SwiftData

enum AppCategory: String, Codable, CaseIterable {
    case productive
    case neutral
    case distracting
}

@Model
final class DistractionApp {
    var id: UUID = UUID()
    var bundleID: String = ""
    var displayName: String = ""
    var iconName: String?
    var dailyLimitMinutes: Int = 30
    var categoryRaw: String = AppCategory.distracting.rawValue

    var category: AppCategory {
        get { AppCategory(rawValue: categoryRaw) ?? .distracting }
        set { categoryRaw = newValue.rawValue }
    }

    // Back-reference to owning UserProfile
    var userProfile: UserProfile?

    init(
        bundleID: String,
        displayName: String,
        iconName: String? = nil,
        dailyLimitMinutes: Int = 30,
        category: AppCategory = .distracting
    ) {
        self.id = UUID()
        self.bundleID = bundleID
        self.displayName = displayName
        self.iconName = iconName
        self.dailyLimitMinutes = dailyLimitMinutes
        self.categoryRaw = category.rawValue
    }
}
