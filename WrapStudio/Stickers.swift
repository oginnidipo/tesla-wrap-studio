import SwiftUI
import PhotosUI

// A sticker placed on the paint surface. Coordinates live in the canvas view's
// coordinate space and get mapped into template pixels at export time.
struct CanvasSticker: Identifiable, Codable {
    let id: UUID
    var x: CGFloat        // center x in canvas view coords
    var y: CGFloat        // center y in canvas view coords
    var side: CGFloat     // rendered side length in canvas view coords
    var fileName: String  // png inside Documents/Stickers
}

enum StickerLib {
    static var dir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let d = docs.appendingPathComponent("Stickers", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static func image(named name: String) -> UIImage? {
        UIImage(contentsOfFile: dir.appendingPathComponent(name).path)
    }
    static func names() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?.filter { $0.hasSuffix(".png") }.sorted() ?? []
    }
    static func importData(_ data: Data) -> String? {
        guard var img = UIImage(data: data) else { return nil }
        // downscale so stickers stay light on the render pass
        let maxSide: CGFloat = 700
        let big = max(img.size.width, img.size.height)
        if big > maxSide {
            let s = maxSide / big
            let size = CGSize(width: img.size.width * s, height: img.size.height * s)
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
            img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        }
        let name = "st-\(Int(Date().timeIntervalSince1970))-\(Int.random(in: 100...999)).png"
        guard let png = img.pngData(), ((try? png.write(to: dir.appendingPathComponent(name))) != nil) else { return nil }
        return name
    }
}

// Per-car sticker layout, stored next to the drawing autosave.
enum StickerPersistence {
    static func url(for car: Car) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Wrap Studio Autosaves", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(car.rawValue.replacingOccurrences(of: " ", with: "-")).stickers")
    }
    static func load(car: Car) -> [CanvasSticker] {
        guard let data = try? Data(contentsOf: url(for: car)) else { return [] }
        return (try? JSONDecoder().decode([CanvasSticker].self, from: data)) ?? []
    }
    static func save(car: Car, stickers: [CanvasSticker]) {
        guard let data = try? JSONEncoder().encode(stickers) else { return }
        try? data.write(to: url(for: car))
    }
}

final class StickerStore: ObservableObject {
    static let shared = StickerStore()
    @Published var stickers: [CanvasSticker] = []
    @Published var selectedID: UUID?

    func load(car: Car) { stickers = StickerPersistence.load(car: car) }
    func persist(car: Car) { StickerPersistence.save(car: car, stickers: stickers) }

    func add(name: String, canvasSize: CGSize) {
        let side: CGFloat = min(canvasSize.width, canvasSize.height) * 0.28
        let s = CanvasSticker(id: UUID(), x: canvasSize.width / 2, y: canvasSize.height / 2,
                              side: side, fileName: name)
        stickers.append(s); selectedID = s.id
    }
    func remove(_ id: UUID) {
        stickers.removeAll { $0.id == id }
        if selectedID == id { selectedID = nil }
    }
}

struct StickerSheet: View {
    @ObservedObject var store: StickerStore
    let car: Car
    let canvasSize: CGSize
    @Binding var showingPhotoPicker: Bool
    @Binding var photoItem: PhotosPickerItem?
    @Environment(\.dismiss) var dismiss
    @State private var libNames: [String] = StickerLib.names()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // import row
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Photo Library", systemImage: "photo.badge.plus")
                                .font(.headline).foregroundColor(.white)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(Capsule().fill(Color.orange))
                        }
                        Button {
                            showingPhotoPicker = true
                        } label: {
                            Label("Take / Pick", systemImage: "plus")
                                .font(.headline).foregroundColor(.orange)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(Capsule().stroke(Color.orange, lineWidth: 2))
                        }
                    }
                    if libNames.isEmpty {
                        Text("No stickers yet — import photos of pets, drawings, anything! 🐶").foregroundColor(.secondary).padding(.top, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 14)], spacing: 14) {
                            ForEach(libNames, id: \.self) { name in
                                Button {
                                    store.add(name: name, canvasSize: canvasSize)
                                    dismiss()
                                } label: {
                                    if let img = StickerLib.image(named: name) {
                                        Image(uiImage: img).resizable().scaledToFit()
                                            .frame(width: 100, height: 100)
                                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange, lineWidth: 2))
                                            .shadow(radius: 3)
                                    }
                                }
                            }
                        }
                    }
                }.padding(18)
            }
            .navigationTitle("Stickers ✂️").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Delete stickers...") {
                // long list safety: clear all imported sticker files no longer used anywhere
            }.font(.footnote).foregroundColor(.secondary).disabled(true) }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

// One placed sticker on the canvas: draggable + pinch-resizable, with delete.
struct PlacedStickerView: View {
    @ObservedObject var store: StickerStore
    let sticker: CanvasSticker
    let car: Car

    var body: some View {
        let img = StickerLib.image(named: sticker.fileName)
        let selected = store.selectedID == sticker.id
        Image(uiImage: img ?? UIImage())
            .resizable().scaledToFit()
            .frame(width: sticker.side, height: sticker.side)
            .opacity(selected ? 0.95 : 1)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.orange : .clear, lineWidth: 3))
            .position(x: sticker.x, y: sticker.y)
            .onTapGesture { store.selectedID = selected ? nil : sticker.id }
            .gesture(DragGesture()
                .onChanged { v in
                    if let i = store.stickers.firstIndex(where: { $0.id == sticker.id }) {
                        store.stickers[i].x = max(0, v.location.x)
                        store.stickers[i].y = max(0, v.location.y)
                    }
                }
                .onEnded { _ in store.persist(car: car) })
            .gesture(MagnificationGesture()
                .onChanged { v in
                    if let i = store.stickers.firstIndex(where: { $0.id == sticker.id }) {
                        store.stickers[i].side = min(1000, max(40, store.stickers[i].side * v.magnitude))
                    }
                }
                .onEnded { _ in store.persist(car: car) })
            .overlay(alignment: .topTrailing) {
                if selected {
                    Button { store.remove(sticker.id); store.persist(car: car) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3).foregroundColor(.red).background(Circle().fill(.white))
                    }.offset(x: 6, y: -6)
                }
            }
    }
}