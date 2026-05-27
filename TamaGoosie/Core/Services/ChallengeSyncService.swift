// TamaGoosie/Core/Services/ChallengeSyncService.swift
import Foundation
import SwiftData
import Observation
import ConvexMobile

@Observable
@MainActor
final class ChallengeSyncService {
    static let shared = ChallengeSyncService()
    private init() {}

    private var convex: ConvexClient { ConvexManager.shared.client }

    // MARK: - Int → Double encoding boundary
    // Convex v.number() expects Float64. Swift Int encodes as Int64 → schema error.
    // Every Int that crosses into a mutation arg dict must go through this cast.
    private static func dbl(_ i: Int) -> Double { Double(i) }

    // MARK: - Pull templates

    struct TemplateDTO: Decodable {
        let templateId: String
        let title: String
        let blurb: String
        let category: String
        let shape: String
        let metric: String
        let windowDays: Double
        let tiers: Tiers
        let active: Bool
        let sortHint: Double
        struct Tier: Decodable { let target: Double; let coinReward: Double }
        struct Tiers: Decodable { let bronze: Tier; let silver: Tier; let gold: Tier }
    }

    func pullTemplates(into context: ModelContext) async {
        do {
            let dtos: [TemplateDTO] = try await ConvexManager.shared.queryOnce(
                "challengeTemplates:listActive"
            )
            for dto in dtos {
                guard let shape = ChallengeShape(rawValue: dto.shape),
                      let metric = ChallengeMetric(rawValue: dto.metric) else {
                    continue
                }
                let templateId = dto.templateId
                let descriptor = FetchDescriptor<ChallengeTemplate>(
                    predicate: #Predicate { $0.templateId == templateId }
                )
                if let existing = try? context.fetch(descriptor).first {
                    existing.title = dto.title
                    existing.blurb = dto.blurb
                    existing.shape = shape.rawValue
                    existing.metric = metric.rawValue
                    existing.windowDays = Int(dto.windowDays)
                    existing.bronzeTarget = dto.tiers.bronze.target
                    existing.bronzeReward = Int(dto.tiers.bronze.coinReward)
                    existing.silverTarget = dto.tiers.silver.target
                    existing.silverReward = Int(dto.tiers.silver.coinReward)
                    existing.goldTarget   = dto.tiers.gold.target
                    existing.goldReward   = Int(dto.tiers.gold.coinReward)
                    existing.isActive = dto.active
                    existing.sortHint = Int(dto.sortHint)
                } else {
                    let t = ChallengeTemplate(
                        templateId: dto.templateId, title: dto.title, blurb: dto.blurb,
                        category: dto.category, shape: shape, metric: metric,
                        windowDays: Int(dto.windowDays),
                        bronzeTarget: dto.tiers.bronze.target, bronzeReward: Int(dto.tiers.bronze.coinReward),
                        silverTarget: dto.tiers.silver.target, silverReward: Int(dto.tiers.silver.coinReward),
                        goldTarget:   dto.tiers.gold.target,   goldReward:   Int(dto.tiers.gold.coinReward),
                        isActive: dto.active, sortHint: Int(dto.sortHint)
                    )
                    context.insert(t)
                }
            }
            try? context.save()
        } catch {
            // Skip silently; render whatever's cached. Don't crash the tab.
        }
    }

    // MARK: - Pull runs

    struct RunDTO: Decodable {
        let runId: String
        let templateId: String
        let tier: String
        let startedAt: Double
        let expiresAt: Double
        let status: String
        let completedAt: Double?
        let coinsAwarded: Double?
        let targetSnapshot: Double
        let rewardSnapshot: Double
        let metricSnapshot: String
        let shapeSnapshot: String
        let windowDaysSnapshot: Double
    }

    func pullRuns(into context: ModelContext) async {
        guard let userId = ConvexManager.shared.currentUserId else { return }
        do {
            let dtos: [RunDTO] = try await ConvexManager.shared.queryOnce(
                "challengeRuns:listForUser", with: ["userId": userId]
            )
            for dto in dtos {
                let runId = dto.runId
                let descriptor = FetchDescriptor<ChallengeRun>(
                    predicate: #Predicate { $0.runId == runId }
                )
                if let existing = try? context.fetch(descriptor).first {
                    existing.status = dto.status
                    existing.completedAt = dto.completedAt.map { Date(timeIntervalSince1970: $0 / 1000) }
                    existing.coinsAwarded = dto.coinsAwarded.map { Int($0) }
                } else {
                    let run = ChallengeRun(
                        runId: dto.runId, templateId: dto.templateId,
                        tier: ChallengeTier(rawValue: dto.tier) ?? .bronze,
                        startedAt: Date(timeIntervalSince1970: dto.startedAt / 1000),
                        windowDays: Int(dto.windowDaysSnapshot),
                        targetSnapshot: dto.targetSnapshot,
                        rewardSnapshot: Int(dto.rewardSnapshot),
                        metricSnapshot: ChallengeMetric(rawValue: dto.metricSnapshot) ?? .steps,
                        shapeSnapshot: ChallengeShape(rawValue: dto.shapeSnapshot) ?? .cumulative
                    )
                    run.status = dto.status
                    run.completedAt = dto.completedAt.map { Date(timeIntervalSince1970: $0 / 1000) }
                    run.coinsAwarded = dto.coinsAwarded.map { Int($0) }
                    context.insert(run)
                }
            }
            try? context.save()
        } catch {
            // ignore; cached data renders
        }
    }

    // MARK: - Push run mutations
    // All mutations are fire-and-forget. If the network call fails, the next
    // pull reconciles. We swallow errors so the local UI stays responsive.

    func pushAccept(_ run: ChallengeRun) async {
        guard let userId = ConvexManager.shared.currentUserId else { return }
        let args: [String: ConvexEncodable?] = [
            "runId": run.runId,
            "userId": userId,
            "templateId": run.templateId,
            "tier": run.tier,
            "startedAt": run.startedAt.timeIntervalSince1970 * 1000,
            "expiresAt": run.expiresAt.timeIntervalSince1970 * 1000,
            "targetSnapshot": run.targetSnapshot,
            "rewardSnapshot": Self.dbl(run.rewardSnapshot),
            "metricSnapshot": run.metricSnapshot,
            "shapeSnapshot": run.shapeSnapshot,
            "windowDaysSnapshot": Self.dbl(run.windowDaysSnapshot),
        ]
        let _: String? = try? await convex.mutation("challengeRuns:accept", with: args)
    }

    func pushComplete(_ run: ChallengeRun) async {
        guard let userId = ConvexManager.shared.currentUserId,
              let completedAt = run.completedAt,
              let coinsAwarded = run.coinsAwarded else { return }
        let args: [String: ConvexEncodable?] = [
            "runId": run.runId,
            "userId": userId,
            "completedAt": completedAt.timeIntervalSince1970 * 1000,
            "coinsAwarded": Self.dbl(coinsAwarded),
        ]
        let _: String? = try? await convex.mutation("challengeRuns:complete", with: args)
    }

    func pushExpire(_ run: ChallengeRun) async {
        guard let userId = ConvexManager.shared.currentUserId else { return }
        let args: [String: ConvexEncodable?] = [
            "runId": run.runId,
            "userId": userId,
        ]
        let _: String? = try? await convex.mutation("challengeRuns:expire", with: args)
    }

    func pullAll(into context: ModelContext) async {
        await pullTemplates(into: context)
        await pullRuns(into: context)
    }
}
