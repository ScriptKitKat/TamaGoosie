import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const upsertGooseState = mutation({
  args: {
    userId: v.id("users"),
    happiness: v.number(),
    healthiness: v.number(),
    mood: v.string(),
    gooseName: v.string(),
    spriteID: v.string(),
    streakDays: v.number(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("geese")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        happiness: args.happiness,
        healthiness: args.healthiness,
        mood: args.mood,
        gooseName: args.gooseName,
        spriteID: args.spriteID,
        streakDays: args.streakDays,
        lastUpdated: Date.now(),
      });
    } else {
      await ctx.db.insert("geese", {
        userId: args.userId,
        happiness: args.happiness,
        healthiness: args.healthiness,
        mood: args.mood,
        gooseName: args.gooseName,
        spriteID: args.spriteID,
        streakDays: args.streakDays,
        lastUpdated: Date.now(),
      });
    }
  },
});

export const getGooseState = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("geese")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .first();
  },
});
