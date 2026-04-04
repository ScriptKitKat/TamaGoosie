import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const createUser = mutation({
  args: {
    deviceId: v.string(),
    username: v.string(),
  },
  handler: async (ctx, args) => {
    const normalized = args.username.toLowerCase().trim();

    // Validate username format
    if (normalized.length < 3 || normalized.length > 20) {
      throw new Error("Username must be 3–20 characters");
    }
    if (!/^[a-z0-9_]+$/.test(normalized)) {
      throw new Error("Username can only contain lowercase letters, numbers, and underscores");
    }

    // Check uniqueness
    const existing = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", normalized))
      .first();
    if (existing) {
      throw new Error("Username is already taken");
    }

    // Check deviceId not already registered
    const existingDevice = await ctx.db
      .query("users")
      .withIndex("by_deviceId", (q) => q.eq("deviceId", args.deviceId))
      .first();
    if (existingDevice) {
      throw new Error("Device already has an account");
    }

    const userId = await ctx.db.insert("users", {
      deviceId: args.deviceId,
      username: normalized,
      createdAt: Date.now(),
    });

    // Create empty goose row
    await ctx.db.insert("geese", {
      userId,
      happiness: 0.7,
      healthiness: 0.8,
      mood: "content",
      gooseName: "Harold",
      spriteID: "default",
      streakDays: 0,
      lastUpdated: Date.now(),
    });

    return userId;
  },
});

export const getUserByDeviceId = query({
  args: { deviceId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("users")
      .withIndex("by_deviceId", (q) => q.eq("deviceId", args.deviceId))
      .first();
  },
});

export const searchUsers = query({
  args: {
    queryText: v.string(),
    currentUserId: v.id("users"),
  },
  handler: async (ctx, args) => {
    if (args.queryText.trim().length < 2) return [];

    const results = await ctx.db
      .query("users")
      .withSearchIndex("search_username", (q) =>
        q.search("username", args.queryText.toLowerCase())
      )
      .take(20);

    // Filter out self
    const filtered = results.filter((u) => u._id !== args.currentUserId);

    // For each result, check friendship/request status
    const enriched = await Promise.all(
      filtered.map(async (user) => {
        // Check if already friends (accepted request in either direction)
        const friendAsFrom = await ctx.db
          .query("friendRequests")
          .withIndex("by_pair", (q) =>
            q.eq("fromUserId", args.currentUserId).eq("toUserId", user._id)
          )
          .first();
        const friendAsTo = await ctx.db
          .query("friendRequests")
          .withIndex("by_pair", (q) =>
            q.eq("fromUserId", user._id).eq("toUserId", args.currentUserId)
          )
          .first();

        let status: "none" | "pending_sent" | "pending_received" | "friends" =
          "none";
        if (
          friendAsFrom?.status === "accepted" ||
          friendAsTo?.status === "accepted"
        ) {
          status = "friends";
        } else if (friendAsFrom?.status === "pending") {
          status = "pending_sent";
        } else if (friendAsTo?.status === "pending") {
          status = "pending_received";
        }

        return {
          _id: user._id,
          username: user.username,
          status,
        };
      })
    );

    return enriched;
  },
});

export const checkUsernameAvailable = query({
  args: { username: v.string() },
  handler: async (ctx, args) => {
    const normalized = args.username.toLowerCase().trim();
    if (normalized.length < 3 || normalized.length > 20) return false;
    if (!/^[a-z0-9_]+$/.test(normalized)) return false;

    const existing = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", normalized))
      .first();
    return existing === null;
  },
});
