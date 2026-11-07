import Combine
import SwiftUI

/// The gallery's view of saved designs. Editors report saves and thumbnails back here,
/// so returning to the gallery never needs to re-read every design from disk.
@MainActor final class DesignLibrary: ObservableObject {
    @Published private(set) var records: [DesignRecord] = []
    @Published private(set) var thumbnails: [UUID: UIImage] = [:]
    @Published var errorMessage: String?
    @Published private(set) var hasLoaded = false

    let store: DesignStore
    /// Designs created in this run that have not been given any artwork yet.
    private var untouched: Set<UUID> = []

    init(store: DesignStore = DesignStore()) {
        self.store = store
    }

    func load() async {
        if !hasLoaded {
            do { try store.importLegacyAutosaves() }
            catch { errorMessage = "Some earlier drafts could not be imported. Their files have been kept. \(error.localizedDescription)" }
        }
        records = store.records()
        hasLoaded = true
        // Show the gallery first; fill in thumbnails one frame at a time.
        for record in records where thumbnails[record.id] == nil {
            await Task.yield()
            loadThumbnail(for: record)
        }
    }

    func create(car: Car) -> DesignRecord? {
        do {
            let record = try store.create(car: car)
            records.insert(record, at: 0)
            untouched.insert(record.id)
            return record
        } catch {
            errorMessage = "A new design could not be created. \(error.localizedDescription)"
            return nil
        }
    }

    func rename(_ record: DesignRecord, to name: String) {
        do { update(try store.rename(record.id, to: name)) }
        catch { errorMessage = "This design could not be renamed. \(error.localizedDescription)" }
    }

    func duplicate(_ record: DesignRecord) {
        do {
            let copy = try store.duplicate(record.id)
            records.insert(copy, at: 0)
            if let thumbnail = thumbnails[record.id] { thumbnails[copy.id] = thumbnail }
        } catch {
            errorMessage = "This design could not be duplicated. \(error.localizedDescription)"
        }
    }

    func delete(_ record: DesignRecord) {
        do {
            try store.delete(record.id)
            records.removeAll { $0.id == record.id }
            thumbnails[record.id] = nil
            untouched.remove(record.id)
        } catch {
            errorMessage = "This design could not be deleted. \(error.localizedDescription)"
        }
    }

    /// Leaving a brand-new design without drawing anything removes it, the way an empty
    /// note disappears, so browsing vehicles never clutters the gallery.
    func editorClosed(_ record: DesignRecord, hasArtwork: Bool) {
        guard untouched.contains(record.id) else { return }
        if hasArtwork { untouched.remove(record.id) } else { delete(record) }
    }

    func update(_ record: DesignRecord) {
        records.removeAll { $0.id == record.id }
        let index = records.firstIndex { $0.modifiedAt < record.modifiedAt } ?? records.endIndex
        records.insert(record, at: index)
    }

    func updateThumbnail(_ png: Data, for id: UUID) {
        thumbnails[id] = UIImage(data: png)
    }

    private func loadThumbnail(for record: DesignRecord) {
        let saved = UIImage(contentsOfFile: store.thumbnailURL(for: record.id).path)
        thumbnails[record.id] = saved
        if saved != nil, store.thumbnailIsCurrent(for: record) { return }
        // Imported drafts have no thumbnail yet; others may be older than their artwork.
        guard !record.needsCanvasMigration,
              let design = try? store.loadDesign(record.id),
              let png = try? WrapRenderer.thumbnail(car: record.car, design: design,
                                                    library: StickerLibrary(documentsURL: store.documentsURL)) else { return }
        try? store.saveThumbnail(png, for: record.id)
        thumbnails[record.id] = UIImage(data: png)
    }
}
