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
