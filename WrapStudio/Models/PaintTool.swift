import Foundation

enum PaintTool: String, CaseIterable, Identifiable {
    case pen, marker, eraser, fill

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .pen: "pencil.tip"
        case .marker: "highlighter"
        case .eraser: "eraser"
        case .fill: "drop.fill"
        }
    }
    /// Hardware-keyboard shortcut on iPad.
    var key: Character {
        switch self {
        case .pen: "p"
        case .marker: "m"
        case .eraser: "e"
        case .fill: "f"
        }
    }
    var drawsInk: Bool { self == .pen || self == .marker }
    var usesWidth: Bool { self != .fill }
}
