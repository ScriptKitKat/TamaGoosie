# Challenges Tab — Design

**Date:** 2026-05-26
**Status:** Approved, pending implementation plan
**Scope:** v1 — additive to Goals, pre–v2 Phase 1 (no XP system required)

## TL;DR

Replace the `ChallengesView` placeholder with an always-on, opt-in **library of curated, time-bound bonus quests**. Health-only for v1. Two shapes: **cumulative** (e.g., 50k steps in 7 days) and **dailyCeiling / anti-goal** (e.g., sit <8h/day for 3 days). Each template has Bronze/Silver/Gold tiers; the user picks a tier when starting. Hard cap of 3 active. Completing awards **coins** (existing `GooseState.coins`). Expiring triggers a cooldown equal to the window length. Backend is Convex for templates + run history; SwiftData mirrors locally so the tab works offline.

## Goals

- Give users a low-pressure way to opt into bigger short-term efforts than recurring Goals provide.
- Reward completion in a form forward-compatible with the v2 Store/economy (coins).
- Establish a feature scaffold that can later host social/group quests (v2 Phase 6) without rework.
- Respect existing principles: no death, no engagement-by-threat, stats earned not bought, iPhone as source of truth.

## Non-goals (v1)

- No XP, no levels — v2 Phase 1 territory.
- No friend/group/leaderboard surfaces — v2 Phase 6.
- No surfacing on Home/Goose view, Watch, or Widget.
- No push notifications. In-app celebration only.
- No personalization from baselines (curated, not procedural).
- No history/"Done" surface in v1 (deferred — Layout A doesn't expose it).
- No new categories beyond Health.

## Design principles in play

- **No engagement-by-threat** ([ADR-003](../../docs/architecture.md)) — expiry awards nothing and isn't penalized; the equal-length cooldown is framed as a *commitment device* (you opted into that window; honor it), not a punishment.
- **Recompute from data, never delta-mutate** ([ADR-002](../../docs/architecture.md)) — progress is always derived from `DailyLog` history, mirroring `RewardEngine`.
- **iPhone as source of truth** ([ADR-004](../../docs/architecture.md)) — Watch/Widget unchanged; Convex stores authoritative run records.
- **Stats earned, not bought** — coins remain non-purchasable in v1.

## Product summary (decided in brainstorm)

| Decision | Answer |
|---|---|
| Source of challenges | Curated library, PS-pattern-inspired |
| Cadence | Always-on opt-in browse |
| Categories (v1) | Health only |
| Shapes | `cumulative` + `dailyCeiling` (anti-goal) |
| Difficulty | Bronze / Silver / Gold tiers (user picks at accept) |
| Reward | Coins (existing `GooseState.coins`) |
| Lifecycle | Window starts on accept; expires if not met |
| Cooldown | Equal to window length |
| Concurrency cap | 3 active |
| Layout | A — Active pinned on top, Browse below, single scroll |
| Cross-surfaces | Challenges tab only |
| Notifications | In-app celebration only (reuse `CoinAnimationView`) |
| Sync | Convex from day one |
| Launch library size | ~12 templates × 3 tiers = 36 configurations |

## Architecture & data model

### Source of truth split

- **Convex** owns: `challengeTemplates` (curated library, hot-updatable) and `challengeRuns` (authoritative per-user run history).
- **SwiftData** mirrors both for offline-first reads; rebuilt on launch + foreground.
- **HealthKit + `DailyLog`** remain the only source of measured behavior. Progress is *computed*, never written from a user action.

### Convex tables

```ts
// convex/schema.ts (additions)

challengeTemplates: defineTable({
  templateId: v.string(),          // stable slug, e.g. "step-it-up"
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
}).index("by_active", ["active", "sortHint"]),

challengeRuns: defineTable({
  runId: v.string(),
  userId: v.string(),
  templateId: v.string(),
  tier: v.union(v.literal("bronze"), v.literal("silver"), v.literal("gold")),
  startedAt: v.number(),           // epoch ms (cast Double on Swift side)
  expiresAt: v.number(),
  status: v.union(v.literal("active"), v.literal("completed"), v.literal("expired")),
  completedAt: v.union(v.number(), v.null()),
  coinsAwarded: v.union(v.number(), v.null()),
  // Snapshots frozen at accept time — survive template edits
  targetSnapshot: v.number(),
  rewardSnapshot: v.number(),
  metricSnapshot: v.string(),
  shapeSnapshot: v.string(),
  windowDaysSnapshot: v.number(),
})
  .index("by_user_status", ["userId", "status"])
  .index("by_user_template", ["userId", "templateId"]),
```

> **Encoding gotcha:** Swift `Int` encodes as Convex `Int64`, not `Float64`. All `Int` values bound for `v.number()` must be cast to `Double` at the sync-service boundary.

### SwiftData mirror

```swift
// TamaGoosie/Core/Models/ChallengeTemplate.swift
@Model final class ChallengeTemplate {
  @Attribute(.unique) var templateId: String
  var title: String
  var blurb: String
  var category: String           // "health"
  var shape: String              // "cumulative" | "dailyCeiling"
  var metric: String
  var windowDays: Int
  // tier values flattened for SwiftData compatibility
  var bronzeTarget: Double; var bronzeReward: Int
  var silverTarget: Double; var silverReward: Int
  var goldTarget:   Double; var goldReward:   Int
  var isActive: Bool
  var sortHint: Int
}

// TamaGoosie/Core/Models/ChallengeRun.swift
@Model final class ChallengeRun {
  @Attribute(.unique) var runId: String
  var templateId: String
  var tier: String
  var startedAt: Date
  var expiresAt: Date
  var status: String             // "active" | "completed" | "expired"
  var completedAt: Date?
  var coinsAwarded: Int?
  // Snapshots
  var targetSnapshot: Double
  var rewardSnapshot: Int
  var metricSnapshot: String
  var shapeSnapshot: String
  var windowDaysSnapshot: Int
}
```

`ChallengeRun.progress` is **not** stored — it's a computed property over `DailyLog`s in `[startedAt, expiresAt]` aggregated per `shapeSnapshot` and `metricSnapshot`.

### Cooldown is derived

A template is in cooldown if `∃ ChallengeRun(templateId, status == .expired, expiresAt > now - run.windowDaysSnapshot·86400)`. Note: cooldown length comes from the run's **snapshot**, not the live template — so editing `windowDays` on a template doesn't retroactively shrink or extend a user's pending cooldown. No timer/state to maintain.

## Components

### New files

```
TamaGoosie/Features/Challenges/
├── ChallengesView.swift                // replace placeholder
├── ChallengeListSection.swift          // "Active" + "Browse" renderers
├── ChallengeCard.swift                 // active + browse variants
├── ChallengeDetailSheet.swift          // tap browse card → details + Start
├── ChallengeCompletionSheet.swift      // post-completion celebration
└── ChallengeViewModel.swift            // @Published active/browse/cooldown slices

TamaGoosie/Core/Models/
├── ChallengeTemplate.swift
└── ChallengeRun.swift

TamaGoosie/Core/Services/
├── ChallengeEngine.swift               // accept, recomputeActive, isInCooldown
└── ChallengeSyncService.swift          // Convex pull (templates) + push (runs)

Shared/
└── ChallengeMetric.swift               // enum, future-proofs Watch/Widget reads

convex/
├── challengeTemplates.ts               // listActive, getById
├── challengeRuns.ts                    // accept, complete, expire, listForUser
└── schema.ts                           // table defs added
```

### Touch points

- `GooseEngine.update(state:log:profile:goals:)` — call `ChallengeEngine.shared.recomputeActive(state:logs:runs:)` at the end of the existing recompute pipeline.
- `GoosieConstants.swift` — add `coinsPerChallengeTier` default fallback constants (used only when a template omits values).
- `ContentView.swift` case `4` — already routes to `ChallengesView()`; no nav wiring needed.
- `CoinAnimationView` — reused for completion, no changes.

### Intentionally not touched

- `GooseEngine.completeGoal` — challenges are independent of goals.
- `GooseSyncPayload` — challenges aren't surfaced on Watch/Widget in v1.
- `NotificationManager` — no push notifications in v1.

## Progress, lifecycle, and the recompute path

### Single recompute call

`ChallengeEngine.shared.recomputeActive(state:logs:runs:)` is the only function that mutates `ChallengeRun.status`. It's called from exactly three places:

1. End of `GooseEngine.update(...)` — covers HealthKit sync, scene-foreground, goal completion.
2. `ChallengesView.onAppear` — covers opening the tab without an intervening `update`.
3. End of `ChallengeEngine.accept(template:tier:)` — gives a freshly accepted run its initial progress (possibly same-day completion).

### Recompute body (pseudocode)

```
for run in runs where run.status == .active:
  if now >= run.expiresAt:
    run.status = .expired              // expiry is a clock check
    persist + push to Convex
    continue

  progress = aggregate(
    metric: run.metricSnapshot,
    shape:  run.shapeSnapshot,
    logs:   logs in [run.startedAt, now],
    target: run.targetSnapshot,
  )

  if reached(progress, run.targetSnapshot):
    run.status       = .completed
    run.completedAt  = now
    run.coinsAwarded = run.rewardSnapshot
    state.coins     += run.coinsAwarded
    persist + push to Convex
    queue completion sheet
```

### Aggregation per shape

- **`cumulative`** → `sum(dailyLog.metricValue for day in window)`. Done when sum ≥ target.
- **`dailyCeiling`** → count of consecutive in-window days where `metricValue <= target`. Done when count ≥ `windowDays`. A failing day resets the counter but does **not** expire the run — user can recover on subsequent days if the window allows.

### Accept flow

```
ChallengeEngine.accept(template, tier):
  guard activeCount < 3              else throw .capReached
  guard !isInCooldown(template)      else throw .inCooldown
  guard template.isActive            else throw .templateDisabled

  run = ChallengeRun(...) at startedAt=now, expiresAt=now+window
  snapshot tier target + reward + metric + shape + windowDays onto run
  modelContext.insert(run)
  Convex.challengeRuns.accept(run)   // optimistic; queued if offline
  recomputeActive(...)               // immediate progress check
```

### Convex sync direction

- **Pull** on launch + foreground: `challengeTemplates.listActive()`, `challengeRuns.listForUser(userId)`. Reconcile into SwiftData by `templateId` / `runId`.
- **Push** on every status change: fire-and-forget; on failure, local is the truth and next pull reconciles.
- **Server-side validators** on `accept` and `complete` re-check cap, cooldown, and run ownership. A tampered client can't break invariants.

### Edge cases

| Case | Behavior |
|---|---|
| Two devices accept the same template simultaneously | Convex `accept` is atomic; second call returns the existing run. |
| Backfilled `DailyLog` flips a past day after user saw progress | Counter recomputes; UI shows lower count. Completion is terminal — no rollback. |
| Target crossed and `expiresAt` passed on same tick | Target check runs first → completion wins. |
| User changes time zone | `startedAt`/`expiresAt` are absolute epoch ms; `DailyLog` is calendar-day local. Acceptable v1 quirk for jet-lagged users; documented. |
| Convex unreachable on accept | Local insert succeeds; sync retried on next foreground. If server later rejects (e.g., cap exceeded on another device), local run reverts with a toast. |

## UI breakdown (Layout A)

```
ScrollView {
  ChallengeHeader(coinBalance:, activeCount:, cap: 3)
  ChallengeListSection(.active, runs: activeRuns)        // hidden when empty
  ChallengeListSection(.browse, templates: browseable)   // includes cooldown + cap-disabled
}
.refreshable { await sync.pullLatest() }
.background(GrassyBackgroundView())
```

### Active card

- White card, gold 2px border.
- Title + tier chip.
- Meta: `"50,000 steps · 4 days left"` from `expiresAt`.
- Progress bar for `cumulative`; `"2/3 days holding"` text for `dailyCeiling`.
- Bottom: `🪙 80 on complete` in muted gold.
- Long-press → action sheet with **Abandon** (sets status `.expired`, starts cooldown).

### Browse card

- White card, no border.
- Title + blurb.
- Three tier chips visible inline.
- States:
  - **Available** → tap → `ChallengeDetailSheet`.
  - **Cooldown** → grayscale, badge `"Available in 3d"`, not tappable.
  - **Cap reached** → normal color, tap shows toast `"Finish one to start another"`.

### Detail sheet

- Title + full blurb + "how it works" copy.
- Segmented tier picker (default = Silver).
- Live row showing target + coin reward for picked tier.
- Big **Start** button. Disabled with explanation if cap reached or template disabled.

### Completion sheet

- Triggered when `recomputeActive` produces a new `.completed` run.
- Sheet with confetti, template title, tier, coin amount; fires `CoinAnimationView` then dismisses.
- One sheet at a time — additional completions queue.

### Empty states

- No actives → section hidden entirely.
- All templates in cooldown → calm `GoosieCard` (`"Caught up. New challenges land regularly."`). Copy avoids promising a schedule.
- Offline with no SwiftData cache → friendly retry card.

### Visual language

- Reuses `GoosieTheme`, `GoosieCard`, `PillButton`.
- Card radii + spacing match Goals/ScreenTime tabs.
- Only new asset: tier ribbon icon (SF Symbol `medal.fill` tinted is fine for v1).

## Error handling, edge cases, and invariants

### Trusted boundaries (no defensive code)

- `DailyLog` values from `HealthKitManager` — already trusted by `RewardEngine`.
- `GooseState.coins` writes — single-writer paths only (`ChallengeEngine.recomputeActive`, `GooseEngine.completeGoal`); SwiftData on main actor.

### Validated boundaries

| Boundary | Validation | On failure |
|---|---|---|
| Convex → SwiftData reconcile | Decode each row; skip malformed templates with `Logger` warning. | Skip row, render rest. Never crashes. |
| `ChallengeEngine.accept` | Cap ≤ 3, no cooldown, template active. | Throws typed `ChallengeError`; UI shows inline toast. |
| Convex `accept` mutation (server) | Re-checks cap + cooldown atomically. | Returns existing run if duplicate; 409-style error if cross-device race. Client reverts local + toasts. |
| Convex `complete` mutation (server) | Verifies run ownership + `status == active`. | If already completed/expired, no-op. Status mismatch → client takes server as truth. |
| Encoding to Convex | All `Int` → `Double` cast at sync-service boundary. | Compile-enforced by a thin wrapper. |

### Hard invariants

1. `activeRuns.count <= 3` — enforced client + server.
2. `coinsAwarded` set **exactly once** per run, on `active → completed`.
3. `status` is monotonic: `active → (completed | expired)`. No reverse transitions.
4. `expiresAt > startedAt`; both immutable after insert.

Violations trigger `assertionFailure` in dev builds.

### Concurrency

- `recomputeActive` runs on main actor (SwiftData). Idempotent, cheap.
- `ChallengeSyncService` does network on background `Task`, hops to main for writes. Same pattern as `WatchSyncService`.

### Failure modes the user sees

- Offline accept: succeeds locally, syncs later, no warning.
- Offline completion: coins awarded locally; syncs later. If server rejects (extreme clock skew), log entry created but coins are **not** clawed back.
- Convex schema mismatch post-deploy: bad templates fail to decode → browse shows empty state with retry. Active runs continue to recompute from their snapshot.

## Testing

### Unit (`ChallengeEngineTests.swift`)

- `recomputeActive` for `cumulative`: under target, at target, above target (no double-complete).
- `recomputeActive` for `dailyCeiling`: all under, one over (counter resets, no expire), retroactive flip after completion (no rollback).
- Expiry: clean expiry, target-crossed-on-expiry-tick (target wins).
- `accept`: third succeeds, fourth throws `.capReached`, expired template within cooldown throws `.inCooldown`, disabled template throws `.templateDisabled`.
- Snapshot freezing: editing template post-accept doesn't change run.

### Integration (`ChallengeFlowTests.swift`)

In-memory `ModelContainer`, seeded `UserProfile` + `GooseState` + synthetic `DailyLog`s:

- Accept Silver "Step it up" with 60k over 5 days → completes; coin total matches.
- Accept Bronze anti-goal, breach on day 2, hold days 3–4 → still completes on day 4.
- Three accepts succeed; fourth throws.
- Force-expire a run; `isInCooldown` true; `accept` throws; advance clock past cooldown; accept succeeds.

### Convex (`convex/__tests__/challengeRuns.test.ts`)

- `accept` enforces cap + cooldown server-side; duplicates return same run.
- `complete` idempotent — second call no-op, no double-award.
- Tampered status transitions rejected (`completed → active`).
- All `number` validators receive `Float64`.

### E2E / UI (XCUITest, `ChallengesUITests.swift`)

Only load-bearing flows:

- Tab opens → "Active" hidden, "Browse" populated.
- Browse card → detail sheet → Gold → Start → card lands in Active with correct meta.
- Fourth attempt while three active → toast appears, no sheet.
- Force-complete via test hook → completion sheet, coin pill increments.

### Manual QA

- Offline accept → kill app → reopen → run still active.
- 8h backgrounded → countdown correct on foreground.
- Convex redeploy with broken template → tab still loads, broken hidden.
- Time-zone change → no crash; progress recomputes against local-day logs.

### Out of scope for v1 tests

- Performance: 12 templates × ≤3 active × ≤31-day windows is tiny.
- Snapshot/visual regression: not wired in repo.
- Watch/Widget: nothing to test (not exposed).

## Constants to add

```swift
// Shared/Constants.swift additions
extension GoosieConstants {
  static let challengeActiveCap = 3
  static let challengeCategoriesV1 = ["health"]
  // Fallbacks only — templates carry their own values
  static let defaultBronzeReward = 25
  static let defaultSilverReward = 60
  static let defaultGoldReward   = 120
}
```

## Open questions deferred to plan / future

- Seed library content (the 12 templates × 3 tiers) — authored during implementation, not part of this design.
- "Done" / history surface — deferred to a v1.1 if usage shows demand.
- Group quests — v2 Phase 6, this scaffold is forward-compatible.
- Server-side stat validation against HealthKit (anti-cheat) — only matters when leaderboards land (v2 Phase 6); v1 ships without it.

## References

- `docs/architecture.md` — three-target topology, sync diagram.
- `docs/models.md` — existing SwiftData models for context.
- Obsidian: `Projects/TamaGoosie/vision-v2-gamification.md` — v2 phasing this design respects.
- Obsidian: `Projects/TamaGoosie/sources/2026-05-26-pokemon-sleep-game-mechanics.md` — Tier-1 PS patterns informing the tier system.
- Memory: `feedback_convex_int_encoding.md` — Swift→Convex number encoding gotcha.
- Memory: `feedback_zstack_color_hittest.md` — apply to `ChallengesView` `ScrollView` background.
