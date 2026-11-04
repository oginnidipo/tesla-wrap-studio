import SwiftUI

struct PlacedStickerView: View {
    let session: EditorSession
    let sticker: CanvasSticker
    let scale: CGFloat
    @GestureState private var translation = CGSize.zero
    @GestureState private var magnification: CGFloat = 1

    private var selected: Bool { session.selectedStickerID == sticker.id }

    var body: some View {
        Image(uiImage: session.stickerLibrary.image(named: sticker.fileName) ?? UIImage())
            .resizable().scaledToFit()
            .frame(width: CanvasGeometry.stickerSide(sticker.side, magnification: magnification) * scale,
                   height: CanvasGeometry.stickerSide(sticker.side, magnification: magnification) * scale)
            .overlay {
                if selected { RoundedRectangle(cornerRadius: 6).strokeBorder(StudioStyle.accent, lineWidth: 2) }
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Button("Remove sticker", systemImage: "xmark.circle.fill") { session.deleteSticker(sticker.id) }
                        .labelStyle(.iconOnly).font(.title2).tint(StudioStyle.accent)
                        .frame(width: 44, height: 44).background(.white, in: .circle)
                        .offset(x: 12, y: -12)
                }
            }
            .position(x: sticker.x * scale + translation.width, y: sticker.y * scale + translation.height)
            .onTapGesture { session.selectedStickerID = selected ? nil : sticker.id }
            .gesture(DragGesture(coordinateSpace: .named("wrapSurface"))
                .updating($translation) { value, state, _ in state = value.translation }
                .onChanged { _ in session.selectedStickerID = sticker.id }
                .onEnded { value in
                    guard scale > 0 else { return }
                    session.moveSticker(sticker.id, by: CGSize(width: value.translation.width / scale,
                                                              height: value.translation.height / scale))
                })
            .simultaneousGesture(MagnifyGesture()
                .updating($magnification) { value, state, _ in state = value.magnification }
                .onChanged { _ in session.selectedStickerID = sticker.id }
                .onEnded { value in session.resizeSticker(sticker.id, magnification: value.magnification) })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Photo sticker")
            .accessibilityValue(selected ? "Selected" : "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { session.selectedStickerID = sticker.id }
            .accessibilityAction(named: "Remove") { session.deleteSticker(sticker.id) }
            .accessibilityAction(named: "Move left") { session.moveSticker(sticker.id, by: CGSize(width: -25, height: 0)) }
            .accessibilityAction(named: "Move right") { session.moveSticker(sticker.id, by: CGSize(width: 25, height: 0)) }
            .accessibilityAction(named: "Move up") { session.moveSticker(sticker.id, by: CGSize(width: 0, height: -25)) }
            .accessibilityAction(named: "Move down") { session.moveSticker(sticker.id, by: CGSize(width: 0, height: 25)) }
            .accessibilityAdjustableAction { direction in
                session.resizeSticker(sticker.id, magnification: direction == .increment ? 1.1 : 0.9)
            }
    }
}
