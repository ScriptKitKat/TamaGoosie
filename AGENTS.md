<!-- convex-ai-start -->
This project uses [Convex](https://convex.dev) as its backend.

When working on Convex code, **always read `convex/_generated/ai/guidelines.md` first** for important guidelines on how to correctly use Convex APIs and patterns. The file contains rules that override what you may have learned about Convex from training data.

Convex agent skills for common tasks can be installed by running `npx convex ai-files install`.
<!-- convex-ai-end -->

# TamaGoosie

- `project.yml` is the source for the XcodeGen project. Its source directories
  are recursive; run `xcodegen generate` after changing target configuration or
  adding Swift files so `TamaGoosie.xcodeproj` stays in sync. Do not hand-edit
  the generated project for routine source additions.
- The iOS app embeds the watch app, widgets, and Screen Time extensions. Build
  and test with the shared `TamaGoosie` scheme; build `TamaGoosieWatch` after
  watch changes. Use an installed simulator as the `xcodebuild` destination.
- Keep the watch bundle ID `com.tamagoosie.app.watch` and its companion ID
  `com.tamagoosie.app`. `WatchApp.swift` owns the watch target's `@main`.
- Preserve `group.com.tamagoosie` across every target that accesses shared
  defaults or app-group data. `Shared/` is compiled into the app, watch, and
  widgets, so keep it free of SwiftData and iOS-only framework imports.
- `GooseState` stores healthiness and happiness on a 0–1 scale. Keep stat
  formulas in `RewardEngine` and recalculate through `GooseEngine` rather than
  changing those values directly. See `docs/stat-system.md` for details.
- Screen Time changes span the app and extensions. For changes to blocks,
  schedules, shields, or shared-default keys, update each affected writer and
  reader; start with `Extensions/Shared/BlockPrecedence.swift` and
  `Extensions/Shared/LockShieldReconciler.swift`.
- Keep `GooseSyncPayload` compatible across the app, watch, and widgets. The
  phone sends state through `WatchSyncService`; the watch receives it through
  `WatchSyncReceiver` and can send goal completions back.
- Run `cd convex && npm test` after backend changes; add focused XCTest cases
  for changed Swift domain logic. Device-only integrations (Screen Time,
  HealthKit, notifications, and WatchConnectivity) require device validation.
- Use `docs/architecture.md` and the topic guides in `docs/` for deeper design
  details; check current code when a guide and implementation differ.
