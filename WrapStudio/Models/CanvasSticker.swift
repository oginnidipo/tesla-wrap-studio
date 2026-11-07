import Foundation

/// Positions and sizes are always in template pixels, independent of the device.
struct CanvasSticker: Identifiable, Codable, Equatable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    /// The longest edge of the sticker's square frame; the image keeps its aspect ratio.
    var side: CGFloat
    var fileName: String
    /// Clockwise, in radians, applied after `isFlipped`.
    var rotation: Double = 0
    /// Mirrored horizontally, before rotation.
    var isFlipped = false

    init(id: UUID, x: CGFloat, y: CGFloat, side: CGFloat, fileName: String,
         rotation: Double = 0, isFlipped: Bool = false) {
        self.id = id
        self.x = x
        self.y = y
        self.side = side
        self.fileName = fileName
        self.rotation = rotation
        self.isFlipped = isFlipped
    }

    // Stickers saved before rotation and flipping existed omit those keys.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        x = try container.decode(CGFloat.self, forKey: .x)
        y = try container.decode(CGFloat.self, forKey: .y)
        side = try container.decode(CGFloat.self, forKey: .side)
        fileName = try container.decode(String.self, forKey: .fileName)
        rotation = try container.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        isFlipped = try container.decodeIfPresent(Bool.self, forKey: .isFlipped) ?? false
    }
}
