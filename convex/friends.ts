import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const sendFriendRequest = mutation({
  args: {
    fromUserId: v.id("users"),
    toUserId: v.id("users"),
  },
  handler: async (ctx, args) => {
    if (args.fromUserId === args.toUserId) {
      throw new Error("Cannot send a friend request to yourself");
    }

    // Check no existing pending/accepted in either direction
    const existing1 = await ctx.db
      .query("friendRequests")
      .withIndex("by_pair", (q) =>
        q.eq("fromUserId", args.fromUserId).eq("toUserId", args.toUserId)
      )
      .first();
    if (existing1 && existing1.status !== "declined") {
      throw new Error("Friend request already exists");
    }

    const existing2 = await ctx.db
      .query("friendRequests")
      .withIndex("by_pair", (q) =>
        q.eq("fromUserId", args.toUserId).eq("toUserId", args.fromUserId)
      )
      .first();
    if (existing2 && existing2.status !== "declined") {
      throw new Error("Friend request already exists");
    }

    // If there's a declined request, replace it
    if (existing1?.status === "declined") {
      await ctx.db.patch(existing1._id, {
        status: "pending",
        createdAt: Date.now(),
      });
      return existing1._id;
    }

    return await ctx.db.insert("friendRequests", {
      fromUserId: args.fromUserId,
      toUserId: args.toUserId,
      status: "pending",
      createdAt: Date.now(),
    });
  },
});

export const acceptFriendRequest = mutation({
  args: { requestId: v.id("friendRequests") },
  handler: async (ctx, args) => {
    const request = await ctx.db.get(args.requestId);
    if (!request) throw new Error("Request not found");
    if (request.status !== "pending") throw new Error("Request is not pending");

    await ctx.db.patch(args.requestId, { status: "accepted" });
  },
});

export const declineFriendRequest = mutation({
  args: { requestId: v.id("friendRequests") },
  handler: async (ctx, args) => {
    const request = await ctx.db.get(args.requestId);
    if (!request) throw new Error("Request not found");
    if (request.status !== "pending") throw new Error("Request is not pending");

    await ctx.db.patch(args.requestId, { status: "declined" });
  },
});

export const cancelFriendRequest = mutation({
  args: { requestId: v.id("friendRequests") },
  handler: async (ctx, args) => {
    const request = await ctx.db.get(args.requestId);
    if (!request) throw new Error("Request not found");
    if (request.status !== "pending") throw new Error("Request is not pending");

    await ctx.db.delete(args.requestId);
  },
});

export const removeFriend = mutation({
  args: {
    userId: v.id("users"),
    friendId: v.id("users"),
  },
  handler: async (ctx, args) => {
    // Find accepted request in either direction
    const req1 = await ctx.db
      .query("friendRequests")
      .withIndex("by_pair", (q) =>
        q.eq("fromUserId", args.userId).eq("toUserId", args.friendId)
      )
      .first();
    if (req1?.status === "accepted") {
      await ctx.db.delete(req1._id);
      return;
    }

    const req2 = await ctx.db
      .query("friendRequests")
      .withIndex("by_pair", (q) =>
        q.eq("fromUserId", args.friendId).eq("toUserId", args.userId)
      )
      .first();
    if (req2?.status === "accepted") {
      await ctx.db.delete(req2._id);
      return;
    }

    throw new Error("Friendship not found");
  },
});

export const getFriends = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    // Get all accepted requests where user is sender
    const sentAccepted = await ctx.db
      .query("friendRequests")
      .withIndex("by_fromUser_status", (q) =>
        q.eq("fromUserId", args.userId).eq("status", "accepted")
      )
      .collect();

    // Get all accepted requests where user is receiver
    const receivedAccepted = await ctx.db
      .query("friendRequests")
      .withIndex("by_toUser_status", (q) =>
        q.eq("toUserId", args.userId).eq("status", "accepted")
      )
      .collect();

    const friendIds = [
      ...sentAccepted.map((r) => r.toUserId),
      ...receivedAccepted.map((r) => r.fromUserId),
    ];

    // Fetch user + goose data for each friend
    const friends = await Promise.all(
      friendIds.map(async (friendId) => {
        const user = await ctx.db.get(friendId);
        if (!user) return null;

        const goose = await ctx.db
          .query("geese")
          .withIndex("by_userId", (q) => q.eq("userId", friendId))
          .first();

        return {
          _id: user._id,
          username: user.username,
          goose: goose
            ? {
                happiness: goose.happiness,
                healthiness: goose.healthiness,
                mood: goose.mood,
                gooseName: goose.gooseName,
                spriteID: goose.spriteID,
                streakDays: goose.streakDays,
                lastUpdated: goose.lastUpdated,
              }
            : null,
        };
      })
    );

    return friends.filter((f) => f !== null);
  },
});

export const getPendingRequests = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const requests = await ctx.db
      .query("friendRequests")
      .withIndex("by_toUser_status", (q) =>
        q.eq("toUserId", args.userId).eq("status", "pending")
      )
      .collect();

    return await Promise.all(
      requests.map(async (req) => {
        const sender = await ctx.db.get(req.fromUserId);
        return {
          _id: req._id,
          fromUsername: sender?.username ?? "unknown",
          fromUserId: req.fromUserId,
          createdAt: req.createdAt,
        };
      })
    );
  },
});

export const getOutgoingRequests = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const requests = await ctx.db
      .query("friendRequests")
      .withIndex("by_fromUser_status", (q) =>
        q.eq("fromUserId", args.userId).eq("status", "pending")
      )
      .collect();

    return await Promise.all(
      requests.map(async (req) => {
        const recipient = await ctx.db.get(req.toUserId);
        return {
          _id: req._id,
          toUsername: recipient?.username ?? "unknown",
          toUserId: req.toUserId,
          createdAt: req.createdAt,
        };
      })
    );
  },
});
