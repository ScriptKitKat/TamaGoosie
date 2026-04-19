import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const syncGoals = mutation({
  args: {
    userId: v.id("users"),
    goals: v.array(
      v.object({
        title: v.string(),
        type: v.string(),
        category: v.string(),
        frequency: v.string(),
        targetCount: v.number(),
        happinessWeight: v.number(),
        sortOrder: v.number(),
        isActive: v.boolean(),
        customDays: v.optional(v.string()),
      })
    ),
  },
  handler: async (ctx, args) => {
    // Get all existing goals for this user
    const existing = await ctx.db
      .query("goals")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    // Build a map of existing goals by title+category (stable key)
    const existingMap = new Map<string, (typeof existing)[0]>();
    for (const goal of existing) {
      existingMap.set(`${goal.title}::${goal.category}`, goal);
    }

    // Track which existing goals are still present
    const seenKeys = new Set<string>();

    for (const goal of args.goals) {
      const key = `${goal.title}::${goal.category}`;
      seenKeys.add(key);

      const existingGoal = existingMap.get(key);
      if (existingGoal) {
        // Update existing goal
        await ctx.db.patch(existingGoal._id, {
          type: goal.type,
          frequency: goal.frequency,
          targetCount: goal.targetCount,
          happinessWeight: goal.happinessWeight,
          sortOrder: goal.sortOrder,
          isActive: goal.isActive,
          customDays: goal.customDays,
        });
      } else {
        // Insert new goal
        await ctx.db.insert("goals", {
          userId: args.userId,
          title: goal.title,
          type: goal.type,
          category: goal.category,
          frequency: goal.frequency,
          targetCount: goal.targetCount,
          happinessWeight: goal.happinessWeight,
          sortOrder: goal.sortOrder,
          isActive: goal.isActive,
          customDays: goal.customDays,
          createdAt: Date.now(),
        });
      }
    }

    // Delete goals that are no longer present
    for (const goal of existing) {
      const key = `${goal.title}::${goal.category}`;
      if (!seenKeys.has(key)) {
        await ctx.db.delete(goal._id);
      }
    }
  },
});

export const getGoals = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("goals")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
  },
});
