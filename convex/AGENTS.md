<!-- convex-ai-start -->
This project uses [Convex](https://convex.dev) as its backend.

When working on Convex code, **always read `convex/_generated/ai/guidelines.md` first** for important guidelines on how to correctly use Convex APIs and patterns. The file contains rules that override what you may have learned about Convex from training data.

Convex agent skills for common tasks can be installed by running `npx convex ai-files install`.
<!-- convex-ai-end -->

- Keep schema changes compatible with Swift DTOs and client calls in
  `../TamaGoosie/Core/Services/ConvexManager.swift` and sync services.
- Swift `Int` values are deliberately converted to `Double` where the schema
  uses `v.number()`; update both sides together if that contract changes.
- Run `npm test` and add focused coverage under `__tests__/` for backend
  behavior changes.
