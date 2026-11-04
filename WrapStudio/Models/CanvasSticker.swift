import Foundation

/// Positions and sizes are always in template pixels, independent of the device.
struct CanvasSticker: Identifiable, Codable, Equatable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var side: CGFloat
    var fileName: String
}
