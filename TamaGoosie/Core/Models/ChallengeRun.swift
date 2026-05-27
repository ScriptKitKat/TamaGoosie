// TamaGoosie/Core/Models/ChallengeRun.swift
import Foundation
import SwiftData

@Model
final class ChallengeRun {
    @Attribute(.unique) var runId: String
    var templateId: String
    var tier: String              // ChallengeTier rawValue
    var startedAt: Date
    var expiresAt: Date
    var status: String            // ChallengeStatus rawValue
    var completedAt: Date?
    var coinsAwarded: Int?

    // Snapshots — frozen at accept time so template edits don't change in-flight runs
    var targetSnapshot: Double
    var rewardSnapshot: Int
    var metricSnapshot: String
    var shapeSnapshot: String
    var windowDaysSnapshot: Int

    init(
        runId: String = UUID().uuidString,
        templateId: String,
        tier: ChallengeTier,
        startedAt: Date,
        windowDays: Int,
        targetSnapshot: Double,
        rewardSnapshot: Int,
        metricSnapshot: ChallengeMetric,
        shapeSnapshot: ChallengeShape
    ) {
        self.runId = runId
        self.templateId = templateId
        self.tier = tier.rawValue
        self.startedAt = startedAt
        self.expiresAt = startedAt.addingTimeInterval(Double(windowDays) * 86_400)
        self.status = ChallengeStatus.active.rawValue
        self.completedAt = nil
        self.coinsAwarded = nil
        self.targetSnapshot = targetSnapshot
        self.rewardSnapshot = rewardSnapshot
        self.metricSnapshot = metricSnapshot.rawValue
        self.shapeSnapshot = shapeSnapshot.rawValue
        self.windowDaysSnapshot = windowDays
    }

    var statusEnum: ChallengeStatus { ChallengeStatus(rawValue: status) ?? .active }
    var tierEnum: ChallengeTier { ChallengeTier(rawValue: tier) ?? .bronze }
    var metricEnum: ChallengeMetric { ChallengeMetric(rawValue: metricSnapshot) ?? .steps }
    var shapeEnum: ChallengeShape { ChallengeShape(rawValue: shapeSnapshot) ?? .cumulative }
}
