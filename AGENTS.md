<!-- convex-ai-start -->
This project uses [Convex](https://convex.dev) as its backend.

When working on Convex code, **always read `convex/_generated/ai/guidelines.md` first** for important guidelines on how to correctly use Convex APIs and patterns. The file contains rules that override what you may have learned about Convex from training data.

Convex agent skills for common tasks can be installed by running `npx convex ai-files install`.
<!-- convex-ai-end -->

# TamaGoosie

- Add new Swift source files to the appropriate target in Xcode. This project
  uses standard Xcode groups, not folder-synchronised groups.
- Preserve `group.com.tamagoosie` across every target that accesses shared
  defaults or app-group data.
- Screen Time changes span the app and extensions. For changes to blocks,
  schedules, shields, or shared-default keys, update each affected writer and
  reader; start with `Extensions/Shared/BlockPrecedence.swift` and
  `Extensions/Shared/LockShieldReconciler.swift`.
- Keep watch payloads compatible with `WatchSyncService` and
  `WatchSyncReceiver`.
- Run `cd convex && npm test` after backend changes; add focused XCTest cases
  for changed Swift domain logic. Device-only integrations (Screen Time,
  HealthKit, notifications, and WatchConnectivity) require device validation.
