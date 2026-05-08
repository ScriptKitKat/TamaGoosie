# Onboarding Redesign Spec

## Overview

Redesign the onboarding flow into 3 distinct entry paths based on user state. Move sign-in after the tutorial, add tutorial screens, move goal picker to Goals tab first-visit, and support logged-out return users.

## Entry Path Detection

| Condition | Path |
|-----------|------|
| `hasCompletedOnboarding == false` (or missing) | **Path A/B** — Fresh install |
| `hasCompletedOnboarding == true` AND no active auth session | **Path C** — Logged-out return |
| `hasCompletedOnboarding == true` AND active auth session | Skip onboarding, go to home |

Detection lives in `ContentView` using `UserDefaults("hasCompletedOnboarding")` + `AuthService.shared.isSignedIn`.

## Path A — Fresh Install (New User)

| Step | Screen | Details |
|------|--------|---------|
| 0 | **Welcome** | Goose character centered, title "Become a better version of yourself", "Get Started" primary button, "Already have an account?" secondary text button |
| 1 | **Hatch** | "Welcome to TamaGoosie! Let's hatch your goose!" — existing egg tap-to-crack animation, goose emerges |
| 2 | **Name** | "What's your goose's name?" — pre-filled "Harold", goose wiggles on keystroke (existing behavior) |
| 3 | **Tutorial 1** | Sad goose mood, "If you treat yourself badly, your goose will reflect that", button "I'll treat myself well" |
| 4 | **Tutorial 2** | Happy goose mood, "Take care of yourself, and your goose will thrive", button "I will!" |
| 5 | **Tutorial 3** | Ecstatic goose mood, "Every action adds up — watch your goose grow", button "Let's grow!" |
| 6 | **Tutorial 4** | Teal checkmark list (Track your health, Build daily habits, Watch your goose thrive), title "Every goal is tracked. Build habits, see progress.", button "Let's go!" |
| 7 | **Sign In** | "Create an account to track your goose", app icon/goose above, buttons: Continue with Apple, Continue with Google, Continue with Email |
| 8 | **Create Account** | Email form — only shown if user chose Email in step 7. Apple/Google skip to step 9. Fields: email, password, confirm password, terms checkbox, Continue button |
| 9 | **Username** | Existing username input with real-time availability check |
| 10 | **Notifications** | "Keep track of your goals", notification preview mockup, "Remind Me" primary button, "Maybe Later" text button |
| 11 | **Health** | Goose speech bubble: "I need to know how you're doing so I can stay healthy too!", "Connect Health Data" primary button, "Skip for now" text button |
| 12 | **Complete** | Dancing ecstatic goose, "You're all set! [GooseName] is ready to go!", "Let's go!" button → dismiss to home |

New user default stats: `healthiness = 1.0`, `happiness = 1.0` (displayed as 100%).

## Path B — "Already Have an Account?" (Fresh Install, Returning User)

Triggered from Welcome screen (step 0) "Already have an account?" button.

1. Jump to step 7 (Sign In)
2. After sign-in, `ConvexManager.shared.checkReturningUser()` runs
3. If returning user detected: skip to Notifications (if not already authorized) -> Health (if not already authorized) -> Complete (stats restored from Convex)
4. If NOT returning (new account via this path): continue with steps 8-12 as Path A

## Path C — Logged-Out Return User

Shown when `hasCompletedOnboarding == true` but user has no active auth session.

| Step | Screen | Details |
|------|--------|---------|
| 0 | **Return Welcome** | Goose character, "Take care of yourself, take care of your Goose", "Start Now" primary button |
| 1 | **Sign In** | Same as Path A step 7 — Apple/Google/Email buttons |
| 2a | **If account exists in Convex** | Restore data → dismiss to home immediately |
| 2b | **If new account** | Continue with Path A steps 8-12 (Create Account if email → Username → Notifications → Health → Complete) |

## First-Time Goals Tab

Separate from onboarding. Triggered when user taps the Goals tab for the first time.

- New field: `UserProfile.hasPickedInitialGoals: Bool` (default `false`)
- When Goals tab appears and `hasPickedInitialGoals == false`, show a modal sheet with the existing goal picker grid
- After selection + continue, set `hasPickedInitialGoals = true`, seed built-in goals + selected goals
- If dismissed without picking, show again next time

## New Files

| File | Purpose |
|------|---------|
| `OnboardingWelcomeView.swift` | Step 0 welcome screen (Path A) |
| `OnboardingReturnWelcomeView.swift` | Step 0 for Path C (logged-out return) |
| `OnboardingTutorialView.swift` | Reusable tutorial page (steps 3-6), parameterized by mood, title, buttonTitle, optional checkmarks |
| `OnboardingCreateAccountView.swift` | Email account creation form (step 8) |
| `InitialGoalPickerSheet.swift` | First-time Goals tab modal (moved from onboarding) |

## Modified Files

| File | Changes |
|------|---------|
| `OnboardingContainerView.swift` | New step numbering (0-12), 3 entry path routing, Path C support |
| `OnboardingState.swift` | Add `entryPath` enum (freshInstall, returningAccount, loggedOutReturn), remove `selectedGoals` |
| `OnboardingSignInView.swift` | Add Email option button, update copy to "Create an account to track your goose" |
| `OnboardingNotificationsView.swift` | Update copy: "Keep track of your goals", add "Maybe Later" secondary button |
| `OnboardingHealthView.swift` | Update copy: goose speech bubble style, "Connect Health Data" / "Skip for now" |
| `OnboardingCompleteView.swift` | Set default stats to 1.0 for new users |
| `ContentView.swift` | Detect Path C (hasCompletedOnboarding + no auth session) |
| `GoalListView.swift` | Show `InitialGoalPickerSheet` on first visit |
| `UserProfile.swift` | Add `hasPickedInitialGoals` field |
| `OnboardingGoalsView.swift` | Delete (moved to InitialGoalPickerSheet) |

## Visual Direction

- Keep existing cream/beige `OBTheme` palette
- Progress dots at bottom, hidden on welcome/sign-in screens
- Tutorial screens show `GooseCharacterView` at specified moods (sad, happy, ecstatic)
- Tutorial 4 uses teal checkmark icons in a vertical list
- Buttons use existing `OBButton` style; secondary actions use plain text buttons
- Transitions use existing spring-based slide animations

## Progress Dots

Dots are scoped per section, not global across all steps:

| Section | Steps | Dots |
|---------|-------|------|
| Welcome + Hatch + Name | 0-2 | No dots |
| Tutorial | 3-6 | 4 dots |
| Sign In + Account + Username | 7-9 | No dots |
| Permissions (Notifications + Health) | 10-11 | 2 dots |
| Complete | 12 | No dots |

- Path B: no dots (short flow)
- Path C: no dots (short flow)
