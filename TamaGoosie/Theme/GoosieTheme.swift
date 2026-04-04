import SwiftUI

// MARK: - Design Tokens

enum GoosieTheme {
    // MARK: Colors
    static let mintBackground = Color(hex: 0xB8E8D0)
    static let creamWhite = Color(hex: 0xFFF8F0)
    static let coralAccent = Color(hex: 0xFF8B7E)
    static let sunYellow = Color(hex: 0xFFD93D)
    static let warmOrange = Color(hex: 0xFFA652)
    static let softPink = Color(hex: 0xFFD1DC)
    static let charcoalOutline = Color(hex: 0x2D2D2D)
    static let skyBlue = Color(hex: 0xA8D8EA)

    // MARK: Stat Colors
    static let healthRed = Color(hex: 0xFF6B6B)
    static let happinessYellow = Color(hex: 0xFFD93D)
    static let energyBlue = Color(hex: 0x6BC5F0)
    static let hygieneGreen = Color(hex: 0x7ED6A5)

    // MARK: Typography
    static func titleFont(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func bodyFont(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func captionFont(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    // MARK: Layout
    static let cornerRadius: CGFloat = 24
    static let smallCornerRadius: CGFloat = 16
    static let pillCornerRadius: CGFloat = 50
    static let padding: CGFloat = 20
    static let smallPadding: CGFloat = 12
    static let cardPadding: CGFloat = 16
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
