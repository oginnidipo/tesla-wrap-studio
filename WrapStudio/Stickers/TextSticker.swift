import CoreText
import SwiftUI
import UIKit

enum TextStickerStyle: String, CaseIterable, Identifiable {
    case bold, sport, classic, mono

    var id: String { rawValue }
    var title: String {
        switch self {
        case .bold: "Bold"
        case .sport: "Sport"
        case .classic: "Classic"
        case .mono: "Mono"
        }
    }

    var obliqueness: CGFloat { self == .sport ? 0.2 : 0 }

    func font(size: CGFloat) -> UIFont {
        switch self {
        case .bold:
            let base = UIFont.systemFont(ofSize: size, weight: .black)
            return UIFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size)
        case .sport:
            // Slanted with `obliqueness` when drawn; replacing symbolic traits would drop the weight.
            return UIFont.systemFont(ofSize: size, weight: .black, width: .expanded)
        case .classic:
            let base = UIFont.systemFont(ofSize: size, weight: .bold)
            return UIFont(descriptor: base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor, size: size)
        case .mono:
            return UIFont.monospacedSystemFont(ofSize: size, weight: .heavy)
        }
    }
}

/// Renders lettering to a transparent PNG-ready image, sized for template pixels.
@MainActor enum TextStickerRenderer {
    static let maximumWidth: CGFloat = 1024

    static func image(text: String, style: TextStickerStyle, colorHex: String, outlined: Bool,
                      pointSize: CGFloat = 160) throws -> UIImage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StudioError.emptyText }
        let fill = StudioStyle.uiColor(hex: colorHex)
        let outline = StudioStyle.prefersLightContent(onHex: colorHex) ? UIColor.white : UIColor.black
        let outlineWidth = outlined ? pointSize * 0.07 : 0
        guard let glyphs = glyphPath(for: trimmed, style: style, pointSize: pointSize) else {
            return try fallbackImage(text: trimmed, style: style, fill: fill, outline: outlined ? outline : nil, pointSize: pointSize)
        }
        let padding = outlineWidth + pointSize * 0.06
        let bounds = glyphs.boundingBoxOfPath.insetBy(dx: -padding, dy: -padding)
        let scale = min(1, maximumWidth / bounds.width)
        let size = CGSize(width: (bounds.width * scale).rounded(.up), height: (bounds.height * scale).rounded(.up))
        return renderer(size: size).image { context in
            let cg = context.cgContext
            cg.scaleBy(x: scale, y: scale)
            // Core Text paths are y-up; flip into the image's y-down space.
            cg.translateBy(x: -bounds.minX, y: bounds.maxY)
            cg.scaleBy(x: 1, y: -1)
            if outlined {
                // Stroke first, then fill over it: variable fonts overlap their contours, and
                // filling last hides the strokes of those inner overlaps.
                cg.addPath(glyphs)
                cg.setLineJoin(.round)
                cg.setLineCap(.round)
                cg.setLineWidth(outlineWidth * 2)
                cg.setStrokeColor(outline.cgColor)
                cg.strokePath()
            }
            cg.addPath(glyphs)
            cg.setFillColor(fill.cgColor)
            cg.fillPath()
        }
    }

    /// Outlines of every glyph, centred line by line, slanted for the Sport style. `nil` when
    /// a glyph has no outline (such as a colour emoji).
    private static func glyphPath(for text: String, style: TextStickerStyle, pointSize: CGFloat) -> CGPath? {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let font = style.font(size: pointSize) as CTFont
        let string = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: paragraph])
        let framesetter = CTFramesetterCreateWithAttributedString(string)
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil,
                                                                     CGSize(width: 20_000, height: 20_000), nil)
        let frameRect = CGRect(x: 0, y: 0, width: suggested.width.rounded(.up) + 2, height: suggested.height.rounded(.up) + 2)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(), CGPath(rect: frameRect, transform: nil), nil)
        guard let lines = CTFrameGetLines(frame) as? [CTLine], !lines.isEmpty else { return nil }
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(), &origins)
        let path = CGMutablePath()
        for (line, origin) in zip(lines, origins) {
            guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { continue }
            for run in runs {
                let attributes = CTRunGetAttributes(run) as NSDictionary
                let runFont = attributes[kCTFontAttributeName as String].map { $0 as! CTFont } ?? font
                let count = CTRunGetGlyphCount(run)
                var glyphs = [CGGlyph](repeating: 0, count: count)
                var positions = [CGPoint](repeating: .zero, count: count)
                CTRunGetGlyphs(run, CFRange(), &glyphs)
                CTRunGetPositions(run, CFRange(), &positions)
                for index in 0..<count {
                    guard let glyph = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) else {
                        // Spaces have no outline; anything else without one cannot be drawn here.
                        if CTFontGetBoundingRectsForGlyphs(runFont, .default, [glyphs[index]], nil, 1).isEmpty { continue }
                        return nil
                    }
                    let place = CGAffineTransform(a: 1, b: 0, c: style.obliqueness, d: 1,
                                                  tx: origin.x + positions[index].x, ty: origin.y + positions[index].y)
                    path.addPath(glyph, transform: place)
                }
            }
        }
        return path.isEmpty ? nil : path
    }

    /// Text drawing for glyphs without outlines, such as emoji.
    private static func fallbackImage(text: String, style: TextStickerStyle, fill: UIColor, outline: UIColor?,
                                      pointSize: CGFloat) throws -> UIImage {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        var attributes: [NSAttributedString.Key: Any] = [
            .font: style.font(size: pointSize), .foregroundColor: fill,
            .paragraphStyle: paragraph, .obliqueness: style.obliqueness,
        ]
        if let outline {
            attributes[.strokeColor] = outline
            attributes[.strokeWidth] = -5
        }
        let string = NSAttributedString(string: text, attributes: attributes)
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let bounds = string.boundingRect(with: CGSize(width: 6000, height: 6000), options: options, context: nil).integral
        let padding = pointSize * (0.15 + style.obliqueness)
        let natural = CGSize(width: bounds.width + padding * 2, height: bounds.height + padding * 2)
        let scale = min(1, maximumWidth / natural.width)
        let size = CGSize(width: (natural.width * scale).rounded(.up), height: (natural.height * scale).rounded(.up))
        return renderer(size: size).image { context in
            context.cgContext.scaleBy(x: scale, y: scale)
            string.draw(with: CGRect(x: padding, y: padding, width: bounds.width, height: bounds.height), options: options, context: nil)
        }
    }

    private static func renderer(size: CGSize) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format)
    }
}

struct TextStickerSheet: View {
    @ObservedObject var session: EditorSession
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var style = TextStickerStyle.sport
    @State private var colorHex = StudioStyle.defaultInkHex
    @State private var outlined = true
    @State private var errorMessage: String?
    @FocusState private var editing: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    TextField("Your name, a number, a slogan", text: $text, axis: .vertical)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1...3)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .focused($editing)
                        .onChange(of: text) { value in if value.count > 40 { text = String(value.prefix(40)) } }
                        .accessibilityIdentifier("textStickerField")

                    Picker("Style", selection: $style) {
                        ForEach(TextStickerStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(StudioStyle.swatches) { swatch in
                                Button { colorHex = swatch.hex } label: {
                                    Circle().fill(StudioStyle.color(hex: swatch.hex))
                                        .overlay { Circle().strokeBorder(.primary.opacity(0.15)) }
                                        .frame(width: 32, height: 32).padding(3)
                                        .overlay { if colorHex == swatch.hex { Circle().strokeBorder(Color.primary, lineWidth: 2) } }
                                }
                                .buttonStyle(.plain)
                                .frame(minWidth: 40, minHeight: 44)
                                .accessibilityLabel(swatch.name)
                                .accessibilityAddTraits(colorHex == swatch.hex ? .isSelected : [])
                            }
                        }
                    }
                    .scrollIndicators(.hidden)

                    Toggle("Outline", isOn: $outlined)
                    if let errorMessage { Text(errorMessage).font(.callout).foregroundStyle(.red) }
                }
                .padding(22)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Lettering").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("addTextSticker")
                }
            }
            .onAppear {
                colorHex = session.colorHex
                editing = true
            }
        }
    }

    private var preview: some View {
        ZStack {
            // Contrast with the outline, which itself contrasts with the lettering.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: StudioStyle.prefersLightContent(onHex: colorHex) ? 0.22 : 0.92))
            if let image = try? TextStickerRenderer.image(text: text, style: style, colorHex: colorHex,
                                                          outlined: outlined, pointSize: 72) {
                Image(uiImage: image).resizable().scaledToFit().padding(16)
            } else {
                Text("Aa").font(Font(style.font(size: 56)))
                    .foregroundStyle(StudioStyle.prefersLightContent(onHex: colorHex) ? Color.white.opacity(0.35) : Color.black.opacity(0.25))
            }
        }
        .frame(height: 150)
        .accessibilityHidden(true)
    }

    private func add() {
        do {
            let image = try TextStickerRenderer.image(text: text, style: style, colorHex: colorHex, outlined: outlined)
            let name = try session.stickerLibrary.add(image, prefix: "tx")
            session.addSticker(named: name, side: min(520, max(220, image.size.width * 0.5)))
            session.tool = session.tool == .fill ? .pen : session.tool
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
