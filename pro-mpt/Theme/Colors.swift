import SwiftUI

// MARK: - pro-mpt カラートークン (ダークモード専用)

enum AppColors {
    static let bgDeep = Color(hex: 0x020203)
    static let bgBase = Color(hex: 0x050506)
    static let bgElevated = Color(hex: 0x0A0A0C)

    static let surface = Color.white.opacity(0.05)
    static let surfaceHover = Color.white.opacity(0.08)
    static let surfaceSelected = Color.white.opacity(0.10)

    static let accent = Color(hex: 0x5E6AD2)
    static let accentGlow = Color(hex: 0x5E6AD2).opacity(0.2)
    static let accentSubtle = Color(hex: 0x5E6AD2).opacity(0.1)

    static let textPrimary = Color(hex: 0xEDEDEF)
    static let textSecondary = Color(hex: 0x8A8F98)
    static let textTertiary = Color(hex: 0x555962)

    static let border = Color.white.opacity(0.08)
    static let borderSubtle = Color.white.opacity(0.04)
    static let borderFocus = Color(hex: 0x5E6AD2).opacity(0.3)

    static let success = Color(hex: 0x34D399)
    static let warning = Color(hex: 0xFBBF24)
    static let error = Color(hex: 0xEF4444)
    static let favorite = Color(hex: 0xF59E0B)

    static let overlayBackground = Color(hex: 0x020203).opacity(0.75)
}

// MARK: - Hex カラー拡張

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
