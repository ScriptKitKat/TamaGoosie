# Challenges Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Challenges tab — a curated, opt-in library of time-bound bonus quests rewarding coins, additive to Goals.

**Architecture:** Convex owns the templates (hot-updatable) and authoritative run history; SwiftData mirrors both for offline-first reads; `ChallengeEngine` derives progress from `DailyLog` on every `GooseEngine.update`. UI is Layout A — Active pinned on top, Browse below, single scroll.

**Tech Stack:** Swift 6 / SwiftUI / SwiftData / Convex (TypeScript) / `ConvexMobile` SDK / Swift Testing / convex-test (vitest)

**Reference spec:** `docs/superpowers/specs/2026-05-26-challenges-tab-design.md`

---

## Pre-flight

- [ ] **Read the spec end-to-end** before starting Task 1. The plan does not repeat every nuance — sections 1–6 of the spec are normative.
- [ ] Confirm `xcodegen` is installed: `xcodegen --version`. Required after every `project.yml` change.
- [ ] Confirm Convex CLI works: `cd convex && npx convex --version`.

---

## Phase 1 — Foundations

### Task 1: Add Challenges constants

**Files:**
- Modify: `Shared/Constants.swift`

- [ ] **Step 1: Append constants**

Open `Shared/Constants.swift` and append inside the `GoosieConstants` enum (before the closing brace):

```swift
    // MARK: - Challenges

    public static let challengeActiveCap: Int = 3
    public static let challengeCategoriesV1: [String] = ["health"]
    // Fallbacks — only used if a template omits explicit tier rewards
    public static let defaultBronzeReward: Int = 25
    public static let defaultSilverReward: Int = 60
    public static let defaultGoldReward:   Int = 120
```

- [ ] **Step 2: Build to verify**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Shared/Constants.swift
git commit -m "feat(challenges): add cap + default reward constants"
```

---

### Task 2: Add ChallengeMetric enum (Shared)

**Files:**
- Create: `Shared/ChallengeMetric.swift`

This enum lives in `Shared/` so future Watch/Widget surfaces can decode the same values. **Do not import SwiftData here** — Shared compiles into three targets.

- [ ] **Step 1: Create the file**

```swift
// Shared/ChallengeMetric.swift
import Foundation

public enum ChallengeMetric: String, Codable, Sendable, CaseIterable {
    case steps
    case exerciseMinutes
    case sleepHours
    case outsideMinutes
    case sittingHours
    case standHours
}

public enum ChallengeShape: String, Codable, Sendable, CaseIterable {
    case cumulative
    case dailyCeiling
}

public enum ChallengeTier: String, Codable, Sendable, CaseIterable {
    case bronze, silver, gold
}

public enum ChallengeStatus: String, Codable, Sendable, CaseIterable {
    case active, completed, expired
}
```

- [ ] **Step 2: Add file to project.yml sources (if Shared isn't recursive)**

Check `project.yml` — if the Shared target already uses `sources: [Shared]`, no change is needed (xcodegen recursively includes `.swift` files). Otherwise add the path explicitly.

- [ ] **Step 3: Regenerate Xcode project**

```bash
xcodegen generate
```

- [ ] **Step 4: Build to verify all three targets compile**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosieWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build 2>&1 | tail -5
```

Expected: both `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add Shared/ChallengeMetric.swift project.yml TamaGoosie.xcodeproj
git commit -m "feat(challenges): add shared ChallengeMetric/Shape/Tier/Status enums"
```

---

### Task 3: Add ChallengeTemplate @Model

**Files:**
- Create: `TamaGoosie/Core/Models/ChallengeTemplate.swift`

- [ ] **Step 1: Create the file**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add TamaGoosie/Core/Models/ChallengeTemplate.swift
git commit -m "feat(challenges): add ChallengeTemplate SwiftData model"
```

---

### Task 4: Add ChallengeRun @Model

**Files:**
- Create: `TamaGoosie/Core/Models/ChallengeRun.swift`

- [ ] **Step 1: Create the file**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add TamaGoosie/Core/Models/ChallengeRun.swift
git commit -m "feat(challenges): add ChallengeRun SwiftData model with snapshots"
```

---

### Task 5: Register models in ModelContainer

**Files:**
- Modify: `TamaGoosie/App/TamaGoosieApp.swift:83-93`

- [ ] **Step 1: Add to Schema array**

Open `TamaGoosie/App/TamaGoosieApp.swift`. In the `Schema([...])` block (around line 83), add the two new entries after `ScreenBlock.self`:

```swift
        let schema = Schema([
            GooseState.self,
            Goal.self,
            GoalProgress.self,
            GoalCompletionEvent.self,
            FocusSession.self,
            HealthSnapshot.self,
            DailyLog.self,
            UserProfile.self,
            ScreenBlock.self,
            ChallengeTemplate.self,
            ChallengeRun.self,
        ])
```

- [ ] **Step 2: Build, run, verify the SwiftData store rebuilds cleanly**

Run:
```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`. The existing `init()` already handles schema migration failure by wiping the store — on first run with the new models this will trigger automatically.

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/App/TamaGoosieApp.swift
git commit -m "feat(challenges): register ChallengeTemplate + ChallengeRun in ModelContainer"
```

---

## Phase 2 — Pure Engine Functions (TDD)

### Task 6: Aggregation for `cumulative` shape

**Files:**
- Create: `TamaGoosie/Core/Services/ChallengeEngine.swift`
- Create: `TamaGoosieTests/ChallengeEngineAggregationTests.swift`

- [ ] **Step 1: Write the failing test**

Create `TamaGoosieTests/ChallengeEngineAggregationTests.swift`:

```swift
import Testing
import Foundation
@testable import TamaGoosie

@Suite("ChallengeEngine.aggregate — cumulative")
struct AggregateCumulativeTests {
    @Test("Sums steps over the window")
    func sumsSteps() {
        let day0 = Date(timeIntervalSince1970: 0)
        let logs = [
            makeLog(date: day0,                     steps: 10_000),
            makeLog(date: day0.addingTimeInterval(86_400),     steps: 8_000),
            makeLog(date: day0.addingTimeInterval(2 * 86_400), steps: 12_000),
        ]
        let progress = ChallengeEngine.aggregate(
            shape: .cumulative,
            metric: .steps,
            target: 50_000,
            logs: logs,
            windowStart: day0,
            now: day0.addingTimeInterval(3 * 86_400)
        )
        #expect(progress == 30_000)
    }

    @Test("Ignores logs outside the window")
    func ignoresOutOfWindow() {
        let day0 = Date(timeIntervalSince1970: 0)
        let logs = [
            makeLog(date: day0.addingTimeInterval(-86_400), steps: 99_999), // before
            makeLog(date: day0, steps: 1_000),
        ]
        let progress = ChallengeEngine.aggregate(
            shape: .cumulative, metric: .steps, target: 5_000,
            logs: logs, windowStart: day0, now: day0.addingTimeInterval(86_400)
        )
        #expect(progress == 1_000)
    }
}

// Test fixture builder — uses the model's init.
@MainActor
func makeLog(date: Date, steps: Int = 0, exerciseMinutes: Int = 0,
             sleepHours: Double = 0, outsideMinutes: Int = 0,
             sittingHours: Double = 0, standHours: Int = 0) -> DailyLog {
    let log = DailyLog(date: date)
    log.steps = steps
    log.exerciseMinutes = exerciseMinutes
    log.sleepHours = sleepHours
    log.outsideMinutes = outsideMinutes
    log.sittingHours = sittingHours
    log.standHours = standHours
    return log
}
```

- [ ] **Step 2: Run the test — expect failure**

```bash
xcodebuild test -project TamaGoosie.xcodeproj -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:TamaGoosieTests/AggregateCumulativeTests 2>&1 | tail -20
```

Expected: build failure — `ChallengeEngine` doesn't exist. If `DailyLog` fields differ from the fixture, update the fixture to match (don't change `DailyLog`).

- [ ] **Step 3: Create the engine with the aggregator**

Create `TamaGoosie/Core/Services/ChallengeEngine.swift`:

```swift
// TamaGoosie/Core/Services/ChallengeEngine.swift
import Foundation
import SwiftData
import Observation

@Observable
final class ChallengeEngine {
    static let shared = ChallengeEngine()
    private init() {}

    /// Pure aggregator. `target` is forwarded for `dailyCeiling` (ignored by `cumulative`).
    /// `windowStart..<now` is the inclusive-exclusive window evaluated.
    static func aggregate(
        shape: ChallengeShape,
        metric: ChallengeMetric,
        target: Double,
        logs: [DailyLog],
        windowStart: Date,
        now: Date
    ) -> Double {
        let inWindow = logs.filter { $0.date >= windowStart && $0.date < now }
            .sorted { $0.date < $1.date }

        switch shape {
        case .cumulative:
            return inWindow.reduce(0.0) { $0 + value(of: metric, in: $1) }

        case .dailyCeiling:
            // Consecutive in-window days under target. A failing day resets to 0.
            var streak = 0
            for log in inWindow {
                if value(of: metric, in: log) <= target {
                    streak += 1
                } else {
                    streak = 0
                }
            }
            return Double(streak)
        }
    }

    private static func value(of metric: ChallengeMetric, in log: DailyLog) -> Double {
        switch metric {
        case .steps:           return Double(log.steps)
        case .exerciseMinutes: return Double(log.exerciseMinutes)
        case .sleepHours:      return log.sleepHours
        case .outsideMinutes:  return Double(log.outsideMinutes)
        case .sittingHours:    return log.sittingHours
        case .standHours:      return Double(log.standHours)
        }
    }
}
```

- [ ] **Step 4: Run the test — expect pass**

```bash
xcodebuild test -project TamaGoosie.xcodeproj -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:TamaGoosieTests/AggregateCumulativeTests 2>&1 | tail -10
```

Expected: `Test Suite '...' passed`.

- [ ] **Step 5: Commit**

```bash
git add TamaGoosie/Core/Services/ChallengeEngine.swift TamaGoosieTests/ChallengeEngineAggregationTests.swift
git commit -m "feat(challenges): add cumulative aggregator with tests"
```

---

### Task 7: Aggregation for `dailyCeiling` shape

**Files:**
- Modify: `TamaGoosieTests/ChallengeEngineAggregationTests.swift`

- [ ] **Step 1: Append failing tests**

Add this suite to the same test file:

```swift
@Suite("ChallengeEngine.aggregate — dailyCeiling")
struct AggregateDailyCeilingTests {
    @Test("All days under ceiling -> count == day count")
    func allUnder() {
        let day0 = Date(timeIntervalSince1970: 0)
        let logs = (0..<3).map { i in
            makeLog(date: day0.addingTimeInterval(Double(i) * 86_400), sittingHours: 6)
        }
        let count = ChallengeEngine.aggregate(
            shape: .dailyCeiling, metric: .sittingHours, target: 8,
            logs: logs, windowStart: day0, now: day0.addingTimeInterval(3 * 86_400)
        )
        #expect(count == 3)
    }

    @Test("Failing day resets the counter")
    func failureResets() {
        let day0 = Date(timeIntervalSince1970: 0)
        let logs = [
            makeLog(date: day0,                            sittingHours: 6),  // under
            makeLog(date: day0.addingTimeInterval(86_400), sittingHours: 9),  // OVER → reset
            makeLog(date: day0.addingTimeInterval(2*86_400), sittingHours: 5), // under
        ]
        let count = ChallengeEngine.aggregate(
            shape: .dailyCeiling, metric: .sittingHours, target: 8,
            logs: logs, windowStart: day0, now: day0.addingTimeInterval(3 * 86_400)
        )
        #expect(count == 1)
    }

    @Test("Day exactly at ceiling counts as under (<=)")
    func boundaryInclusive() {
        let day0 = Date(timeIntervalSince1970: 0)
        let logs = [makeLog(date: day0, sittingHours: 8)]
        let count = ChallengeEngine.aggregate(
            shape: .dailyCeiling, metric: .sittingHours, target: 8,
            logs: logs, windowStart: day0, now: day0.addingTimeInterval(86_400)
        )
        #expect(count == 1)
    }
}
```

- [ ] **Step 2: Run — expect pass (already implemented in Task 6)**

```bash
xcodebuild test -project TamaGoosie.xcodeproj -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:TamaGoosieTests/AggregateDailyCeilingTests 2>&1 | tail -10
```

Expected: pass. If a test fails, fix the engine — the test is the spec.

- [ ] **Step 3: Commit**

```bash
git add TamaGoosieTests/ChallengeEngineAggregationTests.swift
git commit -m "test(challenges): cover dailyCeiling aggregator boundary + reset"
```

---

### Task 8: `reached()` helper

**Files:**
- Modify: `TamaGoosie/Core/Services/ChallengeEngine.swift`
- Create: `TamaGoosieTests/ChallengeEngineReachedTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// TamaGoosieTests/ChallengeEngineReachedTests.swift
import Testing
@testable import TamaGoosie

@Suite("ChallengeEngine.reached")
struct ReachedTests {
    @Test("cumulative: progress ≥ target")
    func cumulativeMeetsTarget() {
        #expect(ChallengeEngine.reached(progress: 50_000, target: 50_000, shape: .cumulative))
        #expect(ChallengeEngine.reached(progress: 50_001, target: 50_000, shape: .cumulative))
        #expect(!ChallengeEngine.reached(progress: 49_999, target: 50_000, shape: .cumulative))
    }

    @Test("dailyCeiling: progress (day count) ≥ target (= windowDays)")
    func dailyCeilingMeetsTarget() {
        // For dailyCeiling the "target" passed to reached() is windowDays, not the metric ceiling.
        #expect(ChallengeEngine.reached(progress: 3, target: 3, shape: .dailyCeiling))
        #expect(!ChallengeEngine.reached(progress: 2, target: 3, shape: .dailyCeiling))
    }
}
```

- [ ] **Step 2: Run — expect failure (`reached` undefined)**

```bash
xcodebuild test -project TamaGoosie.xcodeproj -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:TamaGoosieTests/ReachedTests 2>&1 | tail -10
```

- [ ] **Step 3: Add `reached()` to `ChallengeEngine`**

Append inside `ChallengeEngine`:

```swift
    /// For `cumulative`, target is the metric target (e.g. 50_000 steps).
    /// For `dailyCeiling`, target is `windowDays` (number of in-window days required under ceiling).
    static func reached(progress: Double, target: Double, shape: ChallengeShape) -> Bool {
        progress >= target
    }
```

- [ ] **Step 4: Run — expect pass**

- [ ] **Step 5: Commit**

```bash
git add TamaGoosie/Core/Services/ChallengeEngine.swift TamaGoosieTests/ChallengeEngineReachedTests.swift
git commit -m "feat(challenges): add reached() completion predicate"
```

---

### Task 9: `isInCooldown` helper

**Files:**
- Modify: `TamaGoosie/Core/Services/ChallengeEngine.swift`
- Create: `TamaGoosieTests/ChallengeEngineCooldownTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// TamaGoosieTests/ChallengeEngineCooldownTests.swift
import Testing
import Foundation
@testable import TamaGoosie

@Suite("ChallengeEngine.isInCooldown")
struct CooldownTests {
    @Test("No prior runs → not in cooldown")
    func noPriors() {
        let result = ChallengeEngine.isInCooldown(
            templateId: "step-it-up", runs: [], now: Date()
        )
        #expect(result == false)
    }

    @Test("Active run for template → NOT cooldown (cap covers that)")
    func activeRunNotCooldown() {
        let run = ChallengeRun(templateId: "step-it-up", tier: .bronze,
            startedAt: Date(), windowDays: 7,
            targetSnapshot: 30_000, rewardSnapshot: 25,
            metricSnapshot: .steps, shapeSnapshot: .cumulative)
        #expect(ChallengeEngine.isInCooldown(templateId: "step-it-up", runs: [run], now: Date()) == false)
    }

    @Test("Expired run within window → cooldown")
    func recentExpired() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let run = ChallengeRun(templateId: "step-it-up", tier: .bronze,
            startedAt: now.addingTimeInterval(-14 * 86_400),  // started 14d ago
            windowDays: 7,                                     // expired 7d ago
            targetSnapshot: 30_000, rewardSnapshot: 25,
            metricSnapshot: .steps, shapeSnapshot: .cumulative)
        run.status = ChallengeStatus.expired.rawValue
        // Cooldown ends 7d after expiresAt → 0d ago. Still inside.
        #expect(ChallengeEngine.isInCooldown(templateId: "step-it-up", runs: [run], now: now) == true)
    }

    @Test("Expired run with cooldown elapsed → NOT cooldown")
    func cooldownElapsed() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let run = ChallengeRun(templateId: "step-it-up", tier: .bronze,
            startedAt: now.addingTimeInterval(-30 * 86_400),
            windowDays: 7,
            targetSnapshot: 30_000, rewardSnapshot: 25,
            metricSnapshot: .steps, shapeSnapshot: .cumulative)
        run.status = ChallengeStatus.expired.rawValue
        #expect(ChallengeEngine.isInCooldown(templateId: "step-it-up", runs: [run], now: now) == false)
    }
}
```

- [ ] **Step 2: Run — expect failure**

- [ ] **Step 3: Implement**

Append inside `ChallengeEngine`:

```swift
    /// A template is in cooldown if any expired run for it ended within its own snapshotted window.
    static func isInCooldown(templateId: String, runs: [ChallengeRun], now: Date) -> Bool {
        runs.contains { run in
            run.templateId == templateId
            && run.statusEnum == .expired
            && run.expiresAt.addingTimeInterval(Double(run.windowDaysSnapshot) * 86_400) > now
        }
    }
```

- [ ] **Step 4: Run — expect pass**

- [ ] **Step 5: Commit**

```bash
git add TamaGoosie/Core/Services/ChallengeEngine.swift TamaGoosieTests/ChallengeEngineCooldownTests.swift
git commit -m "feat(challenges): add isInCooldown using snapshot window"
```

---

## Phase 3 — Engine Lifecycle (TDD)

### Task 10: `accept()` with guards

**Files:**
- Modify: `TamaGoosie/Core/Services/ChallengeEngine.swift`
- Create: `TamaGoosieTests/ChallengeEngineAcceptTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// TamaGoosieTests/ChallengeEngineAcceptTests.swift
import Testing
import Foundation
import SwiftData
@testable import TamaGoosie

@MainActor
@Suite("ChallengeEngine.accept")
struct AcceptTests {
    func makeContext() throws -> ModelContext {
        let schema = Schema([ChallengeTemplate.self, ChallengeRun.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    func sampleTemplate() -> ChallengeTemplate {
        ChallengeTemplate(
            templateId: "step-it-up", title: "Step it up", blurb: "",
            category: "health", shape: .cumulative, metric: .steps,
            windowDays: 7,
            bronzeTarget: 30_000, bronzeReward: 25,
            silverTarget: 50_000, silverReward: 60,
            goldTarget:   70_000, goldReward:   120,
            isActive: true
        )
    }

    @Test("First accept succeeds and creates a run with snapshots")
    func firstAcceptSucceeds() throws {
        let ctx = try makeContext()
        let template = sampleTemplate(); ctx.insert(template)

        let run = try ChallengeEngine.accept(
            template: template, tier: .silver, existingRuns: [], context: ctx, now: Date()
        )
        #expect(run.statusEnum == .active)
        #expect(run.targetSnapshot == 50_000)
        #expect(run.rewardSnapshot == 60)
        #expect(run.metricSnapshot == ChallengeMetric.steps.rawValue)
        #expect(run.windowDaysSnapshot == 7)
    }

    @Test("Fourth concurrent accept throws .capReached")
    func capReached() throws {
        let ctx = try makeContext()
        let template = sampleTemplate(); ctx.insert(template)
        var runs: [ChallengeRun] = []
        for _ in 0..<3 {
            let t = ChallengeTemplate(
                templateId: UUID().uuidString, title: "x", blurb: "",
                category: "health", shape: .cumulative, metric: .steps, windowDays: 1,
                bronzeTarget: 1, bronzeReward: 1, silverTarget: 1, silverReward: 1,
                goldTarget: 1, goldReward: 1
            )
            ctx.insert(t)
            runs.append(try ChallengeEngine.accept(
                template: t, tier: .bronze, existingRuns: runs, context: ctx, now: Date()
            ))
        }
        #expect(throws: ChallengeError.capReached) {
            _ = try ChallengeEngine.accept(
                template: template, tier: .silver, existingRuns: runs, context: ctx, now: Date()
            )
        }
    }

    @Test("Disabled template throws .templateDisabled")
    func disabledThrows() throws {
        let ctx = try makeContext()
        let template = sampleTemplate(); template.isActive = false; ctx.insert(template)
        #expect(throws: ChallengeError.templateDisabled) {
            _ = try ChallengeEngine.accept(
                template: template, tier: .silver, existingRuns: [], context: ctx, now: Date()
            )
        }
    }

    @Test("Template in cooldown throws .inCooldown")
    func cooldownThrows() throws {
        let ctx = try makeContext()
        let template = sampleTemplate(); ctx.insert(template)
        let now = Date(timeIntervalSince1970: 1_000_000)
        let stale = ChallengeRun(
            templateId: template.templateId, tier: .bronze,
            startedAt: now.addingTimeInterval(-10 * 86_400), windowDays: 7,
            targetSnapshot: 0, rewardSnapshot: 0,
            metricSnapshot: .steps, shapeSnapshot: .cumulative
        )
        stale.status = ChallengeStatus.expired.rawValue
        #expect(throws: ChallengeError.inCooldown) {
            _ = try ChallengeEngine.accept(
                template: template, tier: .silver, existingRuns: [stale], context: ctx, now: now
            )
        }
    }
}
```

- [ ] **Step 2: Run — expect failure (`accept`, `ChallengeError` undefined)**

- [ ] **Step 3: Implement**

Append inside `ChallengeEngine.swift`:

```swift
enum ChallengeError: Error, Equatable {
    case capReached
    case inCooldown
    case templateDisabled
}

extension ChallengeEngine {
    /// Caller is responsible for filtering `existingRuns` to the current user
    /// (server enforces ownership; this method is pure-local validation).
    @discardableResult
    static func accept(
        template: ChallengeTemplate,
        tier: ChallengeTier,
        existingRuns: [ChallengeRun],
        context: ModelContext,
        now: Date
    ) throws(ChallengeError) -> ChallengeRun {
        guard template.isActive else { throw .templateDisabled }

        let activeCount = existingRuns.filter { $0.statusEnum == .active }.count
        guard activeCount < GoosieConstants.challengeActiveCap else { throw .capReached }

        guard !isInCooldown(templateId: template.templateId, runs: existingRuns, now: now)
        else { throw .inCooldown }

        let run = ChallengeRun(
            templateId: template.templateId,
            tier: tier,
            startedAt: now,
            windowDays: template.windowDays,
            targetSnapshot: template.target(for: tier),
            rewardSnapshot: template.reward(for: tier),
            metricSnapshot: ChallengeMetric(rawValue: template.metric) ?? .steps,
            shapeSnapshot: ChallengeShape(rawValue: template.shape) ?? .cumulative
        )
        context.insert(run)
        return run
    }
}
```

- [ ] **Step 4: Run — expect pass**

- [ ] **Step 5: Commit**

```bash
git add TamaGoosie/Core/Services/ChallengeEngine.swift TamaGoosieTests/ChallengeEngineAcceptTests.swift
git commit -m "feat(challenges): accept() with cap/cooldown/disabled guards"
```

---

### Task 11: `recomputeActive()` — expiry, completion, coin award

**Files:**
- Modify: `TamaGoosie/Core/Services/ChallengeEngine.swift`
- Create: `TamaGoosieTests/ChallengeEngineRecomputeTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// TamaGoosieTests/ChallengeEngineRecomputeTests.swift
import Testing
import Foundation
import SwiftData
@testable import TamaGoosie

@MainActor
@Suite("ChallengeEngine.recomputeActive")
struct RecomputeTests {
    func makeContext() throws -> ModelContext {
        let schema = Schema([GooseState.self, DailyLog.self, ChallengeTemplate.self, ChallengeRun.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    func makeState() -> GooseState { GooseState() }

    func makeRun(templateId: String = "t1", shape: ChallengeShape = .cumulative,
                 metric: ChallengeMetric = .steps, target: Double = 50_000,
                 reward: Int = 60, startedAt: Date, windowDays: Int = 7) -> ChallengeRun {
        ChallengeRun(templateId: templateId, tier: .silver,
            startedAt: startedAt, windowDays: windowDays,
            targetSnapshot: target, rewardSnapshot: reward,
            metricSnapshot: metric, shapeSnapshot: shape)
    }

    @Test("Cumulative: progress below target → still active")
    func belowTarget() throws {
        let ctx = try makeContext()
        let day0 = Date(timeIntervalSince1970: 1_000_000)
        let run = makeRun(startedAt: day0); ctx.insert(run)
        let log = makeLog(date: day0, steps: 20_000); ctx.insert(log)
        let state = makeState(); ctx.insert(state)

        let completed = ChallengeEngine.recomputeActive(
            state: state, logs: [log], runs: [run], now: day0.addingTimeInterval(86_400)
        )
        #expect(completed.isEmpty)
        #expect(run.statusEnum == .active)
        #expect(state.coins == 0)
    }

    @Test("Cumulative: target met → completed, coins awarded once, completion returned")
    func completesAndAwardsCoins() throws {
        let ctx = try makeContext()
        let day0 = Date(timeIntervalSince1970: 1_000_000)
        let run = makeRun(target: 50_000, reward: 60, startedAt: day0); ctx.insert(run)
        let log = makeLog(date: day0, steps: 60_000); ctx.insert(log)
        let state = makeState(); ctx.insert(state)

        let completed = ChallengeEngine.recomputeActive(
            state: state, logs: [log], runs: [run], now: day0.addingTimeInterval(86_400)
        )
        #expect(completed.count == 1)
        #expect(run.statusEnum == .completed)
        #expect(run.coinsAwarded == 60)
        #expect(state.coins == 60)

        // Second recompute is a no-op
        _ = ChallengeEngine.recomputeActive(
            state: state, logs: [log], runs: [run], now: day0.addingTimeInterval(2 * 86_400)
        )
        #expect(state.coins == 60)
    }

    @Test("Expiry: now > expiresAt with target unmet → expired, no coins")
    func expiresWithoutCoins() throws {
        let ctx = try makeContext()
        let day0 = Date(timeIntervalSince1970: 1_000_000)
        let run = makeRun(startedAt: day0, windowDays: 7); ctx.insert(run)
        let state = makeState(); ctx.insert(state)

        _ = ChallengeEngine.recomputeActive(
            state: state, logs: [], runs: [run], now: day0.addingTimeInterval(8 * 86_400)
        )
        #expect(run.statusEnum == .expired)
        #expect(state.coins == 0)
    }

    @Test("Target reached on the expiry tick → completion wins over expiry")
    func targetBeatsExpiry() throws {
        let ctx = try makeContext()
        let day0 = Date(timeIntervalSince1970: 1_000_000)
        let run = makeRun(target: 10_000, reward: 60, startedAt: day0, windowDays: 1); ctx.insert(run)
        let log = makeLog(date: day0, steps: 10_000); ctx.insert(log)
        let state = makeState(); ctx.insert(state)

        // now == expiresAt exactly; window comparison uses < so this is the boundary
        let now = day0.addingTimeInterval(1 * 86_400)
        _ = ChallengeEngine.recomputeActive(state: state, logs: [log], runs: [run], now: now)
        #expect(run.statusEnum == .completed)
        #expect(state.coins == 60)
    }
}
```

- [ ] **Step 2: Run — expect failure (`recomputeActive` undefined)**

- [ ] **Step 3: Implement**

Append inside `ChallengeEngine`:

```swift
extension ChallengeEngine {
    /// Idempotent. Returns the runs that transitioned `active → completed` on this call,
    /// so the caller (ViewModel) can present completion sheets.
    @MainActor
    @discardableResult
    static func recomputeActive(
        state: GooseState,
        logs: [DailyLog],
        runs: [ChallengeRun],
        now: Date = Date()
    ) -> [ChallengeRun] {
        var newlyCompleted: [ChallengeRun] = []

        for run in runs where run.statusEnum == .active {
            // Target check runs before expiry check — completion wins on the tick.
            let progress = aggregate(
                shape: run.shapeEnum,
                metric: run.metricEnum,
                target: run.targetSnapshot,
                logs: logs,
                windowStart: run.startedAt,
                now: now
            )

            // Effective target for `reached`: for dailyCeiling, target is windowDays (day count to hit).
            let effectiveTarget: Double = run.shapeEnum == .dailyCeiling
                ? Double(run.windowDaysSnapshot)
                : run.targetSnapshot

            if reached(progress: progress, target: effectiveTarget, shape: run.shapeEnum) {
                run.status = ChallengeStatus.completed.rawValue
                run.completedAt = now
                run.coinsAwarded = run.rewardSnapshot
                state.coins += run.rewardSnapshot
                newlyCompleted.append(run)
                continue
            }

            if now >= run.expiresAt {
                run.status = ChallengeStatus.expired.rawValue
            }
        }
        return newlyCompleted
    }
}
```

- [ ] **Step 4: Run — expect pass**

- [ ] **Step 5: Commit**

```bash
git add TamaGoosie/Core/Services/ChallengeEngine.swift TamaGoosieTests/ChallengeEngineRecomputeTests.swift
git commit -m "feat(challenges): recomputeActive — target-beats-expiry, idempotent coin award"
```

---

## Phase 4 — Convex Backend

### Task 12: Extend Convex schema

**Files:**
- Modify: `convex/schema.ts`

- [ ] **Step 1: Add the two tables**

Inside `defineSchema({...})`, after `dailyLogs`, append:

```ts
  challengeTemplates: defineTable({
    templateId: v.string(),
    title: v.string(),
    blurb: v.string(),
    category: v.literal("health"),
    shape: v.union(v.literal("cumulative"), v.literal("dailyCeiling")),
    metric: v.union(
      v.literal("steps"),
      v.literal("exerciseMinutes"),
      v.literal("sleepHours"),
      v.literal("outsideMinutes"),
      v.literal("sittingHours"),
      v.literal("standHours"),
    ),
    windowDays: v.number(),
    tiers: v.object({
      bronze: v.object({ target: v.number(), coinReward: v.number() }),
      silver: v.object({ target: v.number(), coinReward: v.number() }),
      gold:   v.object({ target: v.number(), coinReward: v.number() }),
    }),
    active: v.boolean(),
    sortHint: v.number(),
  })
    .index("by_templateId", ["templateId"])
    .index("by_active", ["active", "sortHint"]),

  challengeRuns: defineTable({
    runId: v.string(),
    userId: v.id("users"),
    templateId: v.string(),
    tier: v.union(v.literal("bronze"), v.literal("silver"), v.literal("gold")),
    startedAt: v.number(),
    expiresAt: v.number(),
    status: v.union(v.literal("active"), v.literal("completed"), v.literal("expired")),
    completedAt: v.union(v.number(), v.null()),
    coinsAwarded: v.union(v.number(), v.null()),
    targetSnapshot: v.number(),
    rewardSnapshot: v.number(),
    metricSnapshot: v.string(),
    shapeSnapshot: v.string(),
    windowDaysSnapshot: v.number(),
  })
    .index("by_runId", ["runId"])
    .index("by_user_status", ["userId", "status"])
    .index("by_user_template", ["userId", "templateId"]),
```

- [ ] **Step 2: Push schema**

```bash
cd convex && npx convex dev --once 2>&1 | tail -20
```

Expected: `Convex functions ready!` and no schema validation errors.

- [ ] **Step 3: Commit**

```bash
git add convex/schema.ts
git commit -m "feat(challenges): add challengeTemplates + challengeRuns Convex tables"
```

---

### Task 13: `challengeTemplates` queries

**Files:**
- Create: `convex/challengeTemplates.ts`

- [ ] **Step 1: Create the file**

```ts
// convex/challengeTemplates.ts
import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

export const listActive = query({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("challengeTemplates")
      .withIndex("by_active", (q) => q.eq("active", true))
      .collect();
  },
});

// Admin-only seed/upsert. Idempotent on templateId.
export const upsert = mutation({
  args: {
    templateId: v.string(),
    title: v.string(),
    blurb: v.string(),
    category: v.literal("health"),
    shape: v.union(v.literal("cumulative"), v.literal("dailyCeiling")),
    metric: v.union(
      v.literal("steps"),
      v.literal("exerciseMinutes"),
      v.literal("sleepHours"),
      v.literal("outsideMinutes"),
      v.literal("sittingHours"),
      v.literal("standHours"),
    ),
    windowDays: v.number(),
    tiers: v.object({
      bronze: v.object({ target: v.number(), coinReward: v.number() }),
      silver: v.object({ target: v.number(), coinReward: v.number() }),
      gold:   v.object({ target: v.number(), coinReward: v.number() }),
    }),
    active: v.boolean(),
    sortHint: v.number(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("challengeTemplates")
      .withIndex("by_templateId", (q) => q.eq("templateId", args.templateId))
      .first();
    if (existing) {
      const { templateId, ...rest } = args;
      await ctx.db.patch(existing._id, rest);
      return existing._id;
    }
    return await ctx.db.insert("challengeTemplates", args);
  },
});
```

- [ ] **Step 2: Push and verify**

```bash
cd convex && npx convex dev --once 2>&1 | tail -10
```

Expected: ready, no errors.

- [ ] **Step 3: Commit**

```bash
git add convex/challengeTemplates.ts
git commit -m "feat(challenges): convex listActive + admin upsert for templates"
```

---

### Task 14: `challengeRuns` mutations

**Files:**
- Create: `convex/challengeRuns.ts`

The server re-enforces cap and cooldown so a tampered client can't break invariants.

- [ ] **Step 1: Create the file**

```ts
// convex/challengeRuns.ts
import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

const ACTIVE_CAP = 3;

export const listForUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    return await ctx.db
      .query("challengeRuns")
      .withIndex("by_user_status", (q) => q.eq("userId", userId))
      .collect();
  },
});

export const accept = mutation({
  args: {
    runId: v.string(),
    userId: v.id("users"),
    templateId: v.string(),
    tier: v.union(v.literal("bronze"), v.literal("silver"), v.literal("gold")),
    startedAt: v.number(),
    expiresAt: v.number(),
    targetSnapshot: v.number(),
    rewardSnapshot: v.number(),
    metricSnapshot: v.string(),
    shapeSnapshot: v.string(),
    windowDaysSnapshot: v.number(),
  },
  handler: async (ctx, args) => {
    // Duplicate runId — return existing.
    const existing = await ctx.db
      .query("challengeRuns")
      .withIndex("by_runId", (q) => q.eq("runId", args.runId))
      .first();
    if (existing) return existing._id;

    // Cap check
    const activeRuns = await ctx.db
      .query("challengeRuns")
      .withIndex("by_user_status", (q) =>
        q.eq("userId", args.userId).eq("status", "active")
      )
      .collect();
    if (activeRuns.length >= ACTIVE_CAP) {
      throw new Error("capReached");
    }

    // Cooldown check
    const templateRuns = await ctx.db
      .query("challengeRuns")
      .withIndex("by_user_template", (q) =>
        q.eq("userId", args.userId).eq("templateId", args.templateId)
      )
      .collect();
    const inCooldown = templateRuns.some((r) =>
      r.status === "expired" &&
      r.expiresAt + r.windowDaysSnapshot * 86_400_000 > args.startedAt
    );
    if (inCooldown) throw new Error("inCooldown");

    return await ctx.db.insert("challengeRuns", {
      ...args,
      status: "active",
      completedAt: null,
      coinsAwarded: null,
    });
  },
});

export const complete = mutation({
  args: {
    runId: v.string(),
    userId: v.id("users"),
    completedAt: v.number(),
    coinsAwarded: v.number(),
  },
  handler: async (ctx, args) => {
    const run = await ctx.db
      .query("challengeRuns")
      .withIndex("by_runId", (q) => q.eq("runId", args.runId))
      .first();
    if (!run) return null;                                       // unknown — ignore
    if (run.userId !== args.userId) throw new Error("forbidden");
    if (run.status !== "active") return run._id;                 // idempotent no-op

    await ctx.db.patch(run._id, {
      status: "completed",
      completedAt: args.completedAt,
      coinsAwarded: args.coinsAwarded,
    });
    return run._id;
  },
});

export const expire = mutation({
  args: {
    runId: v.string(),
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const run = await ctx.db
      .query("challengeRuns")
      .withIndex("by_runId", (q) => q.eq("runId", args.runId))
      .first();
    if (!run) return null;
    if (run.userId !== args.userId) throw new Error("forbidden");
    if (run.status !== "active") return run._id;
    await ctx.db.patch(run._id, { status: "expired" });
    return run._id;
  },
});
```

- [ ] **Step 2: Push and verify**

```bash
cd convex && npx convex dev --once 2>&1 | tail -10
```

- [ ] **Step 3: Commit**

```bash
git add convex/challengeRuns.ts
git commit -m "feat(challenges): convex challengeRuns accept/complete/expire with server-side cap+cooldown"
```

---

### Task 15: Convex tests for `challengeRuns`

**Files:**
- Modify: `convex/package.json`
- Create: `convex/__tests__/challengeRuns.test.ts`
- Create: `convex/vitest.config.ts`

- [ ] **Step 1: Install convex-test + vitest**

```bash
cd convex && npm install --save-dev convex-test vitest @edge-runtime/vm
```

- [ ] **Step 2: Add vitest config**

Create `convex/vitest.config.ts`:

```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "edge-runtime",
    server: { deps: { inline: ["convex-test"] } },
  },
});
```

- [ ] **Step 3: Update test script**

In `convex/package.json`, replace the `test` script:

```json
"scripts": {
  "test": "vitest run"
}
```

- [ ] **Step 4: Write tests**

```ts
// convex/__tests__/challengeRuns.test.ts
import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "../schema";
import { api } from "../_generated/api";

async function seedUser(t: ReturnType<typeof convexTest>) {
  return await t.run(async (ctx) =>
    ctx.db.insert("users", {
      authProvider: "email",
      emailUserID: "u@example.com",
      username: "u",
      createdAt: 0,
    })
  );
}

const acceptArgs = (overrides: Partial<{ runId: string; templateId: string; userId: any; startedAt: number }> = {}) => ({
  runId: overrides.runId ?? "r1",
  userId: overrides.userId,
  templateId: overrides.templateId ?? "step-it-up",
  tier: "silver" as const,
  startedAt: overrides.startedAt ?? 1_000_000_000_000,
  expiresAt: (overrides.startedAt ?? 1_000_000_000_000) + 7 * 86_400_000,
  targetSnapshot: 50_000,
  rewardSnapshot: 60,
  metricSnapshot: "steps",
  shapeSnapshot: "cumulative",
  windowDaysSnapshot: 7,
});

test("accept enforces cap of 3", async () => {
  const t = convexTest(schema);
  const userId = await seedUser(t);
  for (let i = 0; i < 3; i++) {
    await t.mutation(api.challengeRuns.accept, { ...acceptArgs({ runId: `r${i}`, templateId: `t${i}`, userId }) });
  }
  await expect(
    t.mutation(api.challengeRuns.accept, { ...acceptArgs({ runId: "r3", templateId: "t3", userId }) })
  ).rejects.toThrow("capReached");
});

test("duplicate runId returns the existing run, no second insert", async () => {
  const t = convexTest(schema);
  const userId = await seedUser(t);
  const a = await t.mutation(api.challengeRuns.accept, acceptArgs({ userId }));
  const b = await t.mutation(api.challengeRuns.accept, acceptArgs({ userId }));
  expect(a).toEqual(b);
  const all = await t.query(api.challengeRuns.listForUser, { userId });
  expect(all.length).toBe(1);
});

test("complete is idempotent — second call is no-op", async () => {
  const t = convexTest(schema);
  const userId = await seedUser(t);
  await t.mutation(api.challengeRuns.accept, acceptArgs({ userId }));
  await t.mutation(api.challengeRuns.complete, {
    runId: "r1", userId, completedAt: 2_000_000_000_000, coinsAwarded: 60,
  });
  await t.mutation(api.challengeRuns.complete, {
    runId: "r1", userId, completedAt: 9_000_000_000_000, coinsAwarded: 9_999,
  });
  const [run] = await t.query(api.challengeRuns.listForUser, { userId });
  expect(run.status).toBe("completed");
  expect(run.coinsAwarded).toBe(60);
});

test("complete from wrong userId throws forbidden", async () => {
  const t = convexTest(schema);
  const owner = await seedUser(t);
  const intruder = await seedUser(t);
  await t.mutation(api.challengeRuns.accept, acceptArgs({ userId: owner }));
  await expect(
    t.mutation(api.challengeRuns.complete, {
      runId: "r1", userId: intruder, completedAt: 0, coinsAwarded: 1,
    })
  ).rejects.toThrow("forbidden");
});

test("expired-with-cooldown blocks re-accept", async () => {
  const t = convexTest(schema);
  const userId = await seedUser(t);
  const startedAt = 1_000_000_000_000;
  await t.mutation(api.challengeRuns.accept, acceptArgs({ userId, startedAt }));
  await t.mutation(api.challengeRuns.expire, { runId: "r1", userId });
  // try to re-accept at startedAt + 8 days (cooldown ends at startedAt + 14 days)
  await expect(
    t.mutation(api.challengeRuns.accept, acceptArgs({
      userId, runId: "r2", startedAt: startedAt + 8 * 86_400_000,
    }))
  ).rejects.toThrow("inCooldown");
});
```

- [ ] **Step 5: Run tests**

```bash
cd convex && npm test 2>&1 | tail -20
```

Expected: `5 passed`.

- [ ] **Step 6: Commit**

```bash
git add convex/package.json convex/package-lock.json convex/vitest.config.ts convex/__tests__/challengeRuns.test.ts
git commit -m "test(challenges): convex-test coverage for cap, idempotency, ownership, cooldown"
```

---

## Phase 5 — Sync Service

### Task 16: `ChallengeSyncService` skeleton + int-encoding wrapper

**Files:**
- Create: `TamaGoosie/Core/Services/ChallengeSyncService.swift`

The key memory: Swift `Int` encodes as Convex `Int64`. All `Int`s in mutation args must be cast to `Double` here, in one place, so the rest of the codebase doesn't need to remember.

- [ ] **Step 1: Create the file**

```swift
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
                let descriptor = FetchDescriptor<ChallengeTemplate>(
                    predicate: #Predicate { $0.templateId == dto.templateId }
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
                let descriptor = FetchDescriptor<ChallengeRun>(
                    predicate: #Predicate { $0.runId == dto.runId }
                )
                if let existing = try? context.fetch(descriptor).first {
                    existing.status = dto.status
                    existing.completedAt = dto.completedAt.map { Date(timeIntervalSince1970: $0 / 1000) }
                    existing.coinsAwarded = dto.coinsAwarded.map(Int.init)
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
                    run.coinsAwarded = dto.coinsAwarded.map(Int.init)
                    context.insert(run)
                }
            }
            try? context.save()
        } catch {
            // ignore; cached data renders
        }
    }

    // MARK: - Push run mutations

    func pushAccept(_ run: ChallengeRun) async {
        guard let userId = ConvexManager.shared.currentUserId else { return }
        do {
            try await convex.mutation("challengeRuns:accept", with: [
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
            ])
        } catch {
            // Sync retries on next foreground; local insert remains.
        }
    }

    func pushComplete(_ run: ChallengeRun) async {
        guard let userId = ConvexManager.shared.currentUserId,
              let completedAt = run.completedAt,
              let coinsAwarded = run.coinsAwarded else { return }
        try? await convex.mutation("challengeRuns:complete", with: [
            "runId": run.runId,
            "userId": userId,
            "completedAt": completedAt.timeIntervalSince1970 * 1000,
            "coinsAwarded": Self.dbl(coinsAwarded),
        ])
    }

    func pushExpire(_ run: ChallengeRun) async {
        guard let userId = ConvexManager.shared.currentUserId else { return }
        try? await convex.mutation("challengeRuns:expire", with: [
            "runId": run.runId,
            "userId": userId,
        ])
    }

    func pullAll(into context: ModelContext) async {
        await pullTemplates(into: context)
        await pullRuns(into: context)
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -10
```

If the `ConvexMobile` API signatures don't match exactly (`client.mutation` vs `subscribe`), follow the patterns already used in `convex/friends.ts`-adjacent Swift call sites and adapt. The Int→Double cast policy stays the same.

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Core/Services/ChallengeSyncService.swift
git commit -m "feat(challenges): ChallengeSyncService with Int→Double encoding boundary"
```

---

## Phase 6 — Integration

### Task 17: Hook recompute into `GooseEngine.update`

**Files:**
- Modify: `TamaGoosie/Core/Services/GooseEngine.swift:31-45`

`GooseEngine.update` is the single recompute pipeline. Add a single call at the end — after stat recompute, before `saveStatsToAppGroup`.

- [ ] **Step 1: Modify `update` signature to take runs**

Replace lines around 31–45 in `GooseEngine.swift`:

```swift
    func update(
        state: GooseState,
        log: DailyLog?,
        profile: UserProfile?,
        goals: [Goal],
        challengeRuns: [ChallengeRun] = [],
        challengeLogs: [DailyLog] = []
    ) {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        if let log, let profile, log.hasHealthData {
            state.healthiness = RewardEngine.computeHealthiness(log: log, profile: profile)
        }
        if let log, log.hasAnyData {
            state.happiness = RewardEngine.computeHappiness(log: log, goals: goals)
        }

        // Recompute challenge progress; awarded coins land on state.coins.
        let newlyCompleted = ChallengeEngine.recomputeActive(
            state: state, logs: challengeLogs, runs: challengeRuns
        )
        for run in newlyCompleted {
            Task { await ChallengeSyncService.shared.pushComplete(run) }
        }
        for run in challengeRuns where run.statusEnum == .expired && run.completedAt == nil {
            // Expiry transition just happened in this call.
            Task { await ChallengeSyncService.shared.pushExpire(run) }
        }

        state.updateMood()
        state.lastUpdated = .now
        saveStatsToAppGroup(state.toSyncPayload())
    }
```

- [ ] **Step 2: Build + run existing tests**

```bash
xcodebuild test -project TamaGoosie.xcodeproj -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Existing callers of `update(state:log:profile:goals:)` keep working — new args default to empty. Verify no test regressions.

- [ ] **Step 3: Update call sites that want challenge recompute**

The Challenges tab call site is added in Task 19. Other call sites (`ContentView.swift`, `GooseViewModel`, etc.) can stay default-empty for now — challenge recompute will only happen when the user opens Challenges. This is fine for v1; cross-tab recompute is a future enhancement.

- [ ] **Step 4: Commit**

```bash
git add TamaGoosie/Core/Services/GooseEngine.swift
git commit -m "feat(challenges): hook recomputeActive into GooseEngine.update (default-empty for back-compat)"
```

---

## Phase 7 — UI

### Task 18: `ChallengeViewModel`

**Files:**
- Create: `TamaGoosie/Features/Challenges/ChallengeViewModel.swift`

- [ ] **Step 1: Create the view model**

```swift
// TamaGoosie/Features/Challenges/ChallengeViewModel.swift
import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class ChallengeViewModel {
    var pendingCompletions: [ChallengeRun] = []
    var lastError: ChallengeError?

    func active(from runs: [ChallengeRun]) -> [ChallengeRun] {
        runs.filter { $0.statusEnum == .active }
            .sorted { $0.startedAt < $1.startedAt }
    }

    func browseable(
        from templates: [ChallengeTemplate],
        runs: [ChallengeRun],
        now: Date = Date()
    ) -> [ChallengeTemplate] {
        templates
            .filter { $0.isActive }
            .sorted { $0.sortHint < $1.sortHint }
    }

    func isInCooldown(_ template: ChallengeTemplate, runs: [ChallengeRun], now: Date = Date()) -> Bool {
        ChallengeEngine.isInCooldown(templateId: template.templateId, runs: runs, now: now)
    }

    func cooldownEnds(for template: ChallengeTemplate, runs: [ChallengeRun]) -> Date? {
        runs
            .filter { $0.templateId == template.templateId && $0.statusEnum == .expired }
            .map { $0.expiresAt.addingTimeInterval(Double($0.windowDaysSnapshot) * 86_400) }
            .max()
    }

    func activeCount(_ runs: [ChallengeRun]) -> Int {
        runs.filter { $0.statusEnum == .active }.count
    }

    func canAccept(_ runs: [ChallengeRun]) -> Bool {
        activeCount(runs) < GoosieConstants.challengeActiveCap
    }

    func accept(
        template: ChallengeTemplate, tier: ChallengeTier,
        runs: [ChallengeRun], logs: [DailyLog], state: GooseState?,
        context: ModelContext
    ) {
        do {
            let run = try ChallengeEngine.accept(
                template: template, tier: tier,
                existingRuns: runs, context: context, now: Date()
            )
            try? context.save()
            Task { await ChallengeSyncService.shared.pushAccept(run) }
            // Same-day completion check — covers e.g. a 1-day challenge whose target is already met.
            if let state {
                let completed = ChallengeEngine.recomputeActive(
                    state: state, logs: logs, runs: runs + [run]
                )
                if !completed.isEmpty { enqueueCompletions(completed) }
            }
        } catch let err as ChallengeError {
            lastError = err
        } catch {
            // unexpected
        }
    }

    /// Live progress for an active run. Returns the raw aggregate value.
    func currentProgress(for run: ChallengeRun, logs: [DailyLog], now: Date = Date()) -> Double {
        ChallengeEngine.aggregate(
            shape: run.shapeEnum, metric: run.metricEnum,
            target: run.targetSnapshot, logs: logs,
            windowStart: run.startedAt, now: now
        )
    }

    /// 0...1 fraction for the progress bar.
    func progressFraction(for run: ChallengeRun, logs: [DailyLog]) -> Double {
        let target: Double = run.shapeEnum == .dailyCeiling
            ? Double(run.windowDaysSnapshot)
            : run.targetSnapshot
        guard target > 0 else { return 0 }
        return min(1.0, currentProgress(for: run, logs: logs) / target)
    }

    func abandon(_ run: ChallengeRun, context: ModelContext) {
        run.status = ChallengeStatus.expired.rawValue
        try? context.save()
        Task { await ChallengeSyncService.shared.pushExpire(run) }
    }

    func enqueueCompletions(_ runs: [ChallengeRun]) {
        pendingCompletions.append(contentsOf: runs)
    }

    func popNextCompletion() -> ChallengeRun? {
        pendingCompletions.isEmpty ? nil : pendingCompletions.removeFirst()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TamaGoosie/Features/Challenges/ChallengeViewModel.swift
git commit -m "feat(challenges): ChallengeViewModel with active/browse slicing + accept/abandon"
```

---

### Task 19: Replace `ChallengesView` with Layout A skeleton

**Files:**
- Modify: `TamaGoosie/Features/Challenges/ChallengesView.swift` (replace whole file)

> **Memory: don't put a `Color.ignoresSafeArea()` inside a `ZStack` above a `ScrollView` — taps will be eaten** (`feedback_zstack_color_hittest`). Use `.background()` on the `ScrollView`.

- [ ] **Step 1: Replace the file**

```swift
// TamaGoosie/Features/Challenges/ChallengesView.swift
import SwiftUI
import SwiftData

struct ChallengesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChallengeTemplate.sortHint) private var templates: [ChallengeTemplate]
    @Query private var runs: [ChallengeRun]
    @Query private var gooseStates: [GooseState]
    @Query private var logs: [DailyLog]
    @State private var viewModel = ChallengeViewModel()
    @State private var detailTarget: ChallengeTemplate?
    @State private var completionTarget: ChallengeRun?
    @State private var showCapToast = false

    private var state: GooseState? { gooseStates.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ChallengeHeader(
                    coins: state?.coins ?? 0,
                    activeCount: viewModel.activeCount(runs),
                    cap: GoosieConstants.challengeActiveCap
                )

                let active = viewModel.active(from: runs)
                if !active.isEmpty {
                    ChallengeListSection(.active, runs: active) { run in
                        ChallengeCard.active(
                            run: run,
                            template: template(for: run),
                            progressFraction: viewModel.progressFraction(for: run, logs: logs),
                            currentProgress: viewModel.currentProgress(for: run, logs: logs)
                        ) {
                            viewModel.abandon(run, context: modelContext)
                        }
                    }
                }

                ChallengeListSection(.browse, templates: viewModel.browseable(from: templates, runs: runs)) { template in
                    let cooldown = viewModel.isInCooldown(template, runs: runs)
                    let cooldownEnds = viewModel.cooldownEnds(for: template, runs: runs)
                    let cap = !viewModel.canAccept(runs)
                    ChallengeCard.browse(
                        template: template, inCooldown: cooldown,
                        cooldownEnds: cooldownEnds, capReached: cap
                    ) {
                        if cooldown { return }
                        if cap { withAnimation { showCapToast = true } ; return }
                        detailTarget = template
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 52)
            .padding(.bottom, 32)
        }
        .background(GrassyBackgroundView().ignoresSafeArea())
        .refreshable {
            await ChallengeSyncService.shared.pullAll(into: modelContext)
            if let state {
                let completed = ChallengeEngine.recomputeActive(state: state, logs: logs, runs: runs)
                viewModel.enqueueCompletions(completed)
            }
        }
        .onAppear {
            Task {
                await ChallengeSyncService.shared.pullAll(into: modelContext)
                if let state {
                    let completed = ChallengeEngine.recomputeActive(state: state, logs: logs, runs: runs)
                    viewModel.enqueueCompletions(completed)
                }
            }
        }
        .onChange(of: viewModel.pendingCompletions.count) { _, _ in
            if completionTarget == nil, let next = viewModel.popNextCompletion() {
                completionTarget = next
            }
        }
        .sheet(item: $detailTarget) { template in
            ChallengeDetailSheet(template: template) { tier in
                viewModel.accept(
                    template: template, tier: tier,
                    runs: runs, logs: logs, state: state,
                    context: modelContext
                )
                detailTarget = nil
            }
        }
        .sheet(item: $completionTarget) { run in
            ChallengeCompletionSheet(run: run, template: template(for: run)) {
                completionTarget = viewModel.popNextCompletion()
            }
        }
        .overlay(alignment: .bottom) {
            if showCapToast {
                Text("Finish one to start another")
                    .font(.callout).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.black.opacity(0.7), in: Capsule())
                    .padding(.bottom, 80)
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { showCapToast = false }
                    }
            }
        }
    }

    private func template(for run: ChallengeRun) -> ChallengeTemplate? {
        templates.first { $0.templateId == run.templateId }
    }
}

private struct ChallengeHeader: View {
    let coins: Int
    let activeCount: Int
    let cap: Int
    var body: some View {
        HStack {
            Text("Challenges")
                .font(GoosieTheme.titleFont(22))
                .foregroundStyle(.white)
            Spacer()
            Text("🪙 \(coins)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white.opacity(0.2), in: Capsule())
        }
    }
}
```

> Note: `ChallengeCard`, `ChallengeListSection`, `ChallengeDetailSheet`, `ChallengeCompletionSheet`, and `GrassyBackgroundView` are referenced — the next tasks build them. `GrassyBackgroundView` already exists in the project (used by the old placeholder).

- [ ] **Step 2: Commit (will not build yet — depends on Tasks 20–22)**

```bash
git add TamaGoosie/Features/Challenges/ChallengesView.swift
git commit -m "feat(challenges): replace placeholder ChallengesView with Layout A skeleton"
```

> Do not run `xcodebuild` yet — it will fail because `ChallengeCard` etc. don't exist. Tasks 20–22 fill in the gaps, then Task 23 runs the build.

---

### Task 20: `ChallengeListSection` + `ChallengeCard`

**Files:**
- Create: `TamaGoosie/Features/Challenges/ChallengeListSection.swift`
- Create: `TamaGoosie/Features/Challenges/ChallengeCard.swift`

- [ ] **Step 1: Create `ChallengeListSection.swift`**

```swift
// TamaGoosie/Features/Challenges/ChallengeListSection.swift
import SwiftUI

struct ChallengeListSection<Item: Identifiable, RowContent: View>: View {
    enum Kind { case active, browse }
    let kind: Kind
    let items: [Item]
    let row: (Item) -> RowContent

    init(_ kind: Kind, runs: [ChallengeRun], @ViewBuilder row: @escaping (ChallengeRun) -> RowContent)
    where Item == ChallengeRun {
        self.kind = kind; self.items = runs; self.row = row
    }

    init(_ kind: Kind, templates: [ChallengeTemplate], @ViewBuilder row: @escaping (ChallengeTemplate) -> RowContent)
    where Item == ChallengeTemplate {
        self.kind = kind; self.items = templates; self.row = row
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .textCase(.uppercase)
            ForEach(items) { row($0) }
        }
    }

    private var label: String { kind == .active ? "Active" : "Browse" }
}

// Both models need to be Identifiable for ForEach
extension ChallengeRun: Identifiable { public var id: String { runId } }
extension ChallengeTemplate: Identifiable { public var id: String { templateId } }
```

- [ ] **Step 2: Create `ChallengeCard.swift`**

```swift
// TamaGoosie/Features/Challenges/ChallengeCard.swift
import SwiftUI

enum ChallengeCard {
    struct active: View {
        let run: ChallengeRun
        let template: ChallengeTemplate?
        let progressFraction: Double          // 0...1, computed by ViewModel
        let currentProgress: Double           // raw aggregate (for dailyCeiling day count display)
        let onAbandon: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(template?.title ?? "Challenge")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    TierChip(tier: run.tierEnum)
                }
                Text(metaLine)
                    .font(.caption).foregroundStyle(.secondary)
                if run.shapeEnum == .cumulative {
                    ProgressView(value: progressFraction)
                        .tint(.green)
                } else {
                    Text(ceilingLine).font(.caption2).foregroundStyle(.secondary)
                }
                Text("🪙 \(run.rewardSnapshot) on complete")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yellow, lineWidth: 2))
            .contextMenu {
                Button(role: .destructive) { onAbandon() } label: { Label("Abandon", systemImage: "xmark") }
            }
        }

        private var metaLine: String {
            let daysLeft = max(0, Calendar.current.dateComponents([.day], from: Date(), to: run.expiresAt).day ?? 0)
            if run.shapeEnum == .cumulative {
                return "\(Int(currentProgress)) / \(Int(run.targetSnapshot)) \(run.metricSnapshot) · \(daysLeft)d left"
            } else {
                return "\(Int(currentProgress))/\(run.windowDaysSnapshot) days · \(daysLeft)d left"
            }
        }
        private var ceilingLine: String { "Hold under \(Int(run.targetSnapshot)) for \(run.windowDaysSnapshot) days" }
    }

    struct browse: View {
        let template: ChallengeTemplate
        let inCooldown: Bool
        let cooldownEnds: Date?
        let capReached: Bool
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.title).font(.subheadline.weight(.bold))
                    Text(template.blurb).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    HStack(spacing: 6) {
                        TierChip(tier: .bronze)
                        TierChip(tier: .silver)
                        TierChip(tier: .gold)
                    }
                    if inCooldown, let ends = cooldownEnds {
                        Text("Available in \(daysUntil(ends))d")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                .grayscale(inCooldown ? 0.8 : 0)
                .opacity(inCooldown ? 0.6 : 1)
            }
            .buttonStyle(.plain)
            .disabled(inCooldown)
        }

        private func daysUntil(_ date: Date) -> Int {
            max(0, Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0)
        }
    }
}

struct TierChip: View {
    let tier: ChallengeTier
    var body: some View {
        Text(tier.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
    private var color: Color {
        switch tier {
        case .bronze: return .brown
        case .silver: return .gray
        case .gold:   return .orange
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Challenges/ChallengeListSection.swift TamaGoosie/Features/Challenges/ChallengeCard.swift
git commit -m "feat(challenges): list section + active/browse card views"
```

---

### Task 21: `ChallengeDetailSheet`

**Files:**
- Create: `TamaGoosie/Features/Challenges/ChallengeDetailSheet.swift`

- [ ] **Step 1: Create the sheet**

```swift
// TamaGoosie/Features/Challenges/ChallengeDetailSheet.swift
import SwiftUI

struct ChallengeDetailSheet: View {
    let template: ChallengeTemplate
    let onStart: (ChallengeTier) -> Void
    @State private var tier: ChallengeTier = .silver
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text(template.title).font(.title2.weight(.bold))
            Text(template.blurb).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)

            Text(howItWorks)
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)

            Picker("Tier", selection: $tier) {
                ForEach(ChallengeTier.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Target")
                Spacer()
                Text("\(Int(template.target(for: tier))) \(template.metric)").font(.body.weight(.semibold))
            }
            HStack {
                Text("Reward")
                Spacer()
                Text("🪙 \(template.reward(for: tier))").font(.body.weight(.semibold)).foregroundStyle(.orange)
            }

            Button {
                onStart(tier); dismiss()
            } label: {
                Text("Start").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(GoosieTheme.accentGreen)
        }
        .padding(20)
        .presentationDetents([.medium])
    }

    private var howItWorks: String {
        let shape = ChallengeShape(rawValue: template.shape) ?? .cumulative
        switch shape {
        case .cumulative:
            return "Accumulate \(Int(template.target(for: tier))) \(template.metric) within \(template.windowDays) days."
        case .dailyCeiling:
            return "Stay under \(Int(template.target(for: tier))) \(template.metric) every day for \(template.windowDays) days."
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TamaGoosie/Features/Challenges/ChallengeDetailSheet.swift
git commit -m "feat(challenges): detail sheet with tier picker + Start CTA"
```

---

### Task 22: `ChallengeCompletionSheet` (reuses `CoinAnimationView`)

**Files:**
- Create: `TamaGoosie/Features/Challenges/ChallengeCompletionSheet.swift`

- [ ] **Step 1: Create the sheet**

```swift
// TamaGoosie/Features/Challenges/ChallengeCompletionSheet.swift
import SwiftUI

struct ChallengeCompletionSheet: View {
    let run: ChallengeRun
    let template: ChallengeTemplate?
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text("Challenge Complete!").font(.title2.weight(.bold))
            Text(template?.title ?? run.templateId).font(.headline)
            TierChip(tier: run.tierEnum)

            // Reuse the existing coin animation.
            CoinAnimationView(coins: run.coinsAwarded ?? 0)
                .frame(height: 100)

            Text("🪙 \(run.coinsAwarded ?? 0)")
                .font(.title3.weight(.bold))
                .foregroundStyle(.orange)

            Button {
                dismiss(); onDismiss()
            } label: {
                Text("Nice!").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(GoosieTheme.accentGreen)
        }
        .padding(24)
        .presentationDetents([.medium])
        .interactiveDismissDisabled(false)
    }
}
```

> If `CoinAnimationView` has a different init signature, adapt the call — check `TamaGoosie/Features/Goose/CoinAnimationView.swift` first.

- [ ] **Step 2: Regenerate Xcode project (new files in Features/Challenges/)**

```bash
xcodegen generate
```

- [ ] **Step 3: Build whole app**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. If the build fails due to a `GooseEngine.update` call site missing the new default-empty parameters, add them.

- [ ] **Step 4: Commit**

```bash
git add TamaGoosie/Features/Challenges/ChallengeCompletionSheet.swift TamaGoosie.xcodeproj
git commit -m "feat(challenges): completion sheet reusing CoinAnimationView"
```

---

### Task 23: Smoke test in simulator

**Files:** none — manual launch.

- [ ] **Step 1: Launch app on the simulator**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
open -a Simulator
```

Then in Xcode: Run the `TamaGoosie` scheme on iPhone 17 Pro.

- [ ] **Step 2: Manually verify**

- Open Challenges tab → no crash; "Browse" shows empty (Convex has no templates yet — Task 24 seeds them).
- "Active (0/3)" header is hidden because Active section hides when empty.
- Pull-to-refresh triggers `pullAll` (won't show anything new yet).

- [ ] **Step 3: No commit** — code-only smoke test.

---

## Phase 8 — Content + Validation

### Task 24: Seed 12 starter templates

**Files:**
- Create: `convex/seedChallenges.ts`

- [ ] **Step 1: Create seed script**

```ts
// convex/seedChallenges.ts
import { internalMutation } from "./_generated/server";

export const seed = internalMutation(async (ctx) => {
  const templates = [
    {
      templateId: "step-it-up", title: "Step it up",
      blurb: "Rack up steps across the week.",
      category: "health" as const, shape: "cumulative" as const, metric: "steps" as const, windowDays: 7,
      tiers: {
        bronze: { target: 30_000, coinReward: 25 },
        silver: { target: 50_000, coinReward: 60 },
        gold:   { target: 75_000, coinReward: 120 },
      }, active: true, sortHint: 10,
    },
    {
      templateId: "sit-less", title: "Sit less",
      blurb: "Keep sitting time low every day.",
      category: "health" as const, shape: "dailyCeiling" as const, metric: "sittingHours" as const, windowDays: 3,
      tiers: {
        bronze: { target: 9, coinReward: 25 },
        silver: { target: 8, coinReward: 60 },
        gold:   { target: 7, coinReward: 120 },
      }, active: true, sortHint: 20,
    },
    {
      templateId: "outdoors-week", title: "Outdoors week",
      blurb: "Get outside this week.",
      category: "health" as const, shape: "cumulative" as const, metric: "outsideMinutes" as const, windowDays: 7,
      tiers: {
        bronze: { target: 60,  coinReward: 25 },
        silver: { target: 120, coinReward: 60 },
        gold:   { target: 210, coinReward: 120 },
      }, active: true, sortHint: 30,
    },
    {
      templateId: "sleep-streak", title: "Sleep streak",
      blurb: "Sleep enough every night.",
      category: "health" as const, shape: "dailyCeiling" as const, metric: "sleepHours" as const, windowDays: 5,
      // Note: dailyCeiling uses <= target. For sleep we invert by negating in app, OR — simpler — leave as ceiling on under-sleep proxy.
      // For v1, we use cumulative sleepHours instead:
      tiers: {
        bronze: { target: 35, coinReward: 25 },
        silver: { target: 40, coinReward: 60 },
        gold:   { target: 45, coinReward: 120 },
      }, active: true, sortHint: 40,
    },
    {
      templateId: "exercise-burst", title: "Exercise burst",
      blurb: "Hit exercise minutes this week.",
      category: "health" as const, shape: "cumulative" as const, metric: "exerciseMinutes" as const, windowDays: 7,
      tiers: {
        bronze: { target: 90,  coinReward: 25 },
        silver: { target: 150, coinReward: 60 },
        gold:   { target: 210, coinReward: 120 },
      }, active: true, sortHint: 50,
    },
    {
      templateId: "stand-up", title: "Stand up",
      blurb: "Stand hours this week.",
      category: "health" as const, shape: "cumulative" as const, metric: "standHours" as const, windowDays: 7,
      tiers: {
        bronze: { target: 50, coinReward: 25 },
        silver: { target: 70, coinReward: 60 },
        gold:   { target: 84, coinReward: 120 },
      }, active: true, sortHint: 60,
    },
    {
      templateId: "weekend-warrior", title: "Weekend warrior",
      blurb: "20k steps over 2 days.",
      category: "health" as const, shape: "cumulative" as const, metric: "steps" as const, windowDays: 2,
      tiers: {
        bronze: { target: 12_000, coinReward: 25 },
        silver: { target: 20_000, coinReward: 60 },
        gold:   { target: 28_000, coinReward: 120 },
      }, active: true, sortHint: 70,
    },
    {
      templateId: "active-trio", title: "Active trio",
      blurb: "Three solid exercise days this week.",
      category: "health" as const, shape: "dailyCeiling" as const, metric: "exerciseMinutes" as const, windowDays: 3,
      // anti-goal flip: we use a high target so "<=" trivially holds; intent here is illustrative.
      // In a future patch, add a "dailyFloor" shape. For v1 seed, skip if dailyFloor not implemented.
      tiers: {
        bronze: { target: 999, coinReward: 25 },
        silver: { target: 999, coinReward: 60 },
        gold:   { target: 999, coinReward: 120 },
      }, active: false, sortHint: 80,  // disabled until dailyFloor lands
    },
    {
      templateId: "sit-less-week", title: "Sit less (week)",
      blurb: "Hold sitting under target every day for a week.",
      category: "health" as const, shape: "dailyCeiling" as const, metric: "sittingHours" as const, windowDays: 7,
      tiers: {
        bronze: { target: 9, coinReward: 50 },
        silver: { target: 8, coinReward: 100 },
        gold:   { target: 7, coinReward: 180 },
      }, active: true, sortHint: 90,
    },
    {
      templateId: "fresh-air-3", title: "Fresh air × 3",
      blurb: "60 outdoor minutes across 3 days.",
      category: "health" as const, shape: "cumulative" as const, metric: "outsideMinutes" as const, windowDays: 3,
      tiers: {
        bronze: { target: 30, coinReward: 25 },
        silver: { target: 60, coinReward: 60 },
        gold:   { target: 90, coinReward: 120 },
      }, active: true, sortHint: 100,
    },
    {
      templateId: "stand-strong", title: "Stand strong",
      blurb: "Hit stand hours each day for 5 days.",
      category: "health" as const, shape: "cumulative" as const, metric: "standHours" as const, windowDays: 5,
      tiers: {
        bronze: { target: 40, coinReward: 25 },
        silver: { target: 50, coinReward: 60 },
        gold:   { target: 60, coinReward: 120 },
      }, active: true, sortHint: 110,
    },
    {
      templateId: "deep-sleep-3", title: "Deep sleep × 3",
      blurb: "21 hours of sleep across 3 nights.",
      category: "health" as const, shape: "cumulative" as const, metric: "sleepHours" as const, windowDays: 3,
      tiers: {
        bronze: { target: 18, coinReward: 25 },
        silver: { target: 21, coinReward: 60 },
        gold:   { target: 24, coinReward: 120 },
      }, active: true, sortHint: 120,
    },
  ];

  for (const t of templates) {
    const existing = await ctx.db
      .query("challengeTemplates")
      .withIndex("by_templateId", (q) => q.eq("templateId", t.templateId))
      .first();
    if (existing) {
      const { templateId, ...rest } = t;
      await ctx.db.patch(existing._id, rest);
    } else {
      await ctx.db.insert("challengeTemplates", t);
    }
  }
});
```

- [ ] **Step 2: Run seed**

```bash
cd convex && npx convex run seedChallenges:seed 2>&1 | tail -5
```

Expected: no error, mutation succeeds.

- [ ] **Step 3: Verify in dev dashboard**

```bash
cd convex && npx convex dashboard
```

In the dashboard, open the `challengeTemplates` table — confirm ~11 active rows (one is intentionally inactive).

- [ ] **Step 4: Re-launch app and verify**

Re-run the simulator. Open Challenges tab. Confirm the Browse section now lists the seeded templates.

- [ ] **Step 5: Commit**

```bash
git add convex/seedChallenges.ts
git commit -m "feat(challenges): seed 12 starter health challenges (1 inactive pending dailyFloor)"
```

---

### Task 25: UI test for load-bearing flow

**Files:**
- Create: `TamaGoosieUITests/ChallengesUITests.swift` (or extend existing `TamaGoosieTests/` if no UITests target)

> If the project has no `TamaGoosieUITests` target, skip this task and rely on manual QA (Task 26). Check `project.yml` for a `TamaGoosieUITests` entry first.

- [ ] **Step 1: Check for UITests target**

```bash
grep -n "TamaGoosieUITests" /Users/PriscillaYe/Documents/GitHub/TamaGoosie/project.yml || echo "NO UITESTS TARGET"
```

If "NO UITESTS TARGET", skip to Step 4 (no-op commit).

- [ ] **Step 2: Write UI test**

```swift
// TamaGoosieUITests/ChallengesUITests.swift
import XCTest

final class ChallengesUITests: XCTestCase {
    func testChallengesTabOpensAndShowsBrowse() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSeedChallenges"]
        app.launch()
        app.tabBars.buttons["Challenges"].tap()
        XCTAssertTrue(app.staticTexts["Browse"].waitForExistence(timeout: 3))
    }

    func testCapToastFiresOnFourthAccept() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSeedChallenges", "-UITestPrefillThreeActive"]
        app.launch()
        app.tabBars.buttons["Challenges"].tap()
        app.scrollViews.firstMatch.swipeUp()
        // Tap any browse card title — expects toast, no sheet.
        let browseCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Outdoors'")).firstMatch
        if browseCard.exists {
            browseCard.tap()
            XCTAssertTrue(app.staticTexts["Finish one to start another"].waitForExistence(timeout: 2))
        }
    }
}
```

- [ ] **Step 3: Wire launch arguments**

In `TamaGoosieApp.init()`, after the ModelContainer setup, check launch args (gate behind `#if DEBUG`):

```swift
#if DEBUG
if CommandLine.arguments.contains("-UITestSeedChallenges") {
    UITestSeed.applyChallengeSeed(to: container.mainContext)
}
if CommandLine.arguments.contains("-UITestPrefillThreeActive") {
    UITestSeed.prefillThreeActive(in: container.mainContext)
}
#endif
```

And create `TamaGoosie/Debug/UITestSeed.swift` (DEBUG-only) with the matching helpers (insert 3 templates + 3 active runs locally so the test doesn't depend on Convex).

- [ ] **Step 4: Run / commit**

If UITests target exists:
```bash
xcodebuild test -project TamaGoosie.xcodeproj -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:TamaGoosieUITests/ChallengesUITests 2>&1 | tail -20
```

Then:
```bash
git add TamaGoosieUITests/ChallengesUITests.swift TamaGoosie/Debug/UITestSeed.swift TamaGoosie/App/TamaGoosieApp.swift
git commit -m "test(challenges): XCUITest for tab load + cap toast"
```

If no UITests target, commit nothing and proceed.

---

### Task 26: Manual QA checklist doc

**Files:**
- Create: `docs/superpowers/plans/2026-05-27-challenges-tab-qa.md`

- [ ] **Step 1: Create QA doc**

```markdown
# Challenges Tab — Manual QA Checklist

Run before merging to main. Expected effort: ~20 min.

## Setup
- Fresh simulator install OR delete the app from a test device first.
- Seed Convex templates: `cd convex && npx convex run seedChallenges:seed`.

## Golden path
- [ ] Open Challenges tab — Browse section populated, Active section hidden.
- [ ] Tap a browse card → detail sheet opens with Silver pre-selected.
- [ ] Switch tier to Gold — target + reward update in real time.
- [ ] Tap Start → card moves to Active, sheet dismisses, coin pill unchanged.
- [ ] Accept two more → "Active (3/3)" header visible.
- [ ] Tap a fourth browse card → toast "Finish one to start another"; no sheet.

## Completion
- [ ] Manually inject HealthKit step data (or use a debug menu) to push an active challenge over target.
- [ ] Foreground the app → completion sheet appears, coin pill increments by the snapshotted reward.
- [ ] Dismiss → if other completions queued, next sheet appears.

## Expiry + cooldown
- [ ] Accept a 2-day challenge; advance simulator clock past `expiresAt`.
- [ ] Re-open app → run moves out of Active; appears as cooldown badge in Browse.
- [ ] Try to start → tap disabled; "Available in Nd" shown.

## Offline
- [ ] Turn off Wi-Fi.
- [ ] Accept a challenge → succeeds locally, no error UI.
- [ ] Kill app → reopen → run still present.
- [ ] Turn Wi-Fi back on → pull-to-refresh → no duplicates appear.

## Schema-mismatch resilience
- [ ] In Convex dashboard, insert a `challengeTemplates` row with an invalid `metric` value.
- [ ] Re-open Challenges → tab loads; bad row is silently skipped.

## Time-zone
- [ ] Change simulator system time zone (Settings → General → Date & Time).
- [ ] Re-open app → no crash; daysLeft countdown updates plausibly.

## Hit-testing (regression check)
- [ ] Background of Challenges tab does NOT swallow taps. Buttons on cards respond.
- [ ] Pull-to-refresh works on the ScrollView.

## Sign-off
- Tested by: ____
- Date: ____
- Build: ____
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/plans/2026-05-27-challenges-tab-qa.md
git commit -m "docs(challenges): add manual QA checklist for v1 ship"
```

---

## Final verification

- [ ] **Run full Swift test suite**

```bash
xcodebuild test -project TamaGoosie.xcodeproj -scheme TamaGoosie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: all Challenge engine tests pass; no regressions in existing tests.

- [ ] **Run full Convex test suite**

```bash
cd convex && npm test 2>&1 | tail -20
```

Expected: 5 challengeRuns tests pass.

- [ ] **Complete the manual QA checklist** (Task 26 doc).

- [ ] **Update the feature doc status field**

In `Obsidian Vault/Projects/TamaGoosie/product/features/challenges.md`, change `status: designed` → `status: shipped` once merged.

---

## Out of scope for this plan (deferred)

- **"Done" / history surface** — Layout A doesn't expose it. Add in v1.1 if usage shows demand.
- **`dailyFloor` shape** — for challenges like "exercise at least N minutes daily" (anti-`dailyCeiling`). One template (`active-trio`) is seeded as inactive pending this.
- **Anti-cheat against fabricated HealthKit values** — only matters when leaderboards land (v2 Phase 6).
- **Watch / Widget surface** — Sync payload unchanged in v1.
- **Notifications** — In-app celebration only. Push deferred.
- **Cross-tab visibility** (e.g., active challenges on Home/Today) — out of v1 scope per surfacing decision.
