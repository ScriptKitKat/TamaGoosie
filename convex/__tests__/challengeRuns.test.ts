import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "../schema";
import { api } from "../_generated/api";
import type { Id } from "../_generated/dataModel";

// Convex functions live as siblings of node_modules inside this `convex/`
// directory. Glob them so convex-test can resolve them at runtime.
const modules = import.meta.glob("../**/*.ts");

async function seedUser(t: ReturnType<typeof convexTest>): Promise<Id<"users">> {
  return await t.run(async (ctx) =>
    ctx.db.insert("users", {
      authProvider: "email",
      emailUserID: "u@example.com",
      username: "u",
      createdAt: 0,
    })
  );
}

const acceptArgs = (
  overrides: Partial<{
    runId: string;
    templateId: string;
    userId: Id<"users">;
    startedAt: number;
  }> = {}
) => ({
  runId: overrides.runId ?? "r1",
  userId: overrides.userId as Id<"users">,
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
  const t = convexTest(schema, modules);
  const userId = await seedUser(t);
  for (let i = 0; i < 3; i++) {
    await t.mutation(api.challengeRuns.accept, {
      ...acceptArgs({ runId: `r${i}`, templateId: `t${i}`, userId }),
    });
  }
  await expect(
    t.mutation(api.challengeRuns.accept, {
      ...acceptArgs({ runId: "r3", templateId: "t3", userId }),
    })
  ).rejects.toThrow("capReached");
});

test("duplicate runId returns the existing run, no second insert", async () => {
  const t = convexTest(schema, modules);
  const userId = await seedUser(t);
  const a = await t.mutation(api.challengeRuns.accept, acceptArgs({ userId }));
  const b = await t.mutation(api.challengeRuns.accept, acceptArgs({ userId }));
  expect(a).toEqual(b);
  const all = await t.query(api.challengeRuns.listForUser, { userId });
  expect(all.length).toBe(1);
});

test("complete is idempotent — second call is no-op", async () => {
  const t = convexTest(schema, modules);
  const userId = await seedUser(t);
  await t.mutation(api.challengeRuns.accept, acceptArgs({ userId }));
  await t.mutation(api.challengeRuns.complete, {
    runId: "r1",
    userId,
    completedAt: 2_000_000_000_000,
    coinsAwarded: 60,
  });
  await t.mutation(api.challengeRuns.complete, {
    runId: "r1",
    userId,
    completedAt: 9_000_000_000_000,
    coinsAwarded: 9_999,
  });
  const [run] = await t.query(api.challengeRuns.listForUser, { userId });
  expect(run.status).toBe("completed");
  expect(run.coinsAwarded).toBe(60);
});

test("complete from wrong userId throws forbidden", async () => {
  const t = convexTest(schema, modules);
  const owner = await seedUser(t);
  const intruder = await seedUser(t);
  await t.mutation(api.challengeRuns.accept, acceptArgs({ userId: owner }));
  await expect(
    t.mutation(api.challengeRuns.complete, {
      runId: "r1",
      userId: intruder,
      completedAt: 0,
      coinsAwarded: 1,
    })
  ).rejects.toThrow("forbidden");
});

test("expired-with-cooldown blocks re-accept", async () => {
  const t = convexTest(schema, modules);
  const userId = await seedUser(t);
  const startedAt = 1_000_000_000_000;
  await t.mutation(api.challengeRuns.accept, acceptArgs({ userId, startedAt }));
  await t.mutation(api.challengeRuns.expire, { runId: "r1", userId });
  // try to re-accept at startedAt + 8 days (cooldown ends at startedAt + 14 days)
  await expect(
    t.mutation(api.challengeRuns.accept, acceptArgs({
      userId,
      runId: "r2",
      startedAt: startedAt + 8 * 86_400_000,
    }))
  ).rejects.toThrow("inCooldown");
});
