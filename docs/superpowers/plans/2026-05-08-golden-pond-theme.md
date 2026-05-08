# Golden Pond Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retheme TamaGoosie from mint/coral to a warm cream/amber/brown "Golden Pond" palette with pond-teal accents and more playful typography/components.

**Architecture:** All colors flow through `GoosieTheme` tokens. Update tokens first, then fix any view-specific hardcoded colors and component structure. Typography gets a playful serif title font and bouncier sizing. No goose asset images change.

**Tech Stack:** SwiftUI, Swift

---

### Task 1: Update GoosieTheme Color Tokens

**Files:**
- Modify: `TamaGoosie/Theme/GoosieTheme.swift`

- [ ] **Step 1: Replace all color tokens**

```swift
enum GoosieTheme {
    // MARK: Colors
    static let mintBackground = Color(hex: 0xFFF5E6)      // warm cream (was mint)
    static let creamWhite = Color(hex: 0xFFFDF8)           // warmer card white
    static let coralAccent = Color(hex: 0xE8963A)          // warm amber (was coral)
    static let sunYellow = Color(hex: 0xD4A853)            // golden yellow
    static let warmOrange = Color(hex: 0xD4782A)           // deeper amber
    static let softPink = Color(hex: 0xFFD4B8)             // peach
    static let charcoalOutline = Color(hex: 0x5C4A3A)      // warm brown (was black)
    static let skyBlue = Color(hex: 0x7BBFA0)              // pond sage (was sky blue)

    // MARK: Stat Colors
    static let healthRed = Color(hex: 0xE87461)            // warm terracotta
    static let happinessYellow = Color(hex: 0xE8963A)      // amber
    static let energyBlue = Color(hex: 0x5AAFB8)           // pond teal
    static let hygieneGreen = Color(hex: 0xA8D4B8)         // sage green

    // MARK: Chat
    static let gooseBubble = Color(hex: 0xD4F0EA)          // light teal for goose chat bubbles
```

- [ ] **Step 2: Update typography to be more playful**

Replace the three font methods with:

```swift
    // MARK: Typography
    static func titleFont(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func bodyFont(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func captionFont(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
```

- [ ] **Step 3: Update layout constants for more playful feel**

```swift
    // MARK: Layout
    static let cornerRadius: CGFloat = 28       // was 24
    static let smallCornerRadius: CGFloat = 20  // was 16
    static let pillCornerRadius: CGFloat = 50
    static let padding: CGFloat = 20
    static let smallPadding: CGFloat = 12
    static let cardPadding: CGFloat = 18        // was 16
```

- [ ] **Step 4: Build to verify no compile errors**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`

- [ ] **Step 5: Commit**

```bash
git add TamaGoosie/Theme/GoosieTheme.swift
git commit -m "feat: update GoosieTheme to Golden Pond palette with playful typography"
```

---

### Task 2: Update GoosieComponents for Warmer Feel

**Files:**
- Modify: `TamaGoosie/Theme/GoosieComponents.swift`

- [ ] **Step 1: Update StatBar for thicker, bouncier bars**

Change the bar height from 10 to 12, and add a subtle warm shadow:

```swift
struct StatBar: View {
    let label: String
    let icon: String
    let value: Double // 0...100
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 22)

            Text(label)
                .font(GoosieTheme.captionFont())
                .foregroundStyle(GoosieTheme.charcoalOutline)
                .frame(width: 70, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.18))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * (value / 100)))
                        .shadow(color: color.opacity(0.3), radius: 4, y: 2)
                }
            }
            .frame(height: 12)

            Text("\(Int(value))")
                .font(GoosieTheme.captionFont(12))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                .frame(width: 28, alignment: .trailing)
        }
    }
}
```

- [ ] **Step 2: Update PillButton with warmer shadow**

```swift
struct PillButton: View {
    let title: String
    let icon: String
    let color: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(GoosieTheme.bodyFont(14))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(color, in: Capsule())
            .shadow(color: color.opacity(0.35), radius: 10, y: 5)
        }
    }
}
```

- [ ] **Step 3: Update CircleActionButton padding**

```swift
struct CircleActionButton: View {
    let icon: String
    let label: String
    let color: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(color, in: Circle())
                    .shadow(color: color.opacity(0.35), radius: 8, y: 4)

                Text(label)
                    .font(GoosieTheme.captionFont(11))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))
            }
        }
    }
}
```

- [ ] **Step 4: Update GoosieCard with warmer shadow and subtle border**

```swift
struct GoosieCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(GoosieTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: GoosieTheme.smallCornerRadius)
                    .fill(GoosieTheme.creamWhite)
                    .overlay(
                        RoundedRectangle(cornerRadius: GoosieTheme.smallCornerRadius)
                            .strokeBorder(GoosieTheme.charcoalOutline.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: GoosieTheme.warmOrange.opacity(0.08), radius: 12, y: 5)
            )
    }
}
```

- [ ] **Step 5: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`

- [ ] **Step 6: Commit**

```bash
git add TamaGoosie/Theme/GoosieComponents.swift
git commit -m "feat: update GoosieComponents with warmer shadows and playful sizing"
```

---

### Task 3: Fix ContentView Subpage Header & Side Menu

**Files:**
- Modify: `TamaGoosie/App/ContentView.swift`

- [ ] **Step 1: Update subpageHeaderColor to warm cream tint**

Replace lines 176-183 with:

```swift
    private static let subpageHeaderColor = Color(
        UIColor(
            red: 1.0 * 0.96 + 0.04 * 0.91,
            green: 0.96 * 0.96 + 0.04 * 0.59,
            blue: 0.90 * 0.96 + 0.04 * 0.23,
            alpha: 1
        )
    )
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/App/ContentView.swift
git commit -m "feat: update ContentView header color to warm cream"
```

---

### Task 4: Fix Chat Bubble Colors

**Files:**
- Modify: `TamaGoosie/Features/Goose/GooseChatPanel.swift`

- [ ] **Step 1: Update MessageBubble to use gooseBubble for bot responses**

In the `MessageBubble` struct (around line 228), change:

```swift
.fill(message.isUser ? GoosieTheme.coralAccent : GoosieTheme.gooseBubble)
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Goose/GooseChatPanel.swift
git commit -m "feat: use pond teal for goose chat bubbles"
```

---

### Task 5: Fix AccountCreationView "Available" Color

**Files:**
- Modify: `TamaGoosie/Features/Account/AccountCreationView.swift`

- [ ] **Step 1: Replace mintBackground with hygieneGreen for the "Available" indicator**

Lines 65-69: change `GoosieTheme.mintBackground` to `GoosieTheme.hygieneGreen`:

```swift
} else if viewModel.isAvailable {
    Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(GoosieTheme.hygieneGreen)
        .font(.system(size: 12))
    Text("Available!")
        .font(GoosieTheme.captionFont(12))
        .foregroundStyle(GoosieTheme.hygieneGreen)
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add TamaGoosie/Features/Account/AccountCreationView.swift
git commit -m "fix: use sage green for username availability indicator"
```

---

### Task 6: Final Build Verification

- [ ] **Step 1: Full clean build**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosie -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build 2>&1 | tail -10`

- [ ] **Step 2: Verify watchOS build**

Run: `xcodebuild -project TamaGoosie.xcodeproj -scheme TamaGoosieWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build 2>&1 | tail -5`
