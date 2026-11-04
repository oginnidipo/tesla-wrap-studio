import SwiftUI
import PhotosUI
import PencilKit

struct CanvasView: View {
    let car: Car
    let onClose: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showingExport = false
    @State private var lastDesign: UIImage?
    @State private var savedFiles: [String] = ExportPanel.savedFileNames()
    @State private var stickerNudge = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { Store.persistCurrentDrawing(car: car); onClose() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward").font(.title3.bold())
                        Text("Cars").font(.subheadline.bold())
                    }.foregroundColor(.primary)
                }.buttonStyle(.plain)
                Spacer()
                Text("\(car.emoji) \(car.rawValue)").font(.headline)
                Spacer()
                Button {
                    if let img = Render.export(car: car) { lastDesign = img; showingExport = true }
                } label: {
                    Text("Save ✨").font(.headline.weight(.bold)).foregroundColor(.white)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Capsule().fill(Color.orange))
                }.buttonStyle(.plain).disabled(Render.isCanvasEmpty())
            }.padding(.horizontal, 18).padding(.top, 10)

            HStack(spacing: 10) {
                Label("Add Sticker", systemImage: "photo.badge.plus")
                    .font(.subheadline.bold()).foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color.purple))
            }
            .onTapGesture { NotificationCenter.default.post(name: .openStickers, object: nil) }
            .padding(.bottom, 2)

            PaintCanvas(car: car)
                .frame(maxHeight: .infinity)

            Text("Paint the white car! Keep the dark windows. 🖍️")
                .font(.footnote).foregroundColor(.secondary).padding(.vertical, 8)
        }
        .sheet(isPresented: $showingExport) {
            ExportPanel(car: car, image: lastDesign, savedFiles: $savedFiles)
        }
    }
}

// Global canvas so the tool picker / undo survive view refreshes
final class Store {
    static let canvas = PKCanvasView()
    // One picker per app lifetime; recreated pickers stop driving the canvas.
    static let toolPicker = PKToolPicker()

    static var fitRect: CGRect = .zero
    static var lastFitRect: CGRect = .zero
    static var isLoadingDrawing = false
    static func persistCurrentDrawing(car: Car) {
        guard !isLoadingDrawing else { return }
        save(car: car)
    }

    static func focus() {
        canvas.becomeFirstResponder()
        toolPicker.setVisible(true, forFirstResponder: canvas)
    }

    static func autosaveURL(for car: Car) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Wrap Studio Autosaves", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(car.rawValue.replacingOccurrences(of: " ", with: "-")).wrapdata")
    }
    static func load(car: Car) -> PKDrawing? {
        guard let data = try? Data(contentsOf: autosaveURL(for: car)) else { return nil }
        return try? PKDrawing(data: data)
    }
    static func save(car: Car) {
        guard !isLoadingDrawing else { return }
        try? canvas.drawing.dataRepresentation().write(to: autosaveURL(for: car))
    }
    static func isCanvasEmpty() -> Bool { canvas.drawing.bounds.isEmpty }
}

struct PaintCanvas: View {
    let car: Car
    @StateObject private var stickerStore = StickerStore.shared
    @State private var showingStickerSheet = false
    @State private var showingPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TemplatePaintSurface(car: car)
                // placed stickers (canvas-view coordinates; exported via same mapping as strokes)
                ForEach(stickerStore.stickers) { s in
                    PlacedStickerView(store: stickerStore, sticker: s, car: car)
                }
            }
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 16) {
                    Button { stickerStore.selectedID = nil; Store.canvas.undoManager?.undo() } label: {
                        Image(systemName: "arrow.uturn.backward.circle.fill").font(.system(size: 40))
                            .foregroundStyle(.white, .orange).shadow(radius: 2)
                    }
                    Button { showingStickerSheet = true } label: {
                        Image(systemName: "photo.on.rectangle.angled.circle.fill").font(.system(size: 40))
                            .foregroundStyle(.white, .purple).shadow(radius: 2)
                    }
                    Button { stickerStore.selectedID = nil; Store.canvas.drawing = PKDrawing()
                             stickerStore.stickers = []; stickerStore.persist(car: car) } label: {
                        Image(systemName: "trash.circle.fill").font(.system(size: 40))
                            .foregroundStyle(.white, .red).shadow(radius: 2)
                    }
                }.padding(16)
            }
            .sheet(isPresented: $showingStickerSheet) {
                StickerSheet(store: stickerStore, car: car, canvasSize: geo.size,
                             showingPhotoPicker: $showingPhotoPicker, photoItem: $photoItem)
            }
            .onChange(of: photoItem) { item in
                guard let item else { return }
                showingPhotoPicker = false
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        if let name = StickerLib.importData(data) {
                            stickerStore.add(name: name, canvasSize: geo.size)
                        }
                    }
                    photoItem = nil
                }
            }
            .onAppear { stickerStore.load(car: car) }
            .onReceive(NotificationCenter.default.publisher(for: .openStickers)) { _ in showingStickerSheet = true }
            .onDisappear { stickerStore.persist(car: car) }
        }
    }
}

struct TemplatePaintSurface: UIViewRepresentable {
    let car: Car

    func makeUIView(context: Context) -> UIView {
        let host = TemplateHostView()
        host.car = car
        host.backgroundColor = .white
        host.layer.cornerRadius = 14
        host.clipsToBounds = true

        let canvas = Store.canvas
        canvas.overrideUserInterfaceStyle = .light
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        host.canvas = canvas
        host.addSubview(canvas)

        let overlay = UIImageView(image: RenderMask.overlay(car: car))
        overlay.contentMode = .scaleToFill
        overlay.isUserInteractionEnabled = false
        host.overlay = overlay
        host.addSubview(overlay)

        host.setNeedsLayout()
        DispatchQueue.main.async {
            Store.toolPicker.addObserver(canvas)
            Store.focus()
        }
        return host
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? TemplateHostView)?.refreshIfNeeded()
        Store.focus()
    }
    func makeCoordinator() -> Coordinator { Coordinator(car: car) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let car: Car
        init(car: Car) { self.car = car }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { Store.save(car: car) }
    }
}

// Owns the paint geometry. Lays out template + canvas + overlay inside the
// template's aspect-fit rect once the view actually has a size.
final class TemplateHostView: UIView {
    var car: Car?
    var canvas: PKCanvasView?
    var overlay: UIImageView?
    private let tplView = UIImageView()
    private var lastSize: CGSize = .zero
    private var configuredCar: Car?

    override init(frame: CGRect) {
        super.init(frame: frame)
        tplView.contentMode = .scaleToFill
        tplView.isUserInteractionEnabled = false
        addSubview(tplView)
    }
    required init?(coder: NSCoder) { fatalError("no") }

    func refreshIfNeeded() { setNeedsLayout(); layoutIfNeeded() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 10, let car else { return }
        let tplSize = car.tplSize
        let scale = min(bounds.width / tplSize.width, bounds.height / tplSize.height)
        let fit = CGSize(width: tplSize.width * scale, height: tplSize.height * scale)
        let fitRect = CGRect(origin: CGPoint(x: (bounds.width - fit.width) / 2,
                                             y: (bounds.height - fit.height) / 2), size: fit)

        if configuredCar != car {
            configuredCar = car
            tplView.image = UIImage(named: car.template)
            Store.lastFitRect = Store.fitRect.width > 0 ? Store.fitRect : fitRect
            if let canvas {
                Store.isLoadingDrawing = true
                canvas.drawing = RenderMask.rescale(Store.load(car: car) ?? PKDrawing(), from: Store.lastFitRect, to: fitRect)
                Store.isLoadingDrawing = false
            }
        }
        Store.fitRect = fitRect

        tplView.frame = fitRect
        canvas?.frame = fitRect
        overlay?.frame = fitRect
        // overlay must sit above canvas visually but never block touches
        overlay?.layer.zPosition = 10
        canvas?.layer.zPosition = 5
        tplView.layer.zPosition = 1
    }
}

extension Notification.Name { static let openStickers = Notification.Name("openStickers") }

enum Render {
    static func isCanvasEmpty() -> Bool { Store.canvas.drawing.bounds.isEmpty }

    /// Composites strokes (mapped display→template pixels) over the official template at exact Tesla size.
    static func export(car: Car) -> UIImage? {
        let canvas = Store.canvas
        let drawing = canvas.drawing
        guard !drawing.bounds.isEmpty else { return nil }

        let fitRect = Store.fitRect
        guard fitRect.width > 50 else { return nil }
        let tplSize = car.tplSize

        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1; fmt.opaque = true
        let renderer = UIGraphicsImageRenderer(size: tplSize, format: fmt)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: tplSize))
            if let carImg = UIImage(named: car.template) { carImg.draw(in: CGRect(origin: .zero, size: tplSize)) }
            let strokeScale = tplSize.width / fitRect.width
            let strokes = drawing.image(from: fitRect, scale: strokeScale)
            let maskedStrokes = RenderMask.maskedToPaintable(strokes, car: car)
            maskedStrokes.draw(in: CGRect(origin: .zero, size: tplSize))
            // stickers: same mapping (canvas view coords -> template pixels)
            for sticker in StickerStore.shared.stickers {
                guard let img = StickerLib.image(named: sticker.fileName) else { continue }
                let side = sticker.side * strokeScale
                let cx = (sticker.x - fitRect.minX) * strokeScale
                let cy = (sticker.y - fitRect.minY) * strokeScale
                let rect = CGRect(x: cx - side/2, y: cy - side/2, width: side, height: side)
                img.draw(in: rect)
            }
        }
    }
}


// Paint-zone control: the precomputed -mask / -overlay PNGs mark exactly the
// paintable body per car. Strokes are clipped to the mask on export; the overlay
// (page + dark trim) is composited above strokes live so kids can't paint windows.
enum RenderMask {
    static func maskedToPaintable(_ strokes: UIImage, car: Car) -> UIImage {
        guard let mask = UIImage(named: car.maskImage)?.cgImage else { return strokes }
        let tplSize = car.tplSize
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        return UIGraphicsImageRenderer(size: tplSize, format: fmt).image { _ in
            let ctx = UIGraphicsGetCurrentContext()!
            ctx.clip(to: CGRect(origin: .zero, size: tplSize), mask: mask)
            strokes.draw(in: CGRect(origin: .zero, size: tplSize))
        }
    }

    static func overlay(car: Car) -> UIImage {
        UIImage(named: car.overlayImage) ?? UIImage()
    }

    static func rescale(_ drawing: PKDrawing, from: CGRect, to: CGRect) -> PKDrawing {
        guard from.width > 0, from != to else { return drawing }
        let sx = to.width / from.width, sy = to.height / from.height
        var t = CGAffineTransform(scaleX: sx, y: sy)
        t.tx = to.minX - from.minX * sx
        t.ty = to.minY - from.minY * sy
        return drawing.transformed(using: t)
    }
}
