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
    if (!run) return null;
    if (run.userId !== args.userId) throw new Error("forbidden");
    if (run.status !== "active") return run._id;

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
