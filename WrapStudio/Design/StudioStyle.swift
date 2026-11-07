import SwiftUI
import UIKit

enum StudioStyle {
    static let accent = Color(red: 0.78, green: 0.20, blue: 0.12)

    struct Swatch: Identifiable, Hashable {
        let hex: String
        let name: String
        var id: String { hex }
    }

    /// Ordered for scanning: neutrals, then warm to cool.
    static let swatches: [Swatch] = [
        Swatch(hex: "FFFFFF", name: "White"),
        Swatch(hex: "C9CDD3", name: "Silver"),
        Swatch(hex: "7D838C", name: "Graphite"),
        Swatch(hex: "25282D", name: "Charcoal"),
        Swatch(hex: "0B0B0D", name: "Black"),
        Swatch(hex: "B3121F", name: "Crimson"),
        Swatch(hex: "F14B35", name: "Coral"),
        Swatch(hex: "FF7A1A", name: "Orange"),
        Swatch(hex: "FFB547", name: "Amber"),
        Swatch(hex: "F6D968", name: "Yellow"),
        Swatch(hex: "A6D96A", name: "Lime"),
        Swatch(hex: "5AAB88", name: "Green"),
        Swatch(hex: "1F6F5C", name: "Forest"),
        Swatch(hex: "4FC3D9", name: "Cyan"),
        Swatch(hex: "558BC7", name: "Blue"),
        Swatch(hex: "1E3A8A", name: "Navy"),
        Swatch(hex: "9675C7", name: "Purple"),
        Swatch(hex: "F3A6BF", name: "Pink"),
    ]

    static let palette = swatches.map(\.hex)
    static let defaultInkHex = "F14B35"

    static func color(hex: String) -> Color { Color(uiColor: uiColor(hex: hex)) }

    static func uiColor(hex: String) -> UIColor {
        let value = UInt32(hex, radix: 16) ?? 0
        return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    /// Six uppercase hex digits in sRGB, the format stored in designs.
    static func hex(from color: UIColor) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let srgb = color.cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)
        if let components = srgb?.components, components.count >= 3 {
            (red, green, blue) = (components[0], components[1], components[2])
        } else {
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        }
        func channel(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X", channel(red), channel(green), channel(blue))
    }

    static func name(forHex hex: String) -> String {
        swatches.first { $0.hex == hex }?.name ?? "Custom color"
    }

    /// Whether white reads better than black on top of this colour.
    static func prefersLightContent(onHex hex: String) -> Bool {
        let value = UInt32(hex, radix: 16) ?? 0
        let red = Double((value >> 16) & 255), green = Double((value >> 8) & 255), blue = Double(value & 255)
        return (0.299 * red + 0.587 * green + 0.114 * blue) < 160
    }
}

@MainActor enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
