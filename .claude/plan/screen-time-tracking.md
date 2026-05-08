# Plan: Screen Time Distraction Tracking System

## Context

The current distraction tracking is entirely manual — users type app names (fake bundle IDs)
and the overlay timer only runs while the user is inside the app. Apple's Screen Time API
(FamilyControls + DeviceActivity + ManagedSettings) enables **real automatic tracking** via
stacked threshold events, app shielding, and rendered usage reports.

### What already exists (from earlier in this session)

| File | Status | Notes |
|------|--------|-------|
| `TamaGoosieDeviceActivity/` | Partial | Basic monitor with single threshold — needs stacked events, notifications, shielding |
| `ScreenTimeManager.swift` | Partial | Single threshold — needs stacked thresholds, limit editor support |
| `DistractionConfigView.swift` | Partial | FamilyActivityPicker added — needs limit editor UI |
| `project.yml` | Partial | Has 1 extension target — needs 2 more (Shield, Report) |
| `ContentView.swift` | Partial | Has scenePhase processing — needs approxMinutes instead of flat count |

### What's missing

1. **Stacked threshold events** (15/30/45/60 min) instead of single 30-min event
2. **Shield extension** — blocks distraction apps with Harold-themed screen when limit hit
3. **Report extension** — renders actual screen time data as embedded SwiftUI view
4. **Limit editor UI** — user-configurable threshold slider in DistractionConfigView
5. **Notifications from extension** — Harold warns when thresholds are crossed
6. **App Group key alignment** — use `distractionApproxMinutes` / `distractionHitsToday` keys
7. **Delete `DistractionApp` model** — dead model after Screen Time replaces manual tracking (no users yet, no migration concern)

---

## Task Type

- [x] iOS (Swift, SwiftUI, XcodeGen)
- [x] Extension targets (DeviceActivity, ManagedSettings)

---

## Technical Solution

Use Apple's 3-framework Screen Time API:
- **FamilyControls** — authorization + `FamilyActivityPicker` for app selection
- **DeviceActivity** — background monitoring via stacked thresholds at 15/30/45/60 min
- **ManagedSettings** — shield (block) apps when user's configured limit is hit

Communication between extensions and main app is exclusively via **App Group UserDefaults**
(`group.com.tamagoosie`). The existing App Group ID is reused — no new group needed.

---

## Implementation Steps

### Step 1: Update Constants

**File:** `Shared/Constants.swift`

Replace the existing 3 screen time constants with:

```swift
// MARK: - Screen Time
public static let screenTimeSelectionKey = "screenTimeSelection"
public static let screenTimeThresholdEventsKey = "distractionHitsToday"
public static let screenTimeApproxMinutesKey = "distractionApproxMinutes"
public static let screenTimeLastHitKey = "lastDistractionHit"
public static let screenTimeLimitKey = "distractionLimitMinutes"
public static let screenTimeLastPenaltyMinutesKey = "lastPenaltyApproxMinutes"
public static let screenTimeDefaultLimitMinutes: Int = 30
public static let screenTimeThresholds: [Int] = [15, 30, 45, 60]
```

### Step 1.5: Delete DistractionApp Model

**Delete file:** `TamaGoosie/Core/Models/DistractionApp.swift`

No users yet → no SwiftData migration concern. Remove all references:
- Remove `DistractionApp` from any `@Query` or `FetchDescriptor` usage
- Remove `var distractionApps: [DistractionApp]?` relationship from `UserProfile` if present
- Remove any `import` or usage in `DistractionConfigView.swift` (replaced entirely by FamilyActivityPicker)
- Verify no other files reference the model (`grep -r DistractionApp`)

### Step 2: Rewrite ScreenTimeManager with Stacked Thresholds

**File:** `TamaGoosie/Core/Services/ScreenTimeManager.swift`

Key changes from current implementation:
- Replace single `DeviceActivityEvent` with 4 stacked events (15/30/45/60 min)
- Add `userLimitMinutes` property (saved to App Group, read by Monitor extension)
- Use `DeviceActivityName("daily-distraction")` instead of `.daily`
- Expose `approxMinutesToday` (read from App Group, written by Monitor extension)

```swift
// Stacked events registration
let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = Dictionary(
    uniqueKeysWithValues: GoosieConstants.screenTimeThresholds.map { mins in
        let name = DeviceActivityEvent.Name("distraction-\(mins)")
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: mins)
        )
        return (name, event)
    }
)

try activityCenter.startMonitoring(
    DeviceActivityName("daily-distraction"),
    during: schedule,
    events: events
)
```

Add limit management:
```swift
var userLimitMinutes: Int {
    get { defaults.integer(forKey: GoosieConstants.screenTimeLimitKey).nonZero
          ?? GoosieConstants.screenTimeDefaultLimitMinutes }
    set { defaults.set(newValue, forKey: GoosieConstants.screenTimeLimitKey) }
}

var approxMinutesToday: Int {
    defaults.integer(forKey: GoosieConstants.screenTimeApproxMinutesKey)
}
```

### Step 3: Rewrite DeviceActivityMonitor Extension

**File:** `TamaGoosieDeviceActivity/DeviceActivityMonitorExtension.swift`

Key changes:
- Parse event name to extract approximate minutes (`"distraction-30"` → 30)
- Store `distractionApproxMinutes` (highest threshold hit = best approximation)
- Increment `distractionHitsToday` counter
- Shield apps via `ManagedSettingsStore` when user limit is reached
- Send local notification (Harold voice)

Must add to extension dependencies in `project.yml`:
- `sdk: ManagedSettings.framework`
- `sdk: UserNotifications.framework`

```swift
import DeviceActivity
import ManagedSettings
import UserNotifications

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    let store = ManagedSettingsStore()
    let defaults = UserDefaults(suiteName: "group.com.tamagoosie")!

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        // Track hits
        let hits = defaults.integer(forKey: "distractionHitsToday") + 1
        defaults.set(hits, forKey: "distractionHitsToday")
        defaults.set(Date().timeIntervalSince1970, forKey: "lastDistractionHit")

        // Extract approximate minutes from event name
        let approxMinutes = Int(event.rawValue.replacingOccurrences(of: "distraction-", with: "")) ?? 0
        defaults.set(approxMinutes, forKey: "distractionApproxMinutes")

        // Shield apps when user's configured limit is reached
        let userLimit = defaults.integer(forKey: "distractionLimitMinutes")
        if userLimit > 0, approxMinutes >= userLimit,
           let data = defaults.data(forKey: "screenTimeSelection"),
           let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
            store.shield.applications = selection.applicationTokens
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }

        // Send Harold notification
        sendNotification(approxMinutes: approxMinutes)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        // Midnight reset
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        defaults.set(0, forKey: "distractionHitsToday")
        defaults.set(0, forKey: "distractionApproxMinutes")
        defaults.set(0, forKey: "lastPenaltyApproxMinutes")
    }

    private func sendNotification(approxMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Harold is worried"
        content.body = approxMinutes >= 60
            ? "You've been on distracting apps for over an hour... I'm getting sad"
            : "You've hit \(approxMinutes) minutes on distracting apps today"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "distraction-\(approxMinutes)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
```

### Step 4: Create Shield Configuration Extension

**New target:** `TamaGoosieShield`
**New directory:** `Extensions/Shield/`
**Extension point:** `com.apple.deviceactivity.shield-configuration`

This controls the UI shown when a shielded app is opened. Very limited API —
title, subtitle, icon, buttons, colors. No arbitrary SwiftUI.

**No bypass button.** The `secondaryButtonLabel` is optional in `ShieldConfiguration` —
omitting it means the user can ONLY tap "Back to Harold" with no way to bypass.
Stronger product statement for a hackathon demo. Can add bypass back later if
user testing shows people hate being fully blocked.

**Files:**
- `Extensions/Shield/ShieldConfigurationProvider.swift`
- `Extensions/Shield/Info.plist`
- `Extensions/Shield/TamaGoosieShield.entitlements`

```swift
import ManagedSettings
import UIKit

class ShieldConfigurationProvider: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor(red: 1.0, green: 0.97, blue: 0.94, alpha: 1.0), // creamWhite
            icon: nil,
            title: .init(
                text: "Harold needs you!",
                color: UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1.0) // charcoalOutline
            ),
            subtitle: .init(
                text: "Take a break from this app and check on your goose",
                color: UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
            ),
            primaryButtonLabel: .init(text: "Back to Harold", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.72, green: 0.91, blue: 0.82, alpha: 1.0) // mintBackground
            // secondaryButtonLabel intentionally omitted — no bypass
        )
    }
}
```

**Info.plist:**
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.deviceactivity.shield-configuration</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShieldConfigurationProvider</string>
</dict>
```

**project.yml addition:**
```yaml
TamaGoosieShield:
  type: app-extension
  platform: iOS
  sources:
    - Extensions/Shield
  dependencies:
    - sdk: ManagedSettings.framework
  settings:
    base:
      PRODUCT_BUNDLE_IDENTIFIER: com.tamagoosie.app.shield
      INFOPLIST_FILE: Extensions/Shield/Info.plist
  entitlements:
    path: Extensions/Shield/TamaGoosieShield.entitlements
    properties:
      com.apple.security.application-groups:
        - group.com.tamagoosie
      com.apple.developer.family-controls: true
```

### Step 5: Create DeviceActivityReport Extension

**New target:** `TamaGoosieReport`
**New directory:** `Extensions/Report/`
**Extension point:** `com.apple.deviceactivity.report`

This renders Apple's screen time data as a SwiftUI view. The data
stays sandboxed inside the extension — the main app embeds the view
but cannot read the raw numbers.

**Files:**
- `Extensions/Report/DistractionReportScene.swift`
- `Extensions/Report/Info.plist`
- `Extensions/Report/TamaGoosieReport.entitlements`

```swift
import DeviceActivity
import SwiftUI

struct DistractionReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "distraction_summary")

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 12) {
            Text("Screen Time Today")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Color(red: 0.18, green: 0.18, blue: 0.18))
            Text(configuration.totalActivityDuration
                .formatted(.components(style: .abbreviated)))
                .font(.system(.title, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.49)) // coralAccent
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(red: 1.0, green: 0.97, blue: 0.94)) // creamWhite
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

@main
struct DistractionReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        DistractionReportScene()
    }
}
```

**Info.plist:**
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.deviceactivity.report</string>
</dict>
```

**project.yml addition:**
```yaml
TamaGoosieReport:
  type: app-extension
  platform: iOS
  sources:
    - Extensions/Report
  dependencies:
    - sdk: DeviceActivity.framework
  settings:
    base:
      PRODUCT_BUNDLE_IDENTIFIER: com.tamagoosie.app.report
      INFOPLIST_FILE: Extensions/Report/Info.plist
  entitlements:
    path: Extensions/Report/TamaGoosieReport.entitlements
    properties:
      com.apple.security.application-groups:
        - group.com.tamagoosie
      com.apple.developer.family-controls: true
```

### Step 6: Update DistractionConfigView with Limit Editor + Report

**File:** `TamaGoosie/Features/Settings/DistractionConfigView.swift`

Add below the FamilyActivityPicker section:
1. **Limit slider** — Stepper from 15 to 120 min (default 30), saved via `ScreenTimeManager.userLimitMinutes`
2. **Screen Time Report** — Embed `DeviceActivityReport(.init(rawValue: "distraction_summary"))` so users see actual usage
3. **Status card** — show approximate minutes from last threshold hit

```swift
// Limit editor card
GoosieCard {
    VStack(alignment: .leading, spacing: 8) {
        Text("Daily Limit")
            .font(GoosieTheme.bodyFont(15))
        Stepper(
            "\(limitMinutes) minutes",
            value: $limitMinutes,
            in: 15...120,
            step: 15
        )
        .onChange(of: limitMinutes) { _, newVal in
            screenTimeManager.userLimitMinutes = newVal
        }
        Text("Apps will be blocked after this limit")
            .font(GoosieTheme.captionFont(12))
            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
    }
}

// Screen Time Report (rendered by extension)
DeviceActivityReport(.init(rawValue: "distraction_summary"))
    .frame(height: 120)
```

### Step 7: Update ContentView Foreground Sync

**File:** `TamaGoosie/App/ContentView.swift`

Change `processScreenTimeEvents()` to read `distractionApproxMinutes`
(the highest threshold reached) instead of counting threshold events.

**Anti-double-dipping:** Track `lastPenaltyApproxMinutes` in App Group UserDefaults.
The penalty is only applied for the *delta* between the current threshold bracket
and the last bracket we already penalized. If the user opens the app 5 times at
the 30-minute bracket, the penalty fires only once (on the first foreground after
crossing 30). The next penalty fires only when a *new* bracket is crossed (e.g., 45).

```swift
private func processScreenTimeEvents() {
    guard let state = gooseStates.first, !state.isDead else { return }
    let approxMinutes = ScreenTimeManager.shared.approxMinutesToday
    guard approxMinutes > 0 else { return }

    let log = fetchOrCreateTodayLog()
    log.distractionMinutes = max(log.distractionMinutes, approxMinutes)
    GooseEngine.shared.updateDistractMinutes(log.distractionMinutes)

    // Only penalize for NEW threshold brackets not yet penalized
    let defaults = UserDefaults(suiteName: GoosieConstants.appGroupID)!
    let lastPenalized = defaults.integer(forKey: GoosieConstants.screenTimeLastPenaltyMinutesKey)
    guard approxMinutes > lastPenalized else { return }

    // Penalty scales with the delta since last penalized bracket
    let deltaMinutes = approxMinutes - lastPenalized
    let penaltyMultiplier = Double(deltaMinutes) / 30.0
    let penalty = RewardEngine.StatDelta(
        happiness: -GoosieConstants.distractionOpenPenalty * penaltyMultiplier
    )
    RewardEngine.applyDelta(penalty, to: state)
    GooseEngine.shared.update(state: state)

    // Record that we've penalized up to this bracket
    defaults.set(approxMinutes, forKey: GoosieConstants.screenTimeLastPenaltyMinutesKey)
}
```

The monitor extension's `intervalDidEnd` must also reset `lastPenaltyApproxMinutes`
at midnight alongside the other counters.

### Step 8: Update project.yml — Full Extension Manifest

Add both new extension targets and embed them in the main app:

```yaml
TamaGoosie:
  dependencies:
    - target: TamaGoosieWidgets
    - target: TamaGoosieWatch
      embed: true
    - target: TamaGoosieDeviceActivity
      embed: true
    - target: TamaGoosieShield
      embed: true
    - target: TamaGoosieReport
      embed: true
    - sdk: FamilyControls.framework
    - sdk: DeviceActivity.framework
    - sdk: ManagedSettings.framework
```

Also update `TamaGoosieDeviceActivity` dependencies:
```yaml
dependencies:
  - sdk: DeviceActivity.framework
  - sdk: ManagedSettings.framework
  - sdk: UserNotifications.framework
```

### Step 9: Update TamaGoosie scheme

Add all extension targets to the build:

```yaml
schemes:
  TamaGoosie:
    build:
      targets:
        TamaGoosie: all
        TamaGoosieWidgets: all
        TamaGoosieDeviceActivity: all
        TamaGoosieShield: all
        TamaGoosieReport: all
        TamaGoosieTests: testing
```

---

## Key Files

| File | Operation | Description |
|------|-----------|-------------|
| `Shared/Constants.swift` | Modify | Replace 3 screen time keys with 8 (thresholds, limits, penalty tracking) |
| `TamaGoosie/Core/Models/DistractionApp.swift` | Delete | Dead model replaced by FamilyActivityPicker; no users → no migration |
| `TamaGoosie/Core/Models/UserProfile.swift` | Modify | Remove `distractionApps` relationship if present |
| `TamaGoosie/Core/Services/ScreenTimeManager.swift` | Rewrite | Stacked 4-threshold monitoring, limit management, approxMinutes |
| `TamaGoosieDeviceActivity/DeviceActivityMonitorExtension.swift` | Rewrite | Parse event names, shield apps at limit, send Harold notifications |
| `Extensions/Shield/ShieldConfigurationProvider.swift` | Create | Harold-themed shield UI when blocked app is opened |
| `Extensions/Shield/Info.plist` | Create | Shield extension info |
| `Extensions/Shield/TamaGoosieShield.entitlements` | Create | App Group + Family Controls |
| `Extensions/Report/DistractionReportScene.swift` | Create | SwiftUI view rendering actual screen time data |
| `Extensions/Report/Info.plist` | Create | Report extension info |
| `Extensions/Report/TamaGoosieReport.entitlements` | Create | App Group + Family Controls |
| `TamaGoosie/Features/Settings/DistractionConfigView.swift` | Modify | Add limit stepper + embedded DeviceActivityReport |
| `TamaGoosie/App/ContentView.swift` | Modify | Use approxMinutes instead of event count |
| `project.yml` | Modify | Add Shield + Report targets, embed in main app, update scheme |

---

## Risks and Mitigation

| Risk | Mitigation |
|------|------------|
| `com.apple.developer.family-controls` requires Apple approval for App Store | Works in development/TestFlight without approval; submit request early |
| DeviceActivityMonitor extension has 6MB memory limit | Keep extension code minimal — no SwiftData, no heavy imports |
| `FamilyActivitySelection` encoding may break across iOS versions | Use `PropertyListEncoder` (Apple's recommended approach), not JSONEncoder |
| Stacked thresholds only give 15-min granularity | Sufficient for happiness penalty; could add 5-min increments later |
| Users may want a bypass option on the shield | `secondaryButtonLabel` can be re-added later; omitted for v1 to be a stronger demo |
| `DeviceActivityReport.totalActivityDuration` may be empty if no usage | Show placeholder text "No data yet" when duration is zero |
| Notification from extension may not fire if notification permission not granted | Request notification permission during onboarding (already done via NotificationManager) |
| Removing `DistractionApp` model changes SwiftData schema | No users yet — no migration needed; delete cleanly in Step 1.5 |
| Penalty double-dipping on repeated foreground | `lastPenaltyApproxMinutes` in App Group tracks last penalized bracket; reset at midnight |

---

## Architecture Diagram

```
Main App (TamaGoosie)
├── ScreenTimeManager ── FamilyControls auth + DeviceActivityCenter scheduling
├── DistractionConfigView ── FamilyActivityPicker + limit stepper
├── ContentView ── reads App Group on foreground → updates DailyLog + GooseState
│
├── [embedded] TamaGoosieDeviceActivity (Monitor Extension)
│   └── eventDidReachThreshold → writes hits/approxMinutes to App Group
│   └── shields apps via ManagedSettingsStore when limit exceeded
│   └── sends Harold notification via UNUserNotificationCenter
│
├── [embedded] TamaGoosieShield (Shield Config Extension)
│   └── renders "Harold needs you!" screen when shielded app is opened
│
├── [embedded] TamaGoosieReport (Report Extension)
│   └── renders actual screen time data as SwiftUI view (embedded in config)
│
└── App Group UserDefaults (group.com.tamagoosie)
    ├── screenTimeSelection (FamilyActivitySelection encoded as Data)
    ├── distractionLimitMinutes (Int, user-configured)
    ├── distractionHitsToday (Int, incremented by monitor)
    ├── distractionApproxMinutes (Int, highest threshold hit today)
    ├── lastDistractionHit (TimeInterval, timestamp)
    └── lastPenaltyApproxMinutes (Int, last bracket penalized — prevents double-dipping)
```

---

## SESSION_ID

- CODEX_SESSION: N/A (no external backend available)
- GEMINI_SESSION: N/A (no external backend available)
