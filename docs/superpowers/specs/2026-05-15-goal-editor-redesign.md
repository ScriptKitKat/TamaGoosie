# Goal Editor Redesign — Guided 2-Step Flow

## Overview

Replace the form-heavy GoalEditorView with a guided 2-step creation flow and a single-page edit view. The goal is to make creating a goal feel like "tell me what you want to do" rather than "fill out this settings form."

## Flows

### Creating a New Goal (2 steps)

**Step 1 — "What do you want to do?"**
- Large title text field as the hero element
- Quick suggestion chips below: `Drink water`, `Exercise`, `Study`, `Sleep earlier`, `Read`, `Less screen time`
- Tapping a suggestion fills in the title and auto-selects the category
- "Continue" CTA at bottom (disabled until title non-empty)
- Typing triggers auto-category suggestion (shown below the text field as a small pill)

**Step 2 — "Customize"**
- Title displayed at top (tappable to go back to Step 1)
- Auto-suggested category pill with "Change" button (opens GoalCategorySheet)
- Goal style: `Build a habit` | `Reach a deadline` segmented picker, defaults to habit
- Repeat row (habit only): shows current frequency as a tappable row ("Every day >"), opens GoalFrequencySheet
- When custom frequency selected, inline weekday picker appears
- Context-aware daily target stepper with smart unit label
- Due date picker (deadline only)
- Reminder toggle with time picker
- "Advanced" disclosure group containing importance slider
- Preview card showing the goal as it will appear
- Big green "Create Goal" CTA at bottom
- Microcopy: "You can always edit this later."

### Editing an Existing Goal (single page)

- All fields visible and pre-filled on one page — no steps
- Same field layout as Step 2 but titled "Edit Goal"
- "Save" CTA at bottom
- Built-in goals still show the limited threshold editor (unchanged from current)

## Smart Category Suggestion

Function `suggestCategory(from title: String) -> GoalCategory` maps title keywords:

| Keywords | Category |
|----------|----------|
| water, drink, glass, hydra | .water |
| exercise, run, walk, gym, workout, jog | .exercise |
| study, homework, learn, class | .study |
| screen, phone, social media, app, tiktok, instagram | .screentime |
| sleep, bed, rest, wake | .health |
| read, book, chapter, page | .learning |
| meditate, breathe, journal, mindful, yoga | .mindfulness |
| friend, call, family, social | .social |
| focus, productive, deep work, task | .productivity |
| stretch, lift, weight, pushup, plank | .fitness |
| fallback | .custom |

## Context-Aware Target Labels

Function `targetUnit(for category: GoalCategory) -> (label: String, defaultValue: Int, range: ClosedRange<Int>, step: Int)`:

| Category | Unit Label | Default | Range | Step |
|----------|-----------|---------|-------|------|
| .water | glasses | 8 | 1...20 | 1 |
| .exercise | minutes | 30 | 5...180 | 5 |
| .fitness | minutes | 30 | 5...180 | 5 |
| .screentime | minutes | 120 | 15...480 | 15 |
| .study | minutes | 60 | 10...300 | 10 |
| .health | hours | 8 | 4...12 | 1 |
| .learning | minutes | 30 | 10...180 | 10 |
| .mindfulness | minutes | 15 | 5...60 | 5 |
| .productivity | tasks | 3 | 1...20 | 1 |
| .social | times | 1 | 1...10 | 1 |
| .custom | times | 1 | 1...99 | 1 |

## Quick Suggestions

Six chips shown on Step 1:

| Label | Pre-filled Title | Category | Target |
|-------|-----------------|----------|--------|
| Drink water | Drink water | .water | 8 glasses |
| Exercise | Exercise | .exercise | 30 min |
| Study | Study | .study | 60 min |
| Sleep earlier | Sleep earlier | .health | 8 hrs |
| Read | Read | .learning | 30 min |
| Less screen time | Less screen time | .screentime | 120 min |

## File Structure

| File | Role | ~Lines |
|------|------|--------|
| `GoalEditorView.swift` | Router: decides between create flow, edit form, or builtin editor. Owns save/validation logic. | ~200 |
| `GoalCreateFlowView.swift` | 2-step create: Step1 (title + suggestions) and Step2 (customize fields + preview + CTA) | ~350 |
| `GoalEditFormView.swift` | Single-page edit with all fields pre-filled, "Save" CTA at bottom | ~250 |
| `GoalCategorySheet.swift` | Bottom sheet with the full category grid picker | ~80 |
| `GoalFrequencySheet.swift` | Bottom sheet with frequency options + custom day picker | ~120 |

## Styling

- Pokemon GO inspired: bright greens, bold rounded typography, white cards
- Green accent: `0x43A047` for CTAs, selected states, category suggestion pill
- Cards: white with subtle shadow, 14pt corner radius
- Step 1: clean and spacious — large text field, suggestion chips as capsules
- Step 2: compact rows, each setting on its own line
- CTA: full-width green capsule button at bottom, 50pt height
- Preview card: light green tinted background, shows icon + title + frequency + target

## What Stays the Same

- GoalDraft struct in GoalViewModel (used for AI prefill)
- All save logic (create/update Goal, sync to Convex, schedule notifications)
- Built-in goal threshold editor (builtinThresholdEditor)
- GoalEditorView is still presented as a `.sheet` from GoalListView
- The `existingGoal` and `prefill` parameters on GoalEditorView
