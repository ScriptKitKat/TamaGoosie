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
});
