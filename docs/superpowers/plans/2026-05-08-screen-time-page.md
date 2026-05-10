# Screen Time Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Screen Time page to the side menu with a first-visit onboarding flow, schedule-based app limiting, and a rich stats dashboard.

**Architecture:** The page container (`ScreenTimePageView`) switches between an onboarding flow and a dashboard based on a UserDefaults flag. The existing `ScreenTimeManager` gains schedule fields. The `DeviceActivityMonitorExtension` and `ShieldConfigurationProvider` are updated to use the goose's name. The data pipeline is fixed so distraction minutes flow from the extension into `DailyLog` and affect happiness.

**Tech Stack:** SwiftUI, FamilyControls, DeviceActivity, ManagedSettings, SwiftData, XcodeGen

---

## File Structure

| File | Role |
|------|------|
| `project.yml` | Re-enable Screen Time extension targets and FamilyControls SDK |
| `Shared/Constants.swift` | Add new UserDefaults keys for schedule, setup-complete, paused |
| `TamaGoosie/Core/Services/ScreenTimeManager.swift` | Add schedule fields, active days, paused state |
| `TamaGoosie/Features/ScreenTime/ScreenTimePageView.swift` | Container: switches onboarding vs dashboard |
| `TamaGoosie/Features/ScreenTime/ScreenTimeOnboardingView.swift` | 6-step onboarding flow |
| `TamaGoosie/Features/ScreenTime/ScreenTimeScheduleView.swift` | Reusable schedule/limit config |
| `TamaGoosie/Features/ScreenTime/ScreenTimeDashboardView.swift` | Stats dashboard with day/week toggle |
| `TamaGoosie/App/ContentView.swift` | Add menu item, distraction sync |
| `TamaGoosieDeviceActivity/DeviceActivityMonitorExtension.swift` | Goose name in notifications |
| `Extensions/Shield/ShieldConfigurationProvider.swift` | Goose name in shield |

---

### Task 1: Re-enable Screen Time targets in project.yml

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Uncomment Screen Time extension targets and dependencies**

In `project.yml`, uncomment the Screen Time SDK dependencies in the main `TamaGoosie` target, the `TamaGoosieDeviceActivity` target, the `TamaGoosieShield` target, the `TamaGoosieReport` target, the Family Controls entitlement, and the scheme build entries.

The `TamaGoosie` target dependencies section should become:

```yaml
    dependencies:
      - package: ConvexMobile
        product: ConvexMobile
      - package: GoogleSignIn
        product: GoogleSignIn
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
      - sdk: FoundationModels.framework
```

The entitlements section should uncomment `com.apple.developer.family-controls`:

```yaml
    entitlements:
      path: TamaGoosie/TamaGoosie.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.tamagoosie
        com.apple.developer.healthkit: true
        com.apple.developer.applesignin:
          - Default
        com.apple.developer.family-controls: true
```

Uncomment all three extension targets (`TamaGoosieDeviceActivity`, `TamaGoosieShield`, `TamaGoosieReport`) and the scheme build entries for them.

- [ ] **Step 2: Regenerate Xcode project**

```bash
cd /Users/PriscillaYe/Documents/GitHub/TamaGoosie && xcodegen generate
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add project.yml && git commit -m "chore: re-enable Screen Time extension targets in project.yml"
```

---

### Task 2: Add new constants for schedule and setup state

**Files:**
- Modify: `Shared/Constants.swift`

- [ ] **Step 1: Add new constants**

Add these to the `// MARK: - Screen Time` section in `Shared/Constants.swift`:

```swift
    public static let screenTimeSetupCompleteKey = "screenTimeSetupComplete"
    public static let screenTimePausedKey = "screenTimePaused"
    public static let screenTimeIsAllDayKey = "screenTimeIsAllDay"
    public static let screenTimeStartHourKey = "screenTimeStartHour"
    public static let screenTimeStartMinuteKey = "screenTimeStartMinute"
    public static let screenTimeEndHourKey = "screenTimeEndHour"
    public static let screenTimeEndMinuteKey = "screenTimeEndMinute"
    public static let screenTimeActiveDaysKey = "screenTimeActiveDays"
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add Shared/Constants.swift && git commit -m "feat: add Screen Time schedule and setup constants"
```

---

### Task 3: Add schedule support to ScreenTimeManager

**Files:**
- Modify: `TamaGoosie/Core/Services/ScreenTimeManager.swift`

- [ ] **Step 1: Add schedule properties and update monitoring**

Replace the entire contents of `ScreenTimeManager.swift` with:

```swift
import Foundation
import FamilyControls
import DeviceActivity

@Observable
@MainActor
final class ScreenTimeManager {

    static let shared = ScreenTimeManager()

    var authorizationStatus: AuthorizationStatus = .notDetermined
    var selection = FamilyActivitySelection()

    var isAuthorized: Bool { authorizationStatus == .approved }
    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    private let authCenter = AuthorizationCenter.shared
    private let activityCenter = DeviceActivityCenter()
    private let defaults = UserDefaults(suiteName: GoosieConstants.appGroupID)!

    private init() {
        authorizationStatus = authCenter.authorizationStatus
        loadSelection()
        if isAuthorized && hasSelection && !isPaused {
            startDailyMonitoring()
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            try await authCenter.requestAuthorization(for: .individual)
            authorizationStatus = authCenter.authorizationStatus
            if isAuthorized && hasSelection && !isPaused {
                startDailyMonitoring()
            }
        } catch {
            authorizationStatus = authCenter.authorizationStatus
        }
    }

    // MARK: - Selection

    func saveSelection(_ newSelection: FamilyActivitySelection) {
        selection = newSelection
        if let data = try? PropertyListEncoder().encode(newSelection) {
            defaults.set(data, forKey: GoosieConstants.screenTimeSelectionKey)
        }
        if !isPaused {
            startDailyMonitoring()
        }
    }

    private func loadSelection() {
        guard let data = defaults.data(forKey: GoosieConstants.screenTimeSelectionKey),
              let loaded = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        selection = loaded
    }

    // MARK: - Limit Management

    var userLimitMinutes: Int {
        get {
            let stored = defaults.integer(forKey: GoosieConstants.screenTimeLimitKey)
            return stored > 0 ? stored : GoosieConstants.screenTimeDefaultLimitMinutes
        }
        set {
            defaults.set(newValue, forKey: GoosieConstants.screenTimeLimitKey)
            if !isPaused { startDailyMonitoring() }
        }
    }

    var approxMinutesToday: Int {
        defaults.integer(forKey: GoosieConstants.screenTimeApproxMinutesKey)
    }

    // MARK: - Setup Complete

    var isSetupComplete: Bool {
        get { defaults.bool(forKey: GoosieConstants.screenTimeSetupCompleteKey) }
        set { defaults.set(newValue, forKey: GoosieConstants.screenTimeSetupCompleteKey) }
    }

    // MARK: - Pause

    var isPaused: Bool {
        get { defaults.bool(forKey: GoosieConstants.screenTimePausedKey) }
        set {
            defaults.set(newValue, forKey: GoosieConstants.screenTimePausedKey)
            if newValue {
                stopMonitoring()
            } else if isAuthorized && hasSelection {
                startDailyMonitoring()
            }
        }
    }

    // MARK: - Schedule

    var isAllDay: Bool {
        get {
            if defaults.object(forKey: GoosieConstants.screenTimeIsAllDayKey) == nil { return true }
            return defaults.bool(forKey: GoosieConstants.screenTimeIsAllDayKey)
        }
        set {
            defaults.set(newValue, forKey: GoosieConstants.screenTimeIsAllDayKey)
            if !isPaused { startDailyMonitoring() }
        }
    }

    var scheduleStartHour: Int {
        get { defaults.object(forKey: GoosieConstants.screenTimeStartHourKey) == nil ? 8 : defaults.integer(forKey: GoosieConstants.screenTimeStartHourKey) }
        set { defaults.set(newValue, forKey: GoosieConstants.screenTimeStartHourKey) }
    }

    var scheduleStartMinute: Int {
        get { defaults.integer(forKey: GoosieConstants.screenTimeStartMinuteKey) }
        set { defaults.set(newValue, forKey: GoosieConstants.screenTimeStartMinuteKey) }
    }

    var scheduleEndHour: Int {
        get { defaults.object(forKey: GoosieConstants.screenTimeEndHourKey) == nil ? 22 : defaults.integer(forKey: GoosieConstants.screenTimeEndHourKey) }
        set { defaults.set(newValue, forKey: GoosieConstants.screenTimeEndHourKey) }
    }

    var scheduleEndMinute: Int {
        get { defaults.integer(forKey: GoosieConstants.screenTimeEndMinuteKey) }
        set { defaults.set(newValue, forKey: GoosieConstants.screenTimeEndMinuteKey) }
    }

    var activeDays: Set<Int> {
        get {
            if let array = defaults.array(forKey: GoosieConstants.screenTimeActiveDaysKey) as? [Int] {
                return Set(array)
            }
            return Set(1...7)
        }
        set {
            defaults.set(Array(newValue), forKey: GoosieConstants.screenTimeActiveDaysKey)
            if !isPaused { startDailyMonitoring() }
        }
    }

    // MARK: - Monitoring

    func startDailyMonitoring() {
        guard isAuthorized, hasSelection else { return }

        let weekday = Calendar.current.component(.weekday, from: .now)
        guard activeDays.contains(weekday) else {
            stopMonitoring()
            return
        }

        activityCenter.stopMonitoring()

        let startComps: DateComponents
        let endComps: DateComponents

        if isAllDay {
            startComps = DateComponents(hour: 0, minute: 0)
            endComps = DateComponents(hour: 23, minute: 59)
        } else {
            startComps = DateComponents(hour: scheduleStartHour, minute: scheduleStartMinute)
            endComps = DateComponents(hour: scheduleEndHour, minute: scheduleEndMinute)
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd: endComps,
            repeats: true
        )

        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = Dictionary(
            uniqueKeysWithValues: GoosieConstants.screenTimeThresholds.map { mins in
                let name = DeviceActivityEvent.Name("distraction-\(mins)")
                let event = DeviceActivityEvent(
                    applications: selection.applicationTokens,
                    categories: selection.categoryTokens,
                    webDomains: selection.webDomainTokens,
                    threshold: DateComponents(minute: mins)
                )
                return (name, event)
            }
        )

        do {
            try activityCenter.startMonitoring(
                DeviceActivityName("daily-distraction"),
                during: schedule,
                events: events
            )
        } catch {
            print("[ScreenTimeManager] startMonitoring failed: \(error)")
        }
    }

    func stopMonitoring() {
        activityCenter.stopMonitoring()
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Core/Services/ScreenTimeManager.swift && git commit -m "feat: add schedule, pause, and setup-complete to ScreenTimeManager"
```

---

### Task 4: Create ScreenTimeScheduleView (reusable config)

**Files:**
- Create: `TamaGoosie/Features/ScreenTime/ScreenTimeScheduleView.swift`

- [ ] **Step 1: Create the schedule config view**

```swift
import SwiftUI

struct ScreenTimeScheduleView: View {
    @State private var manager = ScreenTimeManager.shared

    @State private var limitMinutes: Int
    @State private var isAllDay: Bool
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var activeDays: Set<Int>

    let onSave: () -> Void

    init(onSave: @escaping () -> Void) {
        let m = ScreenTimeManager.shared
        _limitMinutes = State(initialValue: m.userLimitMinutes)
        _isAllDay = State(initialValue: m.isAllDay)
        _activeDays = State(initialValue: m.activeDays)

        var startComps = DateComponents()
        startComps.hour = m.scheduleStartHour
        startComps.minute = m.scheduleStartMinute
        _startTime = State(initialValue: Calendar.current.date(from: startComps) ?? Date())

        var endComps = DateComponents()
        endComps.hour = m.scheduleEndHour
        endComps.minute = m.scheduleEndMinute
        _endTime = State(initialValue: Calendar.current.date(from: endComps) ?? Date())

        self.onSave = onSave
    }

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 16) {
            // Daily limit
            GoosieCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Limit")
                        .font(GoosieTheme.bodyFont(15))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                    Stepper(
                        "\(limitMinutes) minutes",
                        value: $limitMinutes,
                        in: 15...120,
                        step: 15
                    )
                    .font(GoosieTheme.captionFont(13))
                    Text("Apps will be blocked after this limit")
                        .font(GoosieTheme.captionFont(12))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                }
            }

            // Schedule
            GoosieCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Schedule")
                            .font(GoosieTheme.bodyFont(15))
                            .foregroundStyle(GoosieTheme.charcoalOutline)
                        Spacer()
                        HStack(spacing: 6) {
                            Text("All the time")
                                .font(GoosieTheme.captionFont(13))
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                            Toggle("", isOn: $isAllDay)
                                .labelsHidden()
                                .tint(GoosieTheme.skyBlue)
                        }
                    }

                    if !isAllDay {
                        VStack(spacing: 0) {
                            HStack {
                                Text("From")
                                    .font(GoosieTheme.captionFont(14))
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                                Spacer()
                                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 10)

                            Divider()

                            HStack {
                                Text("To")
                                    .font(GoosieTheme.captionFont(14))
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                                Spacer()
                                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 10)
                        }

                        // Day of week selectors
                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { day in
                                let isActive = activeDays.contains(day)
                                Button {
                                    if isActive {
                                        activeDays.remove(day)
                                    } else {
                                        activeDays.insert(day)
                                    }
                                } label: {
                                    Text(dayLabels[day - 1])
                                        .font(GoosieTheme.bodyFont(14))
                                        .foregroundStyle(isActive ? .white : GoosieTheme.charcoalOutline)
                                        .frame(width: 38, height: 38)
                                        .background(
                                            Circle()
                                                .fill(isActive ? GoosieTheme.skyBlue : GoosieTheme.charcoalOutline.opacity(0.1))
                                        )
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }

            // Save button
            Button(action: save) {
                Text("Save")
                    .font(GoosieTheme.bodyFont(16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(GoosieTheme.skyBlue, in: RoundedRectangle(cornerRadius: GoosieTheme.cornerRadius))
            }
            .padding(.top, 8)
        }
    }

    private func save() {
        manager.userLimitMinutes = limitMinutes
        manager.isAllDay = isAllDay

        if !isAllDay {
            let startComps = Calendar.current.dateComponents([.hour, .minute], from: startTime)
            manager.scheduleStartHour = startComps.hour ?? 8
            manager.scheduleStartMinute = startComps.minute ?? 0
            let endComps = Calendar.current.dateComponents([.hour, .minute], from: endTime)
            manager.scheduleEndHour = endComps.hour ?? 22
            manager.scheduleEndMinute = endComps.minute ?? 0
        }

        manager.activeDays = activeDays
        manager.startDailyMonitoring()
        onSave()
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/ScreenTime/ScreenTimeScheduleView.swift && git commit -m "feat: add ScreenTimeScheduleView with limit, schedule, and day-of-week config"
```

---

### Task 5: Create ScreenTimeOnboardingView

**Files:**
- Create: `TamaGoosie/Features/ScreenTime/ScreenTimeOnboardingView.swift`

- [ ] **Step 1: Create the onboarding flow**

```swift
import SwiftUI
import FamilyControls

struct ScreenTimeOnboardingView: View {
    let gooseName: String
    let onComplete: () -> Void

    @State private var step = 0
    @State private var manager = ScreenTimeManager.shared
    @State private var showPicker = false
    @State private var draftSelection = FamilyActivitySelection()

    // Total steps: 0-5 (3 intro + permissions + app picker + schedule)
    private let totalSteps = 6

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 12)

            // Step content
            ZStack {
                switch step {
                case 0: awarenessStep
                case 1: problemStep
                case 2: solutionStep
                case 3: permissionsStep
                case 4: appSelectionStep
                case 5: scheduleStep
                default: EmptyView()
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $draftSelection)
        .onChange(of: showPicker) { wasShowing, isShowing in
            if wasShowing && !isShowing && !draftSelection.applicationTokens.isEmpty || !draftSelection.categoryTokens.isEmpty {
                manager.saveSelection(draftSelection)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            if step > 0 {
                Button {
                    step -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                }
            }

            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? GoosieTheme.skyBlue : GoosieTheme.charcoalOutline.opacity(0.15))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Step 0: Awareness

    private var awarenessStep: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Do you know how long\nyou scroll each day?")
                .font(GoosieTheme.titleFont(24))
                .foregroundStyle(GoosieTheme.charcoalOutline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 32)

            GooseCharacterView(mood: .bored)
                .frame(height: 200)

            Spacer()

            stepButton(title: "probably... too long?") {
                step = 1
            }
        }
    }

    // MARK: - Step 1: Problem

    private var problemStep: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("One quick scroll...\nand 30 minutes are gone.")
                .font(GoosieTheme.titleFont(24))
                .foregroundStyle(GoosieTheme.charcoalOutline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 32)

            GooseCharacterView(mood: .sad)
                .frame(height: 200)

            Spacer()

            stepButton(title: "that's me...") {
                step = 2
            }
        }
    }

    // MARK: - Step 2: Solution

    private var solutionStep: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("\(gooseName) will help\nguard your time!")
                .font(GoosieTheme.titleFont(24))
                .foregroundStyle(GoosieTheme.charcoalOutline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 32)

            GooseCharacterView(mood: .ecstatic)
                .frame(height: 200)

            Spacer()

            stepButton(title: "Let's set it up!") {
                step = 3
            }
        }
    }

    // MARK: - Step 3: Permissions

    private var permissionsStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Enable Screen Time Guard")
                    .font(GoosieTheme.titleFont(22))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Text("Just a few quick steps to start guarding your time:")
                    .font(GoosieTheme.captionFont(14))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GoosieTheme.padding)

            Spacer().frame(height: 32)

            VStack(spacing: 16) {
                // Screen Time toggle
                GoosieCard {
                    HStack(spacing: 12) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 22))
                            .foregroundStyle(GoosieTheme.skyBlue)
                            .frame(width: 40, height: 40)
                            .background(GoosieTheme.skyBlue.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Screen Time")
                                .font(GoosieTheme.bodyFont(15))
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                            Text("Let TamaGoosie access your app-usage data.")
                                .font(GoosieTheme.captionFont(12))
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                        }
                        Spacer()
                        Toggle("", isOn: .init(
                            get: { manager.isAuthorized },
                            set: { _ in Task { await manager.requestAuthorization() } }
                        ))
                        .labelsHidden()
                        .tint(GoosieTheme.skyBlue)
                    }
                }
            }
            .padding(.horizontal, GoosieTheme.padding)

            Spacer()

            Text("Data is stored only on your device.")
                .font(GoosieTheme.captionFont(12))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                .padding(.bottom, 8)

            stepButton(title: "Let's Go", isEnabled: manager.isAuthorized) {
                step = 4
            }
        }
    }

    // MARK: - Step 4: App Selection

    private var appSelectionStep: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Choose apps to limit")
                .font(GoosieTheme.titleFont(24))
                .foregroundStyle(GoosieTheme.charcoalOutline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 16)

            Text("Pick the apps that distract you most.\n\(gooseName) will keep an eye on them.")
                .font(GoosieTheme.captionFont(14))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer().frame(height: 32)

            GooseCharacterView(mood: .happy)
                .frame(height: 160)

            Spacer().frame(height: 24)

            PillButton(
                title: manager.hasSelection ? "Change Selected Apps" : "Select Apps",
                icon: "app.badge",
                color: GoosieTheme.coralAccent
            ) {
                draftSelection = manager.selection
                showPicker = true
            }

            if manager.hasSelection {
                let count = manager.selection.applicationTokens.count + manager.selection.categoryTokens.count
                Text("\(count) item\(count == 1 ? "" : "s") selected")
                    .font(GoosieTheme.captionFont(12))
                    .foregroundStyle(GoosieTheme.skyBlue)
                    .padding(.top, 8)
            }

            Spacer()

            stepButton(title: "Continue", isEnabled: manager.hasSelection) {
                step = 5
            }
        }
    }

    // MARK: - Step 5: Schedule

    private var scheduleStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Set your limits")
                    .font(GoosieTheme.titleFont(24))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                    .padding(.top, 20)

                ScreenTimeScheduleView {
                    manager.isSetupComplete = true
                    onComplete()
                }
            }
            .padding(.horizontal, GoosieTheme.padding)
        }
    }

    // MARK: - Shared Button

    private func stepButton(title: String, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(GoosieTheme.bodyFont(16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: GoosieTheme.cornerRadius)
                        .fill(isEnabled ? GoosieTheme.skyBlue : GoosieTheme.charcoalOutline.opacity(0.2))
                )
        }
        .disabled(!isEnabled)
        .padding(.horizontal, GoosieTheme.padding)
        .padding(.bottom, 36)
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/ScreenTime/ScreenTimeOnboardingView.swift && git commit -m "feat: add ScreenTimeOnboardingView with 6-step setup flow"
```

---

### Task 6: Create ScreenTimeDashboardView

**Files:**
- Create: `TamaGoosie/Features/ScreenTime/ScreenTimeDashboardView.swift`

- [ ] **Step 1: Create the dashboard view**

```swift
import SwiftUI
import SwiftData
import DeviceActivity

struct ScreenTimeDashboardView: View {
    @State private var manager = ScreenTimeManager.shared
    @State private var selectedPeriod = 0 // 0 = Day, 1 = Week
    @State private var selectedDate = Date()
    @State private var showEditSheet = false
    @State private var showPicker = false
    @State private var draftSelection = FamilyActivitySelection()

    @Query(sort: \DailyLog.date, order: .reverse) private var allLogs: [DailyLog]

    private var todayLog: DailyLog? {
        allLogs.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var yesterdayLog: DailyLog? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        return allLogs.first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
    }

    private var weekLogs: [DailyLog] {
        let cal = Calendar.current
        guard let weekStart = cal.date(byAdding: .day, value: -6, to: selectedDate) else { return [] }
        return allLogs.filter { $0.date >= cal.startOfDay(for: weekStart) && $0.date <= cal.startOfDay(for: selectedDate) }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                periodPicker
                dateNavigation
                statCards
                distributionReport
                actionButtons
            }
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showEditSheet) {
            editPlanSheet
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $draftSelection)
        .onChange(of: showPicker) { wasShowing, isShowing in
            if wasShowing && !isShowing {
                manager.saveSelection(draftSelection)
            }
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            Text("Day").tag(0)
            Text("Week").tag(1)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Date Navigation

    private var dateNavigation: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(
                    byAdding: selectedPeriod == 0 ? .day : .weekOfYear,
                    value: -1,
                    to: selectedDate
                ) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
            }

            Spacer()

            Text(dateLabel)
                .font(GoosieTheme.bodyFont(15))
                .foregroundStyle(GoosieTheme.charcoalOutline)

            Spacer()

            Button {
                let next = Calendar.current.date(
                    byAdding: selectedPeriod == 0 ? .day : .weekOfYear,
                    value: 1,
                    to: selectedDate
                ) ?? selectedDate
                if next <= Date() {
                    selectedDate = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        isToday ? GoosieTheme.charcoalOutline.opacity(0.15) : GoosieTheme.charcoalOutline.opacity(0.5)
                    )
            }
            .disabled(isToday)
        }
        .padding(.vertical, 4)
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let base = formatter.string(from: selectedDate)
        return isToday ? "\(base) (Today)" : base
    }

    // MARK: - Stat Cards

    private var statCards: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "iphone.slash",
                iconColor: GoosieTheme.coralAccent,
                title: "Distraction Time",
                value: formatMinutes(distractionMinutesForPeriod),
                change: distractionChange
            )

            statCard(
                icon: "hourglass",
                iconColor: GoosieTheme.skyBlue,
                title: "Limit Remaining",
                value: formatMinutes(max(0, manager.userLimitMinutes - currentDistractionMinutes)),
                change: nil
            )
        }
    }

    private var distractionMinutesForPeriod: Int {
        if selectedPeriod == 0 {
            return todayLog?.distractionMinutes ?? manager.approxMinutesToday
        } else {
            return weekLogs.reduce(0) { $0 + $1.distractionMinutes }
        }
    }

    private var currentDistractionMinutes: Int {
        todayLog?.distractionMinutes ?? manager.approxMinutesToday
    }

    private var distractionChange: String? {
        if selectedPeriod == 0 {
            guard let yesterday = yesterdayLog, yesterday.distractionMinutes > 0 else {
                return "No prior data"
            }
            let current = todayLog?.distractionMinutes ?? manager.approxMinutesToday
            if current == 0 && yesterday.distractionMinutes == 0 { return nil }
            let pct = Int(round(Double(current - yesterday.distractionMinutes) / Double(yesterday.distractionMinutes) * 100))
            if pct < 0 {
                return "\(pct)%"
            } else if pct > 0 {
                return "+\(pct)%"
            }
            return "No change"
        }
        return nil
    }

    private func statCard(icon: String, iconColor: Color, title: String, value: String, change: String?) -> some View {
        GoosieCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(iconColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(GoosieTheme.captionFont(12))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                Text(value)
                    .font(GoosieTheme.titleFont(22))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                if let change {
                    Text(change)
                        .font(GoosieTheme.captionFont(11))
                        .foregroundStyle(changeColor(change))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(changeColor(change).opacity(0.12), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func changeColor(_ change: String) -> Color {
        if change.hasPrefix("-") || change.hasPrefix("\u{2193}") {
            return .green
        } else if change.hasPrefix("+") || change.hasPrefix("\u{2191}") {
            return GoosieTheme.coralAccent
        }
        return GoosieTheme.charcoalOutline.opacity(0.5)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    // MARK: - Distribution Report

    private var distributionReport: some View {
        GoosieCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(GoosieTheme.skyBlue)
                    Text("Screen Time Distribution")
                        .font(GoosieTheme.bodyFont(14))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                }

                DeviceActivityReport(.init(rawValue: "distraction_summary"))
                    .frame(height: 120)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Edit Plan
            Button {
                showEditSheet = true
            } label: {
                HStack {
                    Text("Edit Plan")
                        .font(GoosieTheme.bodyFont(15))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                }
                .padding(GoosieTheme.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: GoosieTheme.smallCornerRadius)
                        .fill(GoosieTheme.creamWhite)
                )
            }

            // Pause toggle
            GoosieCard {
                HStack {
                    Text("Pause Plan")
                        .font(GoosieTheme.bodyFont(15))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { manager.isPaused },
                        set: { manager.isPaused = $0 }
                    ))
                    .labelsHidden()
                    .tint(GoosieTheme.coralAccent)
                }
            }
        }
    }

    // MARK: - Edit Sheet

    private var editPlanSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // App selection
                    PillButton(
                        title: "Change Selected Apps",
                        icon: "app.badge",
                        color: GoosieTheme.coralAccent
                    ) {
                        draftSelection = manager.selection
                        showPicker = true
                    }

                    if manager.hasSelection {
                        let count = manager.selection.applicationTokens.count + manager.selection.categoryTokens.count
                        Text("\(count) item\(count == 1 ? "" : "s") selected")
                            .font(GoosieTheme.captionFont(12))
                            .foregroundStyle(GoosieTheme.skyBlue)
                    }

                    ScreenTimeScheduleView {
                        showEditSheet = false
                    }
                }
                .padding(GoosieTheme.padding)
            }
            .background(GoosieTheme.mintBackground.ignoresSafeArea())
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEditSheet = false }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/ScreenTime/ScreenTimeDashboardView.swift && git commit -m "feat: add ScreenTimeDashboardView with stats, date nav, and edit plan"
```

---

### Task 7: Create ScreenTimePageView (container)

**Files:**
- Create: `TamaGoosie/Features/ScreenTime/ScreenTimePageView.swift`

- [ ] **Step 1: Create the page container**

```swift
import SwiftUI
import SwiftData

struct ScreenTimePageView: View {
    @State private var manager = ScreenTimeManager.shared
    @Query private var gooseStates: [GooseState]

    private var gooseName: String {
        gooseStates.first?.name ?? "Harold"
    }

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground
                .ignoresSafeArea()

            if manager.isSetupComplete {
                ScreenTimeDashboardView()
            } else {
                ScreenTimeOnboardingView(gooseName: gooseName) {
                    // onComplete — setup is done, manager.isSetupComplete is now true
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/ScreenTime/ScreenTimePageView.swift && git commit -m "feat: add ScreenTimePageView container switching onboarding vs dashboard"
```

---

### Task 8: Wire into ContentView side menu

**Files:**
- Modify: `TamaGoosie/App/ContentView.swift`

- [ ] **Step 1: Update menu items — add Screen Time (id 6), bump Settings to id 7**

In `ContentView.swift`, replace the `menuItems` computed property:

```swift
    private var menuItems: [MenuItem] {
        [
            MenuItem(id: 0, title: "Goose", assetImage: "goose_icon"),
            MenuItem(id: 1, title: "Goals", systemImage: "checklist"),
            MenuItem(id: 2, title: "Chat", systemImage: "bubble.left.fill"),
            MenuItem(id: 3, title: "Friends", systemImage: "person.2.fill"),
            MenuItem(id: 4, title: "Stats", systemImage: "chart.line.uptrend.xyaxis"),
            MenuItem(id: 5, title: "Screen Time", systemImage: "hourglass"),
            MenuItem(id: 6, title: "Settings", systemImage: "gearshape.fill"),
        ]
    }
```

- [ ] **Step 2: Update currentPageTitle**

Replace the `currentPageTitle` computed property:

```swift
    private var currentPageTitle: String {
        switch selectedTab {
        case 1: return "Goals"
        case 2: return "Chat"
        case 3: return "Friends"
        case 4: return "Stats"
        case 5: return "Screen Time"
        case 6: return "Settings"
        default: return ""
        }
    }
```

- [ ] **Step 3: Update currentPageView**

Replace the `currentPageView` computed property:

```swift
    @ViewBuilder
    private var currentPageView: some View {
        switch selectedTab {
        case 0: GooseView(onMenuTap: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showMenu.toggle()
            }
        })
        case 1: GoalListView()
        case 2: ChatView()
        case 3: FriendsView()
        case 4: StatsView()
        case 5: ScreenTimePageView()
        case 6: SettingsView()
        default: GooseView()
        }
    }
```

- [ ] **Step 4: Add distraction minutes sync to syncHealthData()**

In `syncHealthData()`, add these lines right after `GooseEngine.shared.syncBuiltinGoalProgress(allGoals)` (line ~381):

```swift
        // Sync distraction minutes from DeviceActivityMonitor
        let distractionDefaults = UserDefaults(suiteName: GoosieConstants.appGroupID)
        let approxDistraction = distractionDefaults?.integer(forKey: GoosieConstants.screenTimeApproxMinutesKey) ?? 0
        if approxDistraction > log.distractionMinutes {
            log.distractionMinutes = approxDistraction
        }
```

Note: `log` is the `fetchOrCreateTodayLog()` result already computed earlier in the function.

- [ ] **Step 5: Build to verify**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 6: Commit**

```bash
git add TamaGoosie/App/ContentView.swift && git commit -m "feat: add Screen Time to side menu and sync distraction minutes to DailyLog"
```

---

### Task 9: Personalize goose name in extensions

**Files:**
- Modify: `TamaGoosieDeviceActivity/DeviceActivityMonitorExtension.swift`
- Modify: `Extensions/Shield/ShieldConfigurationProvider.swift`

- [ ] **Step 1: Update DeviceActivityMonitorExtension notification to use goose name**

Replace the `sendNotification` method in `DeviceActivityMonitorExtension.swift`:

```swift
    private func sendNotification(approxMinutes: Int) {
        let name = gooseNameFromDefaults()

        let content = UNMutableNotificationContent()
        content.title = "\(name) is worried"
        content.body = approxMinutes >= 60
            ? "You've been on distracting apps for over an hour... \(name) is getting sad"
            : "You've hit \(approxMinutes) minutes on distracting apps today"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "distraction-\(approxMinutes)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func gooseNameFromDefaults() -> String {
        guard let data = defaults.data(forKey: "gooseStats"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String, !name.isEmpty
        else { return "Your goose" }
        return name
    }
```

- [ ] **Step 2: Update ShieldConfigurationProvider to use goose name**

Replace the entire `ShieldConfigurationProvider.swift`:

```swift
import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationProvider: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let name = gooseNameFromDefaults()

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor(red: 1.0, green: 0.97, blue: 0.94, alpha: 1.0),
            icon: nil,
            title: .init(
                text: "\(name) needs you!",
                color: UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1.0)
            ),
            subtitle: .init(
                text: "Take a break from this app and check on \(name)",
                color: UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
            ),
            primaryButtonLabel: .init(text: "Back to \(name)", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.72, green: 0.91, blue: 0.82, alpha: 1.0)
        )
    }

    private func gooseNameFromDefaults() -> String {
        let defaults = UserDefaults(suiteName: "group.com.tamagoosie")
        guard let data = defaults?.data(forKey: "gooseStats"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String, !name.isEmpty
        else { return "Your goose" }
        return name
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add TamaGoosieDeviceActivity/DeviceActivityMonitorExtension.swift Extensions/Shield/ShieldConfigurationProvider.swift && git commit -m "feat: use goose name in distraction notifications and shield screen"
```

---

### Task 10: Final build verification

- [ ] **Step 1: Full clean build**

```bash
xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Verify new files are in Xcode project**

Since XcodeGen auto-includes all `.swift` files under `TamaGoosie/` via the `sources: - TamaGoosie` entry, the new `Features/ScreenTime/` files should be automatically picked up. If they're not, run:

```bash
xcodegen generate
```

- [ ] **Step 3: Commit any remaining changes**

```bash
git add -A && git status
```

If there are changes, commit them:

```bash
git commit -m "chore: final build verification for Screen Time page"
```
