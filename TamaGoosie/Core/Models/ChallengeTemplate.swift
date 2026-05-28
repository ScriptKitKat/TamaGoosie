// TamaGoosie/Core/Models/ChallengeTemplate.swift
import Foundation
import SwiftData

@Model
final class ChallengeTemplate {
    @Attribute(.unique) var templateId: String
    var title: String
    var blurb: String
    var category: String        // "health"
    var shape: String           // ChallengeShape rawValue
    var metric: String          // ChallengeMetric rawValue
    var windowDays: Int

    // Tier values flattened — SwiftData doesn't model nested codable cleanly
    var bronzeTarget: Double
    var bronzeReward: Int
    var silverTarget: Double
    var silverReward: Int
    var goldTarget:   Double
    var goldReward:   Int

    var isActive: Bool
    var sortHint: Int

    init(
        templateId: String,
        title: String,
        blurb: String,
        category: String,
        shape: ChallengeShape,
        metric: ChallengeMetric,
        windowDays: Int,
        bronzeTarget: Double, bronzeReward: Int,
        silverTarget: Double, silverReward: Int,
        goldTarget:   Double, goldReward:   Int,
        isActive: Bool = true,
        sortHint: Int = 0
    ) {
        self.templateId = templateId
        self.title = title
        self.blurb = blurb
        self.category = category
        self.shape = shape.rawValue
        self.metric = metric.rawValue
        self.windowDays = windowDays
        self.bronzeTarget = bronzeTarget; self.bronzeReward = bronzeReward
        self.silverTarget = silverTarget; self.silverReward = silverReward
        self.goldTarget = goldTarget;     self.goldReward = goldReward
        self.isActive = isActive
        self.sortHint = sortHint
    }

    func target(for tier: ChallengeTier) -> Double {
        switch tier {
        case .bronze: return bronzeTarget
        case .silver: return silverTarget
        case .gold:   return goldTarget
        }
    }

    func reward(for tier: ChallengeTier) -> Int {
        switch tier {
        case .bronze: return bronzeReward
        case .silver: return silverReward
        case .gold:   return goldReward
        }
    }
}
