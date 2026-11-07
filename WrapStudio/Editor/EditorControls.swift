import SwiftUI

struct EditorControls: View {
    @ObservedObject var session: EditorSession
    @Binding var showingStickers: Bool
    @Binding var showingText: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolRow
            colorRow
            // A fixed slot, so switching tools never resizes the canvas.
            contextualRow.frame(minHeight: 50)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: Tools

    private var toolRow: some View {
        HStack(spacing: 4) {
            ForEach(PaintTool.allCases) { tool in
                ToolButton(title: tool.title, symbol: tool.symbol, isSelected: session.tool == tool) {
                    // Picking a tool means you're done arranging the selected sticker.
                    session.selectedStickerID = nil
                    session.tool = tool
                    Haptics.select()
                }
                .keyboardShortcut(KeyEquivalent(tool.key), modifiers: [])
                .accessibilityIdentifier("tool-\(tool.rawValue)")
            }
            Divider().frame(height: 30).padding(.horizontal, 2)
            ToolButton(title: "Text", symbol: "textformat", isSelected: false) { showingText = true }
                .keyboardShortcut("t", modifiers: [])
                .accessibilityIdentifier("addText")
            ToolButton(title: "Photo", symbol: "photo.badge.plus", isSelected: false) { showingStickers = true }
                .accessibilityIdentifier("addStickers")
        }
    }

    // MARK: Colour and width

    private var colorRow: some View {
        HStack(spacing: 10) {
            ColorPicker("Custom color", selection: customColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 36, height: 44)
                .accessibilityIdentifier("customColor")
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(session.recentColors, id: \.self) { hex in
                            SwatchButton(hex: hex, name: "Recent custom color", isSelected: session.colorHex == hex) {
                                session.selectColor(hex)
                            }
                        }
                        if !session.recentColors.isEmpty { Divider().frame(height: 26) }
                        ForEach(StudioStyle.swatches) { swatch in
                            SwatchButton(hex: swatch.hex, name: swatch.name, isSelected: session.colorHex == swatch.hex) {
                                session.selectColor(swatch.hex)
                                Haptics.select()
                            }
                            .id(swatch.hex)
                            .accessibilityIdentifier("color-\(swatch.hex)")
                        }
                    }
                    .padding(.vertical, 4).padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)
                .onAppear { proxy.scrollTo(session.colorHex, anchor: .center) }
            }
        }
    }

    private var customColor: Binding<Color> {
        Binding {
            StudioStyle.color(hex: session.colorHex)
        } set: { color in
            session.selectColor(StudioStyle.hex(from: UIColor(color)), remember: true)
        }
    }

    // MARK: Context

    @ViewBuilder private var contextualRow: some View {
        if let sticker = session.selectedSticker {
            StickerActions(session: session, sticker: sticker)
        } else if session.tool.usesWidth {
            BrushWidthSlider(session: session)
        } else {
            HStack(spacing: 10) {
                Button {
                    session.fillBody()
                    Haptics.success()
                } label: {
                    Label("Paint whole body", systemImage: "car.side.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(StudioStyle.color(hex: session.colorHex))
                .foregroundStyle(StudioStyle.prefersLightContent(onHex: session.colorHex) ? .white : .black)
                .accessibilityIdentifier("fillBody")
                Button(role: .destructive) {
                    session.clearFills()
                } label: {
                    Label("Clear fills", systemImage: "drop.halffull")
                }
                .buttonStyle(.bordered)
                .disabled(!session.hasFills)
                .accessibilityIdentifier("clearFills")
            }
            .font(.subheadline.weight(.semibold))
            .controlSize(.large)
        }
    }
}

private struct ToolButton: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).frame(height: 22)
                Text(title).font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? StudioStyle.accent : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SwatchButton: View {
    let hex: String
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(StudioStyle.color(hex: hex))
                .overlay { Circle().strokeBorder(.primary.opacity(0.15)) }
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark").font(.caption.bold())
                            .foregroundStyle(StudioStyle.prefersLightContent(onHex: hex) ? .white : .black)
                    }
                }
                .frame(width: 32, height: 32)
                .padding(3)
                .overlay { if isSelected { Circle().strokeBorder(Color.primary, lineWidth: 2) } }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 40, minHeight: 44)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct BrushWidthSlider: View {
    @ObservedObject var session: EditorSession

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(.tertiarySystemFill))
                Circle()
                    .fill(session.tool == .eraser ? Color.secondary : StudioStyle.color(hex: session.colorHex))
                    .overlay { Circle().strokeBorder(.primary.opacity(0.15)) }
                    .frame(width: dot, height: dot)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)
            Slider(value: $session.inkWidth, in: EditorSession.widthRange) {
                Text(session.tool == .eraser ? "Eraser size" : "Brush size")
            } minimumValueLabel: {
                Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Image(systemName: "circle.fill").font(.system(size: 16)).foregroundStyle(.secondary)
            }
            .accessibilityValue("\(Int(session.inkWidth)) pixels")
            .accessibilityIdentifier("brushWidth")
            Text("\(Int(session.inkWidth.rounded())) px")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }

    private var dot: CGFloat {
        let range = EditorSession.widthRange
        return 4 + 34 * (session.inkWidth - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
}

private struct StickerActions: View {
    @ObservedObject var session: EditorSession
    let sticker: CanvasSticker

    var body: some View {
        HStack(spacing: 4) {
            action("Rotate", "rotate.right") { session.rotateSticker(sticker.id, by: .pi / 12) }
            action("Flip", "arrow.left.and.right.righttriangle.left.righttriangle.right") { session.flipSticker(sticker.id) }
            action("Mirror", session.car.mirrorAxis.isVertical ? "square.split.2x1" : "square.split.1x2") {
                session.mirrorCopySticker(sticker.id)
                session.showNotice("Mirrored to the other side.")
            }
            .accessibilityLabel("Mirror to other side")
            action("Copy", "plus.square.on.square") { session.duplicateSticker(sticker.id) }
            action("Front", "square.3.layers.3d.top.filled") { session.bringStickerToFront(sticker.id) }
            action("Delete", "trash", role: .destructive) { session.deleteSticker(sticker.id) }
                .accessibilityIdentifier("deleteSticker")
        }
    }

    private func action(_ title: String, _ symbol: String, role: ButtonRole? = nil, perform: @escaping () -> Void) -> some View {
        Button(role: role) {
            perform()
            Haptics.tap()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).frame(height: 20)
                Text(title).font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(role == .destructive ? Color.red : Color.primary)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
