import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    // Auth — supports Apple, Google, and email sign-in
    authProvider: v.string(), // "apple" | "google" | "email"
    appleUserID: v.optional(v.string()),
    googleUserID: v.optional(v.string()),
    emailUserID: v.optional(v.string()),
    username: v.string(),
    // Profile (from auth provider, optional)
    displayName: v.optional(v.string()),
    email: v.optional(v.string()),
    avatarURL: v.optional(v.string()),
    createdAt: v.number(),
  })
    .index("by_username", ["username"])
    .index("by_apple_id", ["appleUserID"])
    .index("by_google_id", ["googleUserID"])
    .index("by_email_id", ["emailUserID"])
    .searchIndex("search_username", { searchField: "username" }),

  friendRequests: defineTable({
    fromUserId: v.id("users"),
    toUserId: v.id("users"),
    status: v.union(
      v.literal("pending"),
      v.literal("accepted"),
      v.literal("declined")
    ),
    createdAt: v.number(),
  })
    .index("by_toUser_status", ["toUserId", "status"])
    .index("by_fromUser_status", ["fromUserId", "status"])
    .index("by_pair", ["fromUserId", "toUserId"]),

  geese: defineTable({
    userId: v.id("users"),
    happiness: v.number(),
    healthiness: v.number(),
    mood: v.string(),
    gooseName: v.string(),
    spriteID: v.string(),
    streakDays: v.number(),
    lastUpdated: v.number(),
  }).index("by_userId", ["userId"]),

  goals: defineTable({
    userId: v.id("users"),
    title: v.string(),
    type: v.string(),
    category: v.string(),
    frequency: v.string(),
    targetCount: v.number(),
    happinessWeight: v.number(),
    sortOrder: v.number(),
    isActive: v.boolean(),
    customDays: v.optional(v.string()),
    createdAt: v.number(),
  }).index("by_userId", ["userId"]),

  dailyLogs: defineTable({
    userId: v.id("users"),
    date: v.number(), // epoch ms for start-of-day
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
  })
    .index("by_userId", ["userId"])
    .index("by_userId_and_date", ["userId", "date"]),

  challengeTemplates: defineTable({
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
  })
    .index("by_templateId", ["templateId"])
    .index("by_active", ["active", "sortHint"]),

  challengeRuns: defineTable({
    runId: v.string(),
    userId: v.id("users"),
    templateId: v.string(),
    tier: v.union(v.literal("bronze"), v.literal("silver"), v.literal("gold")),
    startedAt: v.number(),
    expiresAt: v.number(),
    status: v.union(v.literal("active"), v.literal("completed"), v.literal("expired")),
    completedAt: v.union(v.number(), v.null()),
    coinsAwarded: v.union(v.number(), v.null()),
    targetSnapshot: v.number(),
    rewardSnapshot: v.number(),
    metricSnapshot: v.string(),
    shapeSnapshot: v.string(),
    windowDaysSnapshot: v.number(),
  })
    .index("by_runId", ["runId"])
    .index("by_user_status", ["userId", "status"])
    .index("by_user_template", ["userId", "templateId"]),
});
