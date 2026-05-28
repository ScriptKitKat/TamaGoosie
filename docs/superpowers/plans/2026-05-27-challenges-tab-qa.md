# Challenges Tab — Manual QA Checklist

Run before merging to main. Expected effort: ~20 min.

## Setup
- Fresh simulator install OR delete the app from a test device first.
- Confirm Convex seed: 11 active templates already loaded (run if missing):
  `npx --prefix convex convex run seedChallenges:seed`

## Golden path
- [ ] Open Challenges tab — Browse section populated, Active section hidden.
- [ ] Tap a browse card → detail sheet opens with Silver pre-selected.
- [ ] Switch tier to Gold — target + reward update in real time.
- [ ] Tap Start → card moves to Active, sheet dismisses, coin pill unchanged.
- [ ] Accept two more → "Active (3/3)" header visible.
- [ ] Tap a fourth browse card → toast "Finish one to start another"; no sheet.

## Completion
- [ ] Manually inject HealthKit step data (or use a debug menu) to push an active challenge over target.
- [ ] Foreground the app → completion sheet appears, coin pill increments by the snapshotted reward.
- [ ] Dismiss → if other completions queued, next sheet appears.

## Expiry + cooldown
- [ ] Accept a 2-day challenge; advance simulator clock past `expiresAt`.
- [ ] Re-open app → run moves out of Active; appears as cooldown badge in Browse.
- [ ] Try to start → tap disabled; "Available in Nd" shown.

## Offline
- [ ] Turn off Wi-Fi.
- [ ] Accept a challenge → succeeds locally, no error UI.
- [ ] Kill app → reopen → run still present.
- [ ] Turn Wi-Fi back on → pull-to-refresh → no duplicates appear.

## Schema-mismatch resilience
- [ ] In Convex dashboard, insert a `challengeTemplates` row with an invalid `metric` value.
- [ ] Re-open Challenges → tab loads; bad row is silently skipped.

## Time-zone
- [ ] Change simulator system time zone (Settings → General → Date & Time).
- [ ] Re-open app → no crash; daysLeft countdown updates plausibly.

## Hit-testing (regression check)
- [ ] Background of Challenges tab does NOT swallow taps. Buttons on cards respond.
- [ ] Pull-to-refresh works on the ScrollView.

## Sign-off
- Tested by: ____
- Date: ____
- Build: ____
