// TamaGoosieTests/ChallengeEngineAcceptTests.swift
import Testing
import Foundation
import SwiftData
@testable import TamaGoosie

@MainActor
@Suite("ChallengeEngine.accept")
struct AcceptTests {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: ChallengeTemplate.self, ChallengeRun.self,
            configurations: config
        )
    }

    private func makeTemplate(
        id: String = "step-it-up",
        windowDays: Int = 7,
        isActive: Bool = true
    ) -> ChallengeTemplate {
        ChallengeTemplate(
            templateId: id,
            title: "Step It Up",
            blurb: "Walk more.",
            category: "health",
            shape: .cumulative,
            metric: .steps,
            windowDays: windowDays,
            bronzeTarget: 30_000, bronzeReward: 25,
            silverTarget: 50_000, silverReward: 60,
            goldTarget:   80_000, goldReward:   120
        )
    }

    @Test("First accept succeeds and inserts a new active run")
    func firstAcceptSucceeds() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let template = makeTemplate()
        context.insert(template)

        let now = Date(timeIntervalSince1970: 1_000_000)
        let run = try ChallengeEngine.accept(
            template: template,
            tier: .bronze,
            existingRuns: [],
            context: context,
            now: now
        )

        #expect(run.templateId == "step-it-up")
        #expect(run.tierEnum == .bronze)
        #expect(run.statusEnum == .active)
        #expect(run.startedAt == now)
        #expect(run.targetSnapshot == 30_000)
        #expect(run.rewardSnapshot == 25)
        #expect(run.metricEnum == .steps)
        #expect(run.shapeEnum == .cumulative)
        #expect(run.windowDaysSnapshot == 7)
    }

    @Test("Fourth active accept throws .capReached")
    func fourthAcceptThrowsCapReached() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let template = makeTemplate()
        context.insert(template)

        let now = Date(timeIntervalSince1970: 1_000_000)
        let active = (0..<3).map { i in
            ChallengeRun(
                templateId: "other-\(i)",
                tier: .bronze,
                startedAt: now,
                windowDays: 7,
                targetSnapshot: 1,
                rewardSnapshot: 1,
                metricSnapshot: .steps,
                shapeSnapshot: .cumulative
            )
        }

        #expect(throws: ChallengeError.capReached) {
            _ = try ChallengeEngine.accept(
                template: template,
                tier: .bronze,
                existingRuns: active,
                context: context,
                now: now
            )
        }
    }

    @Test("Disabled template throws .templateDisabled")
    func disabledTemplateThrows() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let template = makeTemplate()
        context.insert(template)
        template.isActive = false

        #expect(throws: ChallengeError.templateDisabled) {
            _ = try ChallengeEngine.accept(
                template: template,
                tier: .bronze,
                existingRuns: [],
                context: context,
                now: Date()
            )
        }
    }

    @Test("Expired run still in cooldown throws .inCooldown")
    func cooldownThrows() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let template = makeTemplate()
        context.insert(template)

        let now = Date(timeIntervalSince1970: 1_000_000)
        // Expired run: started 14d ago, windowDays=7 → expired 7d ago, cooldown ends now.
        let expired = ChallengeRun(
            templateId: "step-it-up",
            tier: .bronze,
            startedAt: now.addingTimeInterval(-14 * 86_400),
            windowDays: 7,
            targetSnapshot: 30_000,
            rewardSnapshot: 25,
            metricSnapshot: .steps,
            shapeSnapshot: .cumulative
        )
        expired.status = ChallengeStatus.expired.rawValue

        #expect(throws: ChallengeError.inCooldown) {
            _ = try ChallengeEngine.accept(
                template: template,
                tier: .bronze,
                existingRuns: [expired],
                context: context,
                now: now
            )
        }
    }
}
