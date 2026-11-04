import SwiftUI

enum StudioStyle {
    static let accent = Color(red: 0.78, green: 0.20, blue: 0.12)
    static let palette = ["F14B35", "FFB547", "F6D968", "5AAB88", "558BC7", "9675C7", "F3A6BF", "25282D"]

    static func color(hex: String) -> Color {
        let value = UInt32(hex, radix: 16) ?? 0
        return Color(red: Double((value >> 16) & 255) / 255,
                     green: Double((value >> 8) & 255) / 255,
                     blue: Double(value & 255) / 255)
    }
}
