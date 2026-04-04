# Implementation Plan: watchOS Screens Setup

## Current State Assessment

The **Shared/ framework** and most Watch infrastructure are already in place — no framework target needed (Shared/ is directly compiled into each target via `project.yml`). Here is what actually exists vs. what's missing:

| Component | Status | Notes |
|-----------|--------|-------|
| `Shared/Constants.swift` | ✅ Complete | GoosieConstants, all weights/rates |
| `Shared/GoosePhase.swift` | ✅ Complete | GoosePhase, GooseMood, GoalCategory, GoalFrequency |
| `Shared/GooseStats.swift` | ✅ Complete | GooseSyncPayload (2-stat, 0.0–1.0) |
| `Shared/SyncPayload.swift` | ✅ Complete | GoalSummary |
| `project.yml` | ✅ Complete | Shared/ linked to TamaGoosie + TamaGoosieWatch |
| `WatchApp.swift` | ✅ Complete | @main TamaGoosieWatchApp |
| `GooseGlanceView.swift` | ✅ Complete | Health ring + mood + stat bars + streak |
| `QuickLogView.swift` | ⚠️ Partial | Shows `.prefix(3)` — needs 5; no progress bar |
| `WatchSyncReceiver.swift` | ✅ Complete | WCSession + goal completion send |
| `GooseComplication.swift` | 🔴 Broken | Has `@main` conflicting with WatchApp.swift |
| `WatchStatsView.swift` | ❌ Missing | Third screen: steps / exercise / sleep read-only |

## Task Type
- [x] Frontend (SwiftUI Watch screens)
- [x] Backend (minimal — @main fix only)
- [x] Fullstack

---

## Design Language

All Watch views use this visual identity (soft pastel, children's storybook aesthetic):

| Token | Value | Usage |
|-------|-------|-------|
| Background | `#FFF8F0` (warm cream) | All view backgrounds — NOT system black |
| Primary accent | `#7ECBC4` (soft teal) | Health ring, active progress, primary actions |
| Secondary accent | `#F4A683` (warm coral) | Exercise, energy, warning states |
| Tertiary accent | `#FFD97A` (gentle yellow) | Streak, XP, happiness |
| Text | `.design(.rounded)` on all fonts | Every Text modifier |
| Corners | Generous radius everywhere | `Capsule()` for bars, `RoundedRectangle(cornerRadius: 16+)` |
| Icons | SF Symbols tinted in pastel palette | No system blue |
| Character | SwiftUI-drawn duck: circle body + small orange beak + dot eyes | No image assets |

**Overall feel**: cute, soft, bubbly — never sharp, never system-default dark.

---

## Technical Solution

### Problem 1: @main Conflict (simplified fix)
`TamaGoosieWatch/Complications/GooseComplication.swift` declares `@main struct GooseComplicationWidget: Widget`, conflicting with `WatchApp.swift`.

**Fix (hackathon-appropriate)**: Simply remove `@main` from `GooseComplication.swift`. No new target, no `project.yml` changes. The Widget struct exists as a named type and can be wired up to a proper extension when submitting to the App Store. Complications in the Watch Simulator are hard to test anyway — focus on the three main screens.

### Problem 2: Missing WatchStatsView
Create `TamaGoosieWatch/WatchStatsView.swift` with a `WatchHealthSnapshot` mock struct. Use `ScrollView + VStack` instead of `List` — fewer rows, no swipe-to-delete needed, and avoids `GeometryReader`-in-List sluggishness on older Watch hardware.

### Problem 3: QuickLogView shows 3 goals
Change `.prefix(3)` → `.prefix(5)` and add pastel progress bar under each row.

### Mock Data
`WatchSyncReceiver.shared.currentPayload` initializes to `GooseSyncPayload()` (healthiness: 0.8, happiness: 0.7). `WatchStatsView` carries its own `WatchHealthSnapshot` mock struct for now.

---

## Implementation Steps

### Step 1: Fix GooseComplication @main conflict

**File**: `TamaGoosieWatch/Complications/GooseComplication.swift`

Remove `@main`. Rename `GooseComplicationWidget` → `GooseComplicationWidgetConfiguration`. No other changes. No new target.

```swift
// Before: @main struct GooseComplicationWidget: Widget
// After:
struct GooseComplicationWidgetConfiguration: Widget {
    let kind = "GooseComplication"
    // ... rest unchanged
}
```

### Step 2: Create WatchStatsView

**New file**: `TamaGoosieWatch/WatchStatsView.swift`

Design: cream background, pastel-tinted SF Symbol icons, `ScrollView + VStack` (not List), 4px capsule progress bars.

```swift
import SwiftUI

struct WatchHealthSnapshot {
    var steps: Int = 7_432
    var exerciseMinutes: Int = 28
    var sleepHours: Double = 7.2
    var standHours: Int = 9
}

struct WatchStatsView: View {
    let snapshot: WatchHealthSnapshot

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                statCard(
                    icon: "figure.walk", label: "Steps",
                    value: snapshot.steps.formatted(),
                    color: Color(hex: "7ECBC4"),
                    fraction: Double(snapshot.steps) / 10_000
                )
                statCard(
                    icon: "figure.run", label: "Exercise",
                    value: "\(snapshot.exerciseMinutes) min",
                    color: Color(hex: "F4A683"),
                    fraction: Double(snapshot.exerciseMinutes) / 30
                )
                statCard(
                    icon: "moon.zzz.fill", label: "Sleep",
                    value: String(format: "%.1f hr", snapshot.sleepHours),
                    color: Color(hex: "B4A8E8"),  // soft lavender
                    fraction: snapshot.sleepHours / 9.0
                )
                statCard(
                    icon: "figure.stand", label: "Stand",
                    value: "\(snapshot.standHours) hr",
                    color: Color(hex: "FFD97A"),
                    fraction: Double(snapshot.standHours) / 12
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(Color(hex: "FFF8F0"))
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statCard(icon: String, label: String, value: String, color: Color, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
            }
            Capsule()
                .fill(color.opacity(0.2))
                .frame(height: 5)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(color)
                            .frame(width: max(0, geo.size.width * min(1, fraction)))
                    }
                }
        }
        .padding(10)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// Hex color helper (shared inline since Watch target can't import iOS-only modules)
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

#Preview {
    NavigationStack {
        WatchStatsView(snapshot: WatchHealthSnapshot())
    }
}
```

**Note**: The `Color(hex:)` extension may already exist in the iOS target (check `GoosieTheme.swift`). If so, add it only to the Watch target context or put it in `Shared/` so it compiles into all targets without duplication.

### Step 3: Update GooseGlanceView — Stats navigation + pastel theme

**File**: `TamaGoosieWatch/GooseGlanceView.swift`

Changes:
1. Add `@State private var showStats = false`
2. Apply `Color(hex: "FFF8F0")` background
3. Color the health ring teal (`Color(hex: "7ECBC4")`) and happiness bar coral (`Color(hex: "F4A683")`)
4. Add Stats sheet trigger alongside existing Goals button

```swift
// Add state
@State private var showStats = false

// Background on outermost VStack
.background(Color(hex: "FFF8F0"))

// Health ring color
.stroke(Color(hex: "7ECBC4"), style: StrokeStyle(lineWidth: 6, lineCap: .round))

// In toolbar, replace single ToolbarItem with:
ToolbarItem(placement: .bottomBar) {
    HStack {
        Button { showStats = true } label: {
            Image(systemName: "chart.bar.fill")
                .foregroundStyle(Color(hex: "7ECBC4"))
        }
        Spacer()
        Button { showQuickLog = true } label: {
            Image(systemName: "checklist")
                .foregroundStyle(Color(hex: "7ECBC4"))
        }
    }
}

// Add alongside existing sheet
.sheet(isPresented: $showStats) {
    WatchStatsView(snapshot: WatchHealthSnapshot())
}
```

Update `watchStatBar` to use teal for health and coral for happiness (remove the color parameter, pass directly):
```swift
watchStatBar("Health", value: payload.healthiness, color: Color(hex: "7ECBC4"))
watchStatBar("Happy",  value: payload.happiness,   color: Color(hex: "F4A683"))
```

Update `healthColor` computed property to use pastel palette:
```swift
private var healthColor: Color {
    if payload.healthiness > 0.6 { return Color(hex: "7ECBC4") }  // teal
    if payload.healthiness > 0.3 { return Color(hex: "FFD97A") }  // yellow
    return Color(hex: "F4A683")                                     // coral
}
```

### Step 4: Update QuickLogView — 5 goals + progress bars + pastel

**File**: `TamaGoosieWatch/QuickLogView.swift`

1. Change `.prefix(3)` → `.prefix(5)`
2. Add 4px capsule progress bar under each goal title row
3. Apply cream background and rounded fonts

```swift
List {
    ForEach(syncService.activeGoals.prefix(5)) { goal in
        Button { completeGoal(goal) } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(goal.title)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .lineLimit(2)
                        Text("\(Int(goal.progress * 100))%")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: goal.progress >= 1.0 ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(goal.progress >= 1.0 ? Color(hex: "7ECBC4") : Color.gray.opacity(0.4))
                        .font(.system(size: 18))
                }
                // Progress bar
                Capsule()
                    .fill(Color(hex: "7ECBC4").opacity(0.2))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(goal.progress >= 1.0 ? Color(hex: "7ECBC4") : Color(hex: "F4A683"))
                                .frame(width: max(0, geo.size.width * min(1, goal.progress)))
                        }
                    }
            }
            .padding(.vertical, 2)
        }
        .disabled(goal.progress >= 1.0)
    }
}
.navigationTitle("Goals")
```

### Step 5: Regenerate and build (run once at the end)

```bash
xcodegen generate

xcodebuild -project TamaGoosie.xcodeproj \
  -scheme TamaGoosieWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  build
```

---

## Key Files

| File | Operation | Description |
|------|-----------|-------------|
| `TamaGoosieWatch/Complications/GooseComplication.swift` | Modify | Remove `@main`, rename struct |
| `TamaGoosieWatch/WatchStatsView.swift` | **Create** | Steps/exercise/sleep/stand cards; ScrollView+VStack; pastel theme |
| `TamaGoosieWatch/GooseGlanceView.swift` | Modify | Add Stats sheet, cream bg, pastel ring/bar colors |
| `TamaGoosieWatch/QuickLogView.swift` | Modify | prefix(5), progress bars, pastel colors |

No `project.yml` changes needed.

---

## Risks and Mitigation

| Risk | Mitigation |
|------|------------|
| `Color(hex:)` extension duplicated across targets | Check `GoosieTheme.swift`; if already defined in iOS target, add to `Shared/` as `public extension Color` to compile into all targets |
| `GeometryReader` inside overlay vs inside row | Overlay approach avoids layout ambiguity in ScrollView better than row-level GeometryReader |
| Watch Simulator cream bg looks washed out at low brightness | Test at default brightness; use `Color.white.opacity(0.6)` on cards for subtle layering |
| `WCSession.isSupported()` false in Simulator | Already guarded in `WatchSyncReceiver` — defaults serve as mock data |

---

## Execution Order

1. GooseComplication.swift — remove @main (prevents build failure)
2. WatchStatsView.swift — create new file
3. GooseGlanceView.swift — add Stats navigation + pastel theme
4. QuickLogView.swift — prefix(5) + progress bars
5. `xcodegen generate` + build verify (once, at end)

---

## SESSION_ID (for /ccg:execute use)
- CODEX_SESSION: N/A (codeagent-wrapper not available)
- GEMINI_SESSION: N/A (codeagent-wrapper not available)
