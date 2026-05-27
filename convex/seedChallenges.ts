// convex/seedChallenges.ts
import { internalMutation } from "./_generated/server";

export const seed = internalMutation(async (ctx) => {
  const templates = [
    {
      templateId: "step-it-up",
      title: "Step it up",
      blurb: "Rack up steps across the week.",
      category: "health" as const,
      shape: "cumulative" as const,
      metric: "steps" as const,
      windowDays: 7,
      tiers: {
        bronze: { target: 30_000, coinReward: 25 },
        silver: { target: 50_000, coinReward: 60 },
        gold:   { target: 75_000, coinReward: 120 },
      },
      active: true,
      sortHint: 10,
    },
    {
      templateId: "sit-less",
      title: "Sit less",
      blurb: "Keep sitting time low every day.",
      category: "health" as const,
      shape: "dailyCeiling" as const,
      metric: "sittingHours" as const,
      windowDays: 3,
      tiers: {
        bronze: { target: 9, coinReward: 25 },
        silver: { target: 8, coinReward: 60 },
        gold:   { target: 7, coinReward: 120 },
      },
      active: true,
      sortHint: 20,
    },
    {
      templateId: "outdoors-week",
      title: "Outdoors week",
      blurb: "Get outside this week.",
      category: "health" as const,
      shape: "cumulative" as const,
      metric: "outsideMinutes" as const,
      windowDays: 7,
      tiers: {
        bronze: { target: 60,  coinReward: 25 },
        silver: { target: 120, coinReward: 60 },
        gold:   { target: 210, coinReward: 120 },
      },
      active: true,
      sortHint: 30,
    },
    {
      templateId: "sleep-streak",
      title: "Sleep streak",
      blurb: "Stack sleep hours over 5 nights.",
      category: "health" as const,
      shape: "cumulative" as const,
      metric: "sleepHours" as const,
      windowDays: 5,
      tiers: {
        bronze: { target: 35, coinReward: 25 },
        silver: { target: 40, coinReward: 60 },
        gold:   { target: 45, coinReward: 120 },
      },
      active: true,
      sortHint: 40,
    },
    {
      templateId: "exercise-burst",
      title: "Exercise burst",
      blurb: "Hit exercise minutes this week.",
      category: "health" as const,
      shape: "cumulative" as const,
      metric: "exerciseMinutes" as const,
      windowDays: 7,
      tiers: {
        bronze: { target: 90,  coinReward: 25 },
        silver: { target: 150, coinReward: 60 },
        gold:   { target: 210, coinReward: 120 },
      },
      active: true,
      sortHint: 50,
    },
    {
      templateId: "stand-up",
      title: "Stand up",
      blurb: "Rack up stand hours over the week.",
      category: "health" as const,
      shape: "cumulative" as const,
      metric: "standHours" as const,
      windowDays: 7,
      tiers: {
        bronze: { target: 50, coinReward: 25 },
        silver: { target: 70, coinReward: 60 },
        gold:   { target: 84, coinReward: 120 },
      },
      active: true,
      sortHint: 60,
    },
    {
      templateId: "weekend-warrior",
      title: "Weekend warrior",
      blurb: "Big steps over two days.",
      category: "health" as const,
      shape: "cumulative" as const,
      metric: "steps" as const,
      windowDays: 2,
      tiers: {
        bronze: { target: 12_000, coinReward: 25 },
        silver: { target: 20_000, coinReward: 60 },
        gold:   { target: 28_000, coinReward: 120 },
      },
      active: true,
      sortHint: 70,
    },
    {
      // Inactive until a `dailyFloor` shape lands. Kept seeded so admins see it.
      templateId: "active-trio",
      title: "Active trio",
      blurb: "Three solid exercise days this week.",
      category: "health" as const,
      shape: "dailyCeiling" as const,
      metric: "exerciseMinutes" as const,
      windowDays: 3,
      tiers: {
        bronze: { target: 999, coinReward: 25 },
        silver: { target: 999, coinReward: 60 },
        gold:   { target: 999, coinReward: 120 },
      },
      active: false,
      sortHint: 80,
    },
    {
      templateId: "sit-less-week",
      title: "Sit less (week)",
      blurb: "Hold sitting under target every day for a week.",
      category: "health" as const,
      shape: "dailyCeiling" as const,
      metric: "sittingHours" as const,
      windowDays: 7,
      tiers: {
        bronze: { target: 9, coinReward: 50 },
        silver: { target: 8, coinReward: 100 },
        gold:   { target: 7, coinReward: 180 },
      },
      active: true,
      sortHint: 90,
    },
    {
      templateId: "fresh-air-3",
      title: "Fresh air × 3",
      blurb: "Get outdoor minutes across 3 days.",
      category: "health" as const,
      shape: "cumulative" as const,
      metric: "outsideMinutes" as const,
      windowDays: 3,
      tiers: {
        bronze: { target: 30, coinReward: 25 },
        silver: { target: 60, coinReward: 60 },
        gold:   { target: 90, coinReward: 120 },
      },
      active: true,
      sortHint: 100,
    },
    {
      templateId: "stand-strong",
      title: "Stand strong",
      blurb: "Stand hours across 5 days.",
      category: "health" as const,
      shape: "cumulative" as const,
      metric: "standHours" as const,
      windowDays: 5,
      tiers: {
        bronze: { target: 40, coinReward: 25 },
        silver: { target: 50, coinReward: 60 },
        gold:   { target: 60, coinReward: 120 },
      },
      active: true,
      sortHint: 110,
    },
    {
      templateId: "deep-sleep-3",
      title: "Deep sleep × 3",
      blurb: "Stack sleep hours across 3 nights.",
      category: "health" as const,
      shape: "cumulative" as const,
      metric: "sleepHours" as const,
      windowDays: 3,
      tiers: {
        bronze: { target: 18, coinReward: 25 },
        silver: { target: 21, coinReward: 60 },
        gold:   { target: 24, coinReward: 120 },
      },
      active: true,
      sortHint: 120,
    },
  ];

  for (const t of templates) {
    const existing = await ctx.db
      .query("challengeTemplates")
      .withIndex("by_templateId", (q) => q.eq("templateId", t.templateId))
      .first();
    if (existing) {
      const { templateId, ...rest } = t;
      await ctx.db.patch(existing._id, rest);
    } else {
      await ctx.db.insert("challengeTemplates", t);
    }
  }
});
