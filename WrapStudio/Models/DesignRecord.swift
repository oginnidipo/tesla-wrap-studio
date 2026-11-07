import Foundation

/// Everything the gallery needs to list a design without opening its artwork.
struct DesignRecord: Codable, Identifiable, Hashable {
    let id: UUID
    var car: Car
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    /// Drafts from the prototype stored on-screen coordinates; they are converted to
    /// template coordinates the first time the editor lays out the canvas.
    var needsCanvasMigration = false

    init(id: UUID = UUID(), car: Car, name: String, createdAt: Date = .now, modifiedAt: Date? = nil,
         needsCanvasMigration: Bool = false) {
        self.id = id
        self.car = car
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
        self.needsCanvasMigration = needsCanvasMigration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        car = try container.decode(Car.self, forKey: .car)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        needsCanvasMigration = try container.decodeIfPresent(Bool.self, forKey: .needsCanvasMigration) ?? false
    }

    static let maximumNameLength = 40

    static func cleanedName(_ name: String) -> String {
        let collapsed = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(collapsed.prefix(maximumNameLength))
    }
}
