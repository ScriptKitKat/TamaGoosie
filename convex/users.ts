import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const createUser = mutation({
  args: {
    authProvider: v.string(),
    appleUserID: v.optional(v.string()),
    googleUserID: v.optional(v.string()),
    username: v.string(),
    displayName: v.optional(v.string()),
    email: v.optional(v.string()),
    avatarURL: v.optional(v.string()),
    gooseName: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const normalized = args.username.toLowerCase().trim();

    // Validate username format
    if (normalized.length < 3 || normalized.length > 20) {
      throw new Error("Username must be 3–20 characters");
    }
    if (!/^[a-z][a-z0-9_]*$/.test(normalized)) {
      throw new Error(
        "Username must start with a letter and contain only lowercase letters, numbers, and underscores"
      );
    }

    // Check username uniqueness
    const existingUsername = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", normalized))
      .first();
    if (existingUsername) {
      throw new Error("Username is already taken");
    }

    // Check auth provider ID not already registered
    if (args.authProvider === "apple" && args.appleUserID) {
      const existing = await ctx.db
        .query("users")
        .withIndex("by_apple_id", (q) => q.eq("appleUserID", args.appleUserID))
        .first();
      if (existing) {
        throw new Error("This Apple ID already has an account");
      }
    } else if (args.authProvider === "google" && args.googleUserID) {
      const existing = await ctx.db
        .query("users")
        .withIndex("by_google_id", (q) =>
          q.eq("googleUserID", args.googleUserID)
        )
        .first();
      if (existing) {
        throw new Error("This Google account already has an account");
      }
    }

    const userId = await ctx.db.insert("users", {
      authProvider: args.authProvider,
      appleUserID: args.appleUserID,
      googleUserID: args.googleUserID,
      username: normalized,
      displayName: args.displayName,
      email: args.email,
      avatarURL: args.avatarURL,
      createdAt: Date.now(),
    });

    // Create empty goose row
    await ctx.db.insert("geese", {
      userId,
      happiness: 0.7,
      healthiness: 0.8,
      mood: "content",
      gooseName: args.gooseName ?? "Harold",
      spriteID: "default",
      streakDays: 0,
      lastUpdated: Date.now(),
    });

    return userId;
  },
});

// Look up user by auth provider ID (used on app launch to restore session)
export const getUserByAuthID = query({
  args: {
    authProvider: v.string(),
    authUserID: v.string(),
  },
  handler: async (ctx, args) => {
    if (args.authProvider === "apple") {
      return await ctx.db
        .query("users")
        .withIndex("by_apple_id", (q) => q.eq("appleUserID", args.authUserID))
        .first();
    } else if (args.authProvider === "google") {
      return await ctx.db
        .query("users")
        .withIndex("by_google_id", (q) =>
          q.eq("googleUserID", args.authUserID)
        )
        .first();
    }
    return null;
  },
});

// Look up a user's goose by their Convex user ID
export const getGooseByUserId = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("geese")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
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
    if (!/^[a-z][a-z0-9_]*$/.test(normalized)) return false;

    const existing = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", normalized))
      .first();
    return existing === null;
  },
});
