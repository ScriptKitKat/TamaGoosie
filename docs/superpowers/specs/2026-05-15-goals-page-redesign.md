# Goals Page Redesign — Tabbed Layout

## Overview

Refactor the Goals page from a two-section list (Daily Health Goals / My Goals) into a three-tab layout: **Today**, **Habits**, and **Quests**. Each tab serves a distinct purpose while sharing the existing green theme and card styling.

## Tab Definitions

### Today Tab
- **Content**: All active goals for the current day — builtin, recurring, and deadline
- **Header**: Date line ("Thu, May 15"), progress bar with "X / Y" completed count
- **Cards**: Icon + title + subtitle (frequency) + streak flame on the right + completion indicator (check circle for single-count, progress ring for multi-count, progress bar for auto-tracked)
- Auto-tracked (HealthKit) goals show live progress bars with value labels

### Habits Tab
- **Content**: Recurring and builtin goals only
- **Header**: Subtitle "X active, longest streak Y days", stats row with 2 cards (longest streak, this week %)
- **Cards**: Icon + title + frequency label + streak flame + **weekly heat map** (M T W T F S S)
- Heat map: 7 cells for the current week, green shades for completed days, light/empty for incomplete or future
- "+ New habit" button with dashed border at bottom

### Quests Tab
- **Content**: Deadline goals only
- **Cards**: Icon + title + due date + percentage ring + progress bar (reuses existing DeadlineGoalCardView styling)
- "+ New quest" button with dashed border at bottom

## Tab Picker

Segmented pill-style picker matching the reference: selected tab has a green filled capsule with white text, unselected tabs are plain text. Sits below the summary header, above the goal list.

## Data Model Change

Add `completionDates: [Date]` to the `Goal` model.

- On goal completion: append today's date (if not already present)
- On goal uncomplete: remove today's date
- Auto-completed HealthKit goals: append date when auto-complete fires
- Heat map reads the last 7 calendar days from this array
- Keep the array pruned to the last 90 days to avoid unbounded growth

No migration needed — SwiftData handles new optional/defaulted properties automatically with a default of `[]`.

## File Structure

| File | Role | ~Lines |
|------|------|--------|
| `GoalListView.swift` | Container: @Query, tab state, shared logic (seed, ensureTodayLog, auto-complete, confetti, sheets, onChange) | ~250 |
| `TodayGoalsTab.swift` | Today tab: date header, progress summary, flat goal list | ~200 |
| `HabitsGoalsTab.swift` | Habits tab: stats row, habit cards with heat maps, "+ New habit" | ~200 |
| `QuestsGoalsTab.swift` | Quests tab: deadline cards, "+ New quest" | ~100 |
| `WeeklyHeatMap.swift` | Reusable 7-cell heat map component | ~60 |
| `GoalTabPicker.swift` | Today/Habits/Quests segmented pill picker | ~50 |

Existing card views (`GoalCardView`, `DeadlineGoalCardView`, `HealthKitGoalCardView`, `ConfettiView`) remain in `GoalListView.swift` or get extracted as-is. They receive minor layout tweaks (streak flame moves to trailing side) but keep their core logic.

## Styling (Pokemon GO inspired)

- Background: `GrassyBackgroundView()` (unchanged)
- Cards: white with rounded corners, subtle shadow (unchanged) — Pokemon GO's clean card aesthetic
- Category colors: existing `goal.colorHex` system (unchanged)
- Tab picker: green capsule (`0x43A047`) for selected, charcoal text for unselected — matches Pokemon GO's pill-style segmented controls
- Heat map cells: `0x43A047` full opacity for completed, `0xC5E1A5` for partial, `0xE8F5E9` for empty, `0xEEEEEE` for future days
- Stats cards: white background with bold green accent numbers — Pokemon GO stat badge style
- Section headers: green gradient banners (already used in Stats/Settings pages) — evokes Pokemon GO's colored section dividers
- Overall feel: bright, friendly, gamified — bold rounded typography, generous spacing, clear visual hierarchy like Pokemon GO's activity screens

## What Stays the Same

- All completion/uncomplete/increment logic in GoalViewModel
- GooseEngine integration (auto-complete, stat recomputation)
- Confetti system
- Sheet-based GoalEditorView
- InitialGoalPickerSheet
- All onChange handlers for HealthKit sync
