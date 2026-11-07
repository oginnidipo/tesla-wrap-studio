import Foundation
import PencilKit

/// Saved designs, one folder per design:
/// `Designs/<id>/record.json` (name, vehicle, dates), `design.json` (artwork) and
/// `thumbnail.png`. Writes are atomic per file; the artwork is written before its record.
struct DesignStore {
    let documentsURL: URL

    init(documentsURL: URL = URL.documentsDirectory) {
        self.documentsURL = documentsURL
    }

    var designsDirectory: URL { documentsURL.appending(path: "Designs", directoryHint: .isDirectory) }
    /// Version 1.3 kept one draft per vehicle here. Those files are imported, never modified.
    var legacyAutosaveDirectory: URL { documentsURL.appending(path: "Wrap Studio Autosaves", directoryHint: .isDirectory) }
    private var importMarkerURL: URL { designsDirectory.appending(path: ".imported-autosaves.json") }

    func folder(for id: UUID) -> URL { designsDirectory.appending(path: id.uuidString, directoryHint: .isDirectory) }
    func recordURL(for id: UUID) -> URL { folder(for: id).appending(path: "record.json") }
    func designURL(for id: UUID) -> URL { folder(for: id).appending(path: "design.json") }
    func thumbnailURL(for id: UUID) -> URL { folder(for: id).appending(path: "thumbnail.png") }

    // MARK: Reading

    /// Every readable design, most recently edited first.
    func records() -> [DesignRecord] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: designsDirectory, includingPropertiesForKeys: nil,
                                                                     options: .skipsHiddenFiles)) ?? []
        return folders.compactMap { folder in
            guard let id = UUID(uuidString: folder.lastPathComponent) else { return nil }
            return try? record(id)
        }
        .sorted { $0.modifiedAt == $1.modifiedAt ? $0.createdAt > $1.createdAt : $0.modifiedAt > $1.modifiedAt }
    }

    func record(_ id: UUID) throws -> DesignRecord {
        guard FileManager.default.fileExists(atPath: recordURL(for: id).path) else { throw StudioError.designNotFound }
        return try Self.decoder.decode(DesignRecord.self, from: Data(contentsOf: recordURL(for: id)))
    }

    func loadDesign(_ id: UUID) throws -> WrapDesign {
        let url = designURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return WrapDesign() }
        let design = try Self.decoder.decode(WrapDesign.self, from: Data(contentsOf: url))
        guard (1...WrapDesign.currentVersion).contains(design.version) else { throw StudioError.unsupportedDesign }
        _ = try PKDrawing(data: design.drawingData)
        return design
    }

    // MARK: Writing

    @discardableResult
    func create(car: Car, name: String? = nil, design: WrapDesign = WrapDesign(), date: Date = .now,
                needsCanvasMigration: Bool = false) throws -> DesignRecord {
        let record = DesignRecord(car: car, name: uniqueName(name.map(DesignRecord.cleanedName) ?? defaultName(for: car)),
                                  createdAt: date, needsCanvasMigration: needsCanvasMigration)
        try FileManager.default.createDirectory(at: folder(for: record.id), withIntermediateDirectories: true)
        try Self.encoder.encode(design).write(to: designURL(for: record.id), options: .atomic)
        try saveRecord(record)
        return record
    }

    /// Saves artwork and returns the record with its new modification date.
    @discardableResult
    func save(_ design: WrapDesign, for record: DesignRecord, at date: Date = .now) throws -> DesignRecord {
        var updated = record
        updated.modifiedAt = date
        try FileManager.default.createDirectory(at: folder(for: record.id), withIntermediateDirectories: true)
        try Self.encoder.encode(design).write(to: designURL(for: record.id), options: .atomic)
        try saveRecord(updated)
        return updated
    }

    func saveRecord(_ record: DesignRecord) throws {
        try FileManager.default.createDirectory(at: folder(for: record.id), withIntermediateDirectories: true)
        try Self.encoder.encode(record).write(to: recordURL(for: record.id), options: .atomic)
    }

    /// A thumbnail missing, or older than the design's last save (e.g. the app was killed
    /// with the editor open), needs to be rendered again.
    func thumbnailIsCurrent(for record: DesignRecord) -> Bool {
        let url = thumbnailURL(for: record.id)
        guard let written = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        else { return false }
        return written >= record.modifiedAt
    }

    func saveThumbnail(_ png: Data, for id: UUID) throws {
        guard FileManager.default.fileExists(atPath: folder(for: id).path) else { throw StudioError.designNotFound }
        try png.write(to: thumbnailURL(for: id), options: .atomic)
    }

    @discardableResult
    func rename(_ id: UUID, to name: String) throws -> DesignRecord {
        var updated = try record(id)
        let cleaned = DesignRecord.cleanedName(name)
        guard !cleaned.isEmpty, cleaned != updated.name else { return updated }
        updated.name = uniqueName(cleaned, excluding: id)
        try saveRecord(updated)
        return updated
    }

    /// Copies the artwork byte for byte, so even a draft that cannot be opened is preserved.
    @discardableResult
    func duplicate(_ id: UUID, at date: Date = .now) throws -> DesignRecord {
        let original = try record(id)
        var copy = DesignRecord(car: original.car, name: uniqueName("\(original.name) copy"), createdAt: date,
                                needsCanvasMigration: original.needsCanvasMigration)
        copy.modifiedAt = date
        try FileManager.default.createDirectory(at: folder(for: copy.id), withIntermediateDirectories: true)
        for (source, destination) in [(designURL(for: id), designURL(for: copy.id)),
                                      (thumbnailURL(for: id), thumbnailURL(for: copy.id))]
        where FileManager.default.fileExists(atPath: source.path) {
            try FileManager.default.copyItem(at: source, to: destination)
        }
        try saveRecord(copy)
        return copy
    }

    func delete(_ id: UUID) throws {
        let folder = folder(for: id)
        guard FileManager.default.fileExists(atPath: folder.path) else { return }
        try FileManager.default.removeItem(at: folder)
    }

    // MARK: Names

    func defaultName(for car: Car) -> String { "\(car.name) Wrap" }

    /// Appends a number when another design already uses the name (case-insensitively).
    func uniqueName(_ base: String, excluding id: UUID? = nil) -> String {
        let trimmed = DesignRecord.cleanedName(base)
        let start = trimmed.isEmpty ? "Untitled Wrap" : trimmed
        let taken = Set(records().filter { $0.id != id }.map { $0.name.lowercased() })
        guard taken.contains(start.lowercased()) else { return start }
        for number in 2... {
            let suffix = " \(number)"
            let candidate = String(start.prefix(DesignRecord.maximumNameLength - suffix.count)) + suffix
            if !taken.contains(candidate.lowercased()) { return candidate }
        }
        return start
    }

    // MARK: Importing earlier versions

    /// Turns version 1.3 autosaves and prototype drafts into designs, once per vehicle.
    /// Original files are read but never changed or removed.
    @discardableResult
    func importLegacyAutosaves() throws -> [DesignRecord] {
        var imported = Set((try? Self.decoder.decode([String].self, from: Data(contentsOf: importMarkerURL))) ?? [])
        var created: [DesignRecord] = []
        for car in Car.allCases where car.legacyFileName != nil && !imported.contains(car.rawValue) {
            let autosave = legacyAutosaveDirectory.appending(path: "\(car.rawValue).wrap.json")
            if FileManager.default.fileExists(atPath: autosave.path) {
                let data = try Data(contentsOf: autosave)
                // An empty draft is not worth a gallery entry; an unreadable one is kept so the
                // editor can explain the problem instead of losing it silently.
                let decoded = try? Self.decoder.decode(WrapDesign.self, from: data)
                if decoded?.hasArtwork != false {
                    let date = (try? autosave.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .now
                    var record = try create(car: car, name: defaultName(for: car), date: date)
                    try data.write(to: designURL(for: record.id), options: .atomic)
                    record.modifiedAt = date
                    try saveRecord(record)
                    created.append(record)
                }
            } else if let legacy = try? legacyPrototypeDesign(for: car) {
                created.append(try create(car: car, name: defaultName(for: car), design: legacy,
                                          needsCanvasMigration: true))
            }
            imported.insert(car.rawValue)
        }
        try FileManager.default.createDirectory(at: designsDirectory, withIntermediateDirectories: true)
        try Self.encoder.encode(imported.sorted()).write(to: importMarkerURL, options: .atomic)
        return created
    }

    private func legacyPrototypeDesign(for car: Car) throws -> WrapDesign? {
        guard let name = car.legacyFileName else { return nil }
        let drawingURL = legacyAutosaveDirectory.appending(path: "\(name).wrapdata")
        let stickersURL = legacyAutosaveDirectory.appending(path: "\(name).stickers")
        let hasDrawing = FileManager.default.fileExists(atPath: drawingURL.path)
        let hasStickers = FileManager.default.fileExists(atPath: stickersURL.path)
        guard hasDrawing || hasStickers else { return nil }
        let drawing = hasDrawing ? try PKDrawing(data: Data(contentsOf: drawingURL)) : PKDrawing()
        let stickers = hasStickers ? try JSONDecoder().decode([CanvasSticker].self, from: Data(contentsOf: stickersURL)) : []
        return WrapDesign(drawing: drawing, stickers: stickers)
    }

    // Dates use Foundation's default encoding so they round-trip exactly.
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder { JSONDecoder() }
}
