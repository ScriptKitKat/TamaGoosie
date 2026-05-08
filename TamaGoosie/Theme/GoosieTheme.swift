import SwiftUI

// MARK: - Design Tokens

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

    // MARK: Layout
    static let cornerRadius: CGFloat = 28       // was 24
    static let smallCornerRadius: CGFloat = 20  // was 16
    static let pillCornerRadius: CGFloat = 50
    static let padding: CGFloat = 20
    static let smallPadding: CGFloat = 12
    static let cardPadding: CGFloat = 18        // was 16
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
