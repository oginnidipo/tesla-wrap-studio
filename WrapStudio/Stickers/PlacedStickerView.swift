import SwiftUI

struct PlacedStickerView: View {
    @ObservedObject var session: EditorSession
    let sticker: CanvasSticker
    let scale: CGFloat
    @GestureState private var translation = CGSize.zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var twist = Angle.zero

    private var selected: Bool { session.selectedStickerID == sticker.id }
    private var side: CGFloat { CanvasGeometry.stickerSide(sticker.side, magnification: magnification) * scale }
    private var image: UIImage { session.stickerLibrary.image(named: sticker.fileName) ?? UIImage() }
    private var position: CGPoint {
        CGPoint(x: sticker.x * scale + translation.width, y: sticker.y * scale + translation.height)
    }

    var body: some View {
        artwork
            .rotationEffect(.radians(sticker.rotation) + twist)
            .position(position)
            .onTapGesture {
                session.selectedStickerID = selected ? nil : sticker.id
                Haptics.select()
            }
            .gesture(drag)
            .simultaneousGesture(pinchAndTwist)
            .modifier(StickerAccessibility(session: session, sticker: sticker, selected: selected))
    }

    private var artwork: some View {
        // Fit inside the square frame used for export, so the selection hugs the image.
        let fitted = CanvasGeometry.fitRect(template: image.size, in: CGSize(width: side, height: side)).size
        return Image(uiImage: image)
            .resizable()
            .frame(width: max(fitted.width, 1), height: max(fitted.height, 1))
            .scaleEffect(x: sticker.isFlipped ? -1 : 1, y: 1)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(StudioStyle.accent, style: StrokeStyle(lineWidth: 2, dash: [7, 4]))
                        .padding(-6)
                }
            }
    }

    private var drag: some Gesture {
        DragGesture(coordinateSpace: .named("wrapSurface"))
            .updating($translation) { value, state, _ in state = value.translation }
            .onChanged { _ in if !selected { session.selectedStickerID = sticker.id } }
            .onEnded { value in
                guard scale > 0 else { return }
                session.moveSticker(sticker.id, by: CGSize(width: value.translation.width / scale,
                                                          height: value.translation.height / scale))
            }
    }

    private var pinchAndTwist: some Gesture {
        MagnificationGesture().simultaneously(with: RotationGesture())
            .updating($magnification) { value, state, _ in state = value.first ?? 1 }
            .updating($twist) { value, state, _ in state = value.second ?? .zero }
            .onChanged { _ in if !selected { session.selectedStickerID = sticker.id } }
            .onEnded { value in
                session.transformSticker(sticker.id, magnification: value.first ?? 1,
                                         rotation: (value.second ?? .zero).radians)
            }
    }
}

private struct StickerAccessibility: ViewModifier {
    let session: EditorSession
    let sticker: CanvasSticker
    let selected: Bool

    private var label: Text { Text(sticker.fileName.hasPrefix("tx-") ? "Text sticker" : "Photo sticker") }
    private var value: Text { Text(selected ? "Selected" : "") }

    func body(content: Content) -> some View {
        let described = content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("sticker")
        return described
            .accessibilityAction { select() }
            .accessibilityActions { actions }
            .accessibilityAdjustableAction(resize)
    }

    @ViewBuilder private var actions: some View {
        Button("Remove") { session.deleteSticker(sticker.id) }
        Button("Move left") { move(-25, 0) }
        Button("Move right") { move(25, 0) }
        Button("Move up") { move(0, -25) }
        Button("Move down") { move(0, 25) }
        Button("Rotate left") { rotate(-.pi / 12) }
        Button("Rotate right") { rotate(.pi / 12) }
        Button("Flip") { session.flipSticker(sticker.id) }
        Button("Mirror to other side") { session.mirrorCopySticker(sticker.id) }
    }

    private func select() { session.selectedStickerID = sticker.id }

    private func rotate(_ angle: Double) { session.rotateSticker(sticker.id, by: angle) }

    private func resize(_ direction: AccessibilityAdjustmentDirection) {
        session.resizeSticker(sticker.id, magnification: direction == .increment ? 1.1 : 0.9)
    }

    private func move(_ dx: CGFloat, _ dy: CGFloat) {
        session.moveSticker(sticker.id, by: CGSize(width: dx, height: dy))
    }
}
