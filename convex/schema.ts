import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    deviceId: v.string(),
    username: v.string(),
    createdAt: v.number(),
  })
    .index("by_deviceId", ["deviceId"])
    .index("by_username", ["username"])
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
});
