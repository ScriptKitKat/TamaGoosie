import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

const dailyLogValidator = v.object({
  date: v.number(),
  steps: v.number(),
  exerciseMinutes: v.number(),
  sleepHours: v.number(),
  standHours: v.number(),
  sittingHours: v.number(),
  outsideMinutes: v.number(),
  distractionOpens: v.number(),
  distractionMinutes: v.number(),
  goalsCompleted: v.number(),
  goalsTotal: v.number(),
  endOfDayHealthiness: v.number(),
  endOfDayHappiness: v.number(),
});

export const syncDailyLogs = mutation({
  args: {
    userId: v.id("users"),
    logs: v.array(dailyLogValidator),
  },
  handler: async (ctx, args) => {
    for (const log of args.logs) {
      const existing = await ctx.db
        .query("dailyLogs")
        .withIndex("by_userId_and_date", (q) =>
          q.eq("userId", args.userId).eq("date", log.date)
        )
        .first();

      if (existing) {
        await ctx.db.patch(existing._id, {
          steps: log.steps,
          exerciseMinutes: log.exerciseMinutes,
          sleepHours: log.sleepHours,
          standHours: log.standHours,
          sittingHours: log.sittingHours,
          outsideMinutes: log.outsideMinutes,
          distractionOpens: log.distractionOpens,
          distractionMinutes: log.distractionMinutes,
          goalsCompleted: log.goalsCompleted,
          goalsTotal: log.goalsTotal,
          endOfDayHealthiness: log.endOfDayHealthiness,
          endOfDayHappiness: log.endOfDayHappiness,
        });
      } else {
        await ctx.db.insert("dailyLogs", {
          userId: args.userId,
          ...log,
        });
      }
    }
  },
});

export const getDailyLogs = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("dailyLogs")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .take(365);
  },
});
