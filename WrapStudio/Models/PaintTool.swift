import PencilKit

enum PaintTool: String, CaseIterable, Identifiable {
    case pen, marker, eraser

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .pen: "pencil.tip"
        case .marker: "highlighter"
        case .eraser: "eraser"
        }
    }
}
