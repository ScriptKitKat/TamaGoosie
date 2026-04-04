import SwiftUI

// MARK: - Watch Design Tokens

enum WatchTheme {
    // Backgrounds
    static let cream  = Color(hex: 0xFFF8F0)
    static let card   = Color(hex: 0xF5EFE6)
    static let border = Color(hex: 0xE8E0D4)

    // Text
    static let text          = Color(hex: 0x4A3728)
    static let textSecondary = Color(hex: 0xA09080)

    // Accent
    static let teal    = Color(hex: 0x7ECBC4)
    static let coral   = Color(hex: 0xF4A683)
    static let yellow  = Color(hex: 0xFFD97A)
    static let lavender = Color(hex: 0xB4A8E8)

    // Stat row accents (match HTML exactly)
    static let stepsBlue        = Color(hex: 0x378ADD)
    static let sleepPurple      = Color(hex: 0x9B8FD9)
    static let sleepPurpleDark  = Color(hex: 0x534AB7)
    static let exerciseDark     = Color(hex: 0xD85A30)
    static let standDark        = Color(hex: 0x0F6E56)
}

// MARK: - Color Hex Extension (Watch target — mirrors GoosieTheme.swift for iOS)

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8)  & 0xFF) / 255.0,
            blue:  Double(hex & 0xFF)          / 255.0,
            opacity: alpha
        )
    }
}
