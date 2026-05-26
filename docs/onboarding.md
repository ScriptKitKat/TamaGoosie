# Onboarding System

## Overview

The onboarding is presented as a full-screen cover (`fullScreenCover`) from `ContentView`. It uses a step-based linear flow managed by `OnboardingContainerView`, which routes between 13 possible step views (0-12). Steps are animated with a slide-from-trailing/slide-to-leading spring transition.

## Entry Paths

There are three entry paths, determined by the app's current state:

| Entry Path | Trigger | Starting Step |
|---|---|---|
| `freshInstall` | `UserProfile.hasCompletedOnboarding` is false | 0 (Welcome) |
| `loggedOutReturn` | Onboarding complete but `AuthService.shared.isSignedIn` is false | 0 (ReturnWelcome) |
| `returningAccount` | User taps "Already have an account?" on the Welcome screen | 7 (SignIn) |

The entry path is set in `ContentView.onAppear` and passed to `OnboardingContainerView`.

## Step Map

| Step | View | Purpose |
|---|---|---|
| 0 | `OnboardingWelcomeView` / `OnboardingReturnWelcomeView` | Landing screen. Fresh installs see the welcome; logged-out returns see a shorter variant. |
| 1 | `OnboardingHatchView` | User taps an egg to hatch their goose. Egg wobbles, cracks, then reveals the goose character. Auto-advances after 2.55s. |
| 2 | `OnboardingNameView` | Text field to name the goose. Default is "Harold". Goose wiggles on each keystroke. |
| 3 | `OnboardingTutorialView` (sad mood) | "If you treat yourself badly, your goose will reflect that" |
| 4 | `OnboardingTutorialView` (happy mood) | "Take care of yourself, and your goose will thrive" |
| 5 | `OnboardingTutorialView` (happy mood) | "Every action adds up -- watch your goose grow" |
| 6 | `OnboardingTutorialView` (happy mood) | "Every goal is tracked. Build habits, see progress." + checkmark list |
| 7 | `OnboardingSignInView` | Sign in with Apple, Google, or Email. After successful sign-in, checks Convex for returning user data. |
| 8 | `OnboardingCreateAccountView` | Email sign-up form (email, password, confirm password, terms checkbox). Only shown if user chose email. |
| 9 | `OnboardingUsernameView` | Pick a username (@username). Validates availability via Convex. Calls `AccountCreationViewModel.createAccount()`. Skipped for returning users. |
| 10 | `OnboardingNotificationsView` | Request notification permission. Shows a fake notification preview card. Has "Maybe Later" skip option. Skipped if already authorized. |
| 11 | `OnboardingHealthView` | Request HealthKit permission. Lists what health data is used (steps, sleep, exercise, stand hours). Has "Maybe Later" skip option. Skipped if already authorized. |
| 12 | `OnboardingCompleteView` | Final screen. Creates SwiftData entities (or restores them for returning users). Dancing goose animation. |

## Visible Steps Logic

Not all 13 steps are shown every time. `OnboardingContainerView.visibleSteps` computes which steps to display based on:

### Fresh Install
`[0, 1, 2, 3, 4, 5, 6, 7]` + conditionally:
- Step 8 if user chose email sign-up
- Step 9 if NOT a returning user (returning users already have a username)
- Step 10 if notifications not already authorized
- Step 11 if HealthKit not already authorized
- Step 12 always

### Returning Account (tapped "Already have an account?")
`[7]` + conditionally:
- Step 8 if chose email sign-up AND not returning user
- Step 9 if NOT a returning user
- Step 10/11 if not already authorized
- Step 12 always

### Logged-Out Return
`[0, 7]` + same conditional steps as returning account

## Navigation

- `advance()` moves to the next step in the `visibleSteps` array (not just `step + 1`)
- There is no back navigation
- The Welcome screen has a secondary "Already have an account?" link that jumps to step 7 and switches the entry path to `.returningAccount`

## Page Dots

Section-scoped dots appear at the bottom of the screen for:
- **Tutorial section** (steps 3-6): 4 dots, teal active / border inactive
- **Permissions section** (steps 10-11): dots only if both permission screens are visible

Dots use an expanding capsule style (active dot is wider).

## Theme

All onboarding views use `OBTheme`, a shared color palette:
- `cream` (#FFF8F0) -- background
- `card` (#F5EFE6) -- card/input backgrounds
- `border` (#E8E0D4) -- borders and inactive elements
- `text` (#4A3728) -- primary text
- `secondary` (#A09080) -- secondary/muted text
- `teal` (#7ECBC4) -- primary accent / CTA buttons
- `coral` (#F4A683) -- error states
- `yellow` (#FFD97A) -- decorative accent

## Shared UI Components

Defined in `OnboardingContainerView.swift`:
- `OBButton` -- full-width rounded CTA button. Teal when enabled, border color when disabled.
- `OBSpeechBubble` -- speech bubble with downward-pointing tail, used above the goose on several screens.
- `PageDots` -- animated page indicator dots.

## Sign-In Flow

`OnboardingSignInView` offers three sign-in methods:
1. **Apple** -- uses `SignInWithAppleButton` / `AuthenticationServices`
2. **Google** -- uses `GoogleSignIn` SDK
3. **Email** -- navigates to `OnboardingCreateAccountView` (step 8)

After successful sign-in, `handleSignInSuccess()`:
1. Shows a "Checking account..." spinner
2. Calls `ConvexManager.shared.checkReturningUser()`
3. If returning user found: populates `obState` with restored data (goose name, stats, mood, goals, daily logs, username) and sets `isReturningUser = true`
4. Advances to next step

## Entity Creation (OnboardingCompleteView)

### New User (`createEntities`)
1. Creates `UserProfile` with `hasCompletedOnboarding: true`
2. Creates `GooseState` with name from input, healthiness/happiness at 1.0, mood happy
3. Links goose to profile
4. Sets `UserDefaults["hasCompletedOnboarding"] = true`
5. Saves model context
6. Schedules morning notification reminder

### Returning User (`restoreEntities`)
1. Creates `UserProfile` from restored data
2. Creates `GooseState` with restored stats (healthiness, happiness, mood, streak, sprite)
3. Restores all `Goal` entities from Convex data
4. Restores all `DailyLog` entities from Convex data
5. Same completion steps as new user

For `loggedOutReturn` entry path, the complete screen auto-dismisses after 1.5s.

## Permission Pre-Checks

On container appear, `checkDevicePermissions()` checks:
- **HealthKit**: If `stepCount` sharing is already authorized, skips the health permission screen
- **Notifications**: If notification authorization is already granted, skips the notification screen

## Files

All onboarding files live in `TamaGoosie/Features/Onboarding/`:

| File | Content |
|---|---|
| `OnboardingState.swift` | `@Observable` state object shared across all steps |
| `OnboardingContainerView.swift` | Container, step routing, `OBTheme`, `OBButton`, `OBSpeechBubble`, `PageDots` |
| `OnboardingWelcomeView.swift` | Fresh install welcome screen |
| `OnboardingReturnWelcomeView.swift` | Logged-out return welcome screen |
| `OnboardingHatchView.swift` | Egg hatching interaction |
| `OnboardingNameView.swift` | Goose naming screen |
| `OnboardingTutorialView.swift` | Reusable tutorial screen (used for steps 3-6) |
| `OnboardingSignInView.swift` | Apple/Google/Email sign-in |
| `OnboardingCreateAccountView.swift` | Email account creation form |
| `OnboardingUsernameView.swift` | Username picker with availability check |
| `OnboardingNotificationsView.swift` | Notification permission request |
| `OnboardingHealthView.swift` | HealthKit permission request |
| `OnboardingCompleteView.swift` | Final screen, entity creation/restoration |
