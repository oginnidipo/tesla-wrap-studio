import SwiftUI

struct EditorControls: View {
    @Bindable var session: EditorSession
    @Binding var showingStickers: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Picker("Drawing tool", selection: $session.tool) {
                    ForEach(PaintTool.allCases) { tool in
                        Label(tool.title, systemImage: tool.symbol).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                ColorPicker("Ink color", selection: $session.inkColor, supportsOpacity: false)
                    .labelsHidden().frame(minWidth: 44, minHeight: 44)
                    .disabled(session.tool == .eraser)
                Menu {
                    ForEach([CGFloat(5), 10, 22, 40], id: \.self) { width in
                        Button("\(Int(width)) px", systemImage: session.inkWidth == width ? "checkmark" : "circle") {
                            session.inkWidth = width
                        }
                    }
                } label: {
                    Label("Brush width", systemImage: "lineweight").labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            HStack {
                Text("FILL").font(.caption2.bold()).tracking(1).foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        Button { session.setFill(nil) } label: {
                            Image(systemName: "nosign").frame(width: 34, height: 34)
                                .background(Color(.secondarySystemGroupedBackground), in: .circle)
                                .overlay { Circle().strokeBorder(session.fillHex == nil ? Color.primary : .clear, lineWidth: 2) }
                        }.frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("No body fill").accessibilityAddTraits(session.fillHex == nil ? .isSelected : [])
                        ForEach(StudioStyle.palette, id: \.self) { hex in
                            Button { session.setFill(hex) } label: {
                                Circle().fill(StudioStyle.color(hex: hex)).frame(width: 34, height: 34)
                                    .overlay {
                                        if session.fillHex == hex {
                                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                        }
                                    }
                            }.frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("\(Self.colorName(hex)) body fill")
                            .accessibilityAddTraits(session.fillHex == hex ? .isSelected : [])
                            .accessibilityIdentifier("fill-\(hex)")
                        }
                    }.padding(.vertical, 5)
                }.scrollIndicators(.hidden)
                Button("Stickers", systemImage: "photo.badge.plus") { showingStickers = true }
                    .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("addStickers")
            }
            if let selectedID = session.selectedStickerID {
                Button("Remove selected sticker", systemImage: "trash", role: .destructive) {
                    session.deleteSticker(selectedID)
                }.font(.footnote).frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.bar)
    }

    private static func colorName(_ hex: String) -> String {
        switch hex {
        case "F14B35": "Coral"
        case "FFB547": "Amber"
        case "F6D968": "Yellow"
        case "5AAB88": "Green"
        case "558BC7": "Blue"
        case "9675C7": "Purple"
        case "F3A6BF": "Pink"
        default: "Charcoal"
        }
    }
}
