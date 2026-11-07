import SwiftUI

struct PaintCanvas: View {
    @ObservedObject var session: EditorSession

    var body: some View {
        // GeometryReader is intentional: the PencilKit bridge, sticker gestures and the bucket
        // tool must share the exact fitted template rectangle, including its letterbox offsets.
        GeometryReader { geometry in
            let rect = CanvasGeometry.fitRect(template: session.car.templateSize, in: geometry.size)
            let scale = rect.width / session.car.templateSize.width
            ZStack {
                TemplatePaintSurface(session: session, revision: session.drawingRevision,
                                     tool: session.pencilTool(displayScale: scale),
                                     isDrawingEnabled: session.tool != .fill,
                                     fillHex: session.fillHex, panelFills: session.panelFills)
                    // On the surface itself: an identifier on the whole canvas would also
                    // replace the identifiers of the stickers and the bucket layer inside it.
                    .accessibilityIdentifier("paintCanvas")

                if session.tool == .fill {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: rect.width, height: rect.height)
                        .onTapGesture(coordinateSpace: .local) { location in
                            guard scale > 0 else { return }
                            session.selectedStickerID = nil
                            let filled = session.fillPanel(at: CGPoint(x: location.x / scale, y: location.y / scale))
                            filled ? Haptics.tap() : Haptics.warning()
                        }
                        .position(x: rect.midX, y: rect.midY)
                        .accessibilityElement()
                        .accessibilityLabel("Body panels")
                        .accessibilityHint("Double-tap a panel to fill it with the current color.")
                        .accessibilityIdentifier("fillSurface")
                }

                ZStack {
                    ForEach(session.stickers) { sticker in
                        PlacedStickerView(session: session, sticker: sticker, scale: scale)
                    }
                }
                .frame(width: rect.width, height: rect.height)
                .coordinateSpace(name: "wrapSurface")
                .position(x: rect.midX, y: rect.midY)

                // Same final layer as export: trim and windows stay clean, including stickers.
                Image(uiImage: UIImage(named: session.car.overlayImage) ?? UIImage()).resizable()
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false).accessibilityHidden(true)

                if session.isMirroring {
                    MirrorGuide(axis: session.car.mirrorAxis, scale: scale)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .task(id: geometry.size) { session.migrateLegacyIfNeeded(in: geometry.size) }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.primary.opacity(0.08)) }
    }
}

/// The line paint is reflected across while mirroring.
private struct MirrorGuide: View {
    let axis: MirrorAxis
    let scale: CGFloat

    var body: some View {
        Canvas { context, size in
            var path = Path()
            switch axis {
            case .vertical(let sum):
                path.move(to: CGPoint(x: sum / 2 * scale, y: 0))
                path.addLine(to: CGPoint(x: sum / 2 * scale, y: size.height))
            case .horizontal(let sum):
                path.move(to: CGPoint(x: 0, y: sum / 2 * scale))
                path.addLine(to: CGPoint(x: size.width, y: sum / 2 * scale))
            }
            context.stroke(path, with: .color(StudioStyle.accent.opacity(0.75)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        }
    }
}
