import UIKit

/// The individual body panels of a template: the connected regions of its paintable mask.
/// Built once per vehicle and shared by the editor, the bucket tool, and export.
final class PanelMap: Sendable {
    let width: Int
    let height: Int
    /// Panel index for every pixel, or -1 outside the paintable body.
    let labels: [Int32]
    /// The mask's coverage (0–255), used as alpha so panel fills keep the mask's soft edges.
    let coverage: [UInt8]
    /// Pixel indices that belong to each panel.
    let panelPixels: [[Int32]]

    var panelCount: Int { panelPixels.count }

    static let minimumPanelPixels = 64

    init?(mask: CGImage) {
        let width = mask.width, height = mask.height, count = width * height
        guard count > 0 else { return nil }
        var gray = [UInt8](repeating: 0, count: count)
        let drew = gray.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.draw(mask, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return nil }

        var labels = [Int32](repeating: -1, count: count)
        var panelCount: Int32 = 0
        gray.withUnsafeBufferPointer { gray in
            labels.withUnsafeMutableBufferPointer { labels in
                var stack: [Int] = []
                stack.reserveCapacity(4096)
                // 4-connected regions of solidly paintable pixels.
                for start in 0..<count where gray[start] > 127 && labels[start] < 0 {
                    let label = panelCount
                    panelCount += 1
                    labels[start] = label
                    stack.append(start)
                    while let index = stack.popLast() {
                        let x = index % width
                        if x > 0, gray[index - 1] > 127, labels[index - 1] < 0 { labels[index - 1] = label; stack.append(index - 1) }
                        if x < width - 1, gray[index + 1] > 127, labels[index + 1] < 0 { labels[index + 1] = label; stack.append(index + 1) }
                        if index >= width, gray[index - width] > 127, labels[index - width] < 0 {
                            labels[index - width] = label; stack.append(index - width)
                        }
                        if index < count - width, gray[index + width] > 127, labels[index + width] < 0 {
                            labels[index + width] = label; stack.append(index + width)
                        }
                    }
                }
                // Extend each panel over its anti-aliased rim so fills reach the outline.
                for _ in 0..<2 {
                    var grown: [(Int, Int32)] = []
                    for index in 0..<count where labels[index] < 0 && gray[index] > 0 {
                        let x = index % width
                        if x > 0, labels[index - 1] >= 0 { grown.append((index, labels[index - 1])) }
                        else if x < width - 1, labels[index + 1] >= 0 { grown.append((index, labels[index + 1])) }
                        else if index >= width, labels[index - width] >= 0 { grown.append((index, labels[index - width])) }
                        else if index < count - width, labels[index + width] >= 0 { grown.append((index, labels[index + width])) }
                    }
                    for (index, label) in grown { labels[index] = label }
                }
            }
        }

        var regions = [[Int32]](repeating: [], count: Int(panelCount))
        for index in 0..<count where labels[index] >= 0 {
            regions[Int(labels[index])].append(Int32(index))
        }
        // Stray specks in a mask are not panels anyone can tap; renumber the rest densely.
        var panelPixels: [[Int32]] = []
        for region in regions {
            if region.count < Self.minimumPanelPixels {
                for index in region { labels[Int(index)] = -1 }
            } else {
                for index in region { labels[Int(index)] = Int32(panelPixels.count) }
                panelPixels.append(region)
            }
        }
        self.width = width
        self.height = height
        self.labels = labels
        self.coverage = gray
        self.panelPixels = panelPixels
    }

    @MainActor private static var cache: [Car: PanelMap] = [:]

    @MainActor static func forCar(_ car: Car) -> PanelMap? {
        if let cached = cache[car] { return cached }
        guard let mask = UIImage(named: car.maskImage)?.cgImage, let map = PanelMap(mask: mask) else { return nil }
        cache[car] = map
        return map
    }

    /// The panel under a point in template pixels. Taps that land on an outline snap to the
    /// nearest panel within `tolerance` pixels.
    func panel(at point: CGPoint, tolerance: Int = 6) -> Int? {
        let x = Int(point.x.rounded(.down)), y = Int(point.y.rounded(.down))
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let direct = labels[y * width + x]
        if direct >= 0 { return Int(direct) }
        var best: (distance: Int, label: Int32)?
        for dy in -tolerance...tolerance {
            for dx in -tolerance...tolerance {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                let label = labels[ny * width + nx]
                let distance = dx * dx + dy * dy
                if label >= 0, distance <= tolerance * tolerance, distance < (best?.distance ?? .max) {
                    best = (distance, label)
                }
            }
        }
        return best.map { Int($0.label) }
    }

    /// `point` when it lies inside `panel`, otherwise the panel pixel closest to it. Stored
    /// fills use this so a mirrored tap that lands on an outline still names its panel.
    func anchor(for panel: Int, near point: CGPoint) -> CGPoint {
        let x = Int(point.x.rounded(.down)), y = Int(point.y.rounded(.down))
        if x >= 0, y >= 0, x < width, y < height, labels[y * width + x] == Int32(panel) { return point }
        guard panel >= 0, panel < panelPixels.count else { return point }
        var best = (distance: Int.max, index: 0)
        for index in panelPixels[panel] {
            let px = Int(index) % width, py = Int(index) / width
            let distance = (px - x) * (px - x) + (py - y) * (py - y)
            if distance < best.distance { best = (distance, Int(index)) }
        }
        return CGPoint(x: CGFloat(best.index % width) + 0.5, y: CGFloat(best.index / width) + 0.5)
    }

    /// A spot well inside the largest panel, where new stickers start out visible.
    var stickerHome: (center: CGPoint, size: CGSize)? {
        guard let largest = panelPixels.indices.max(by: { panelPixels[$0].count < panelPixels[$1].count }),
              !panelPixels[largest].isEmpty else { return nil }
        var minX = width, minY = height, maxX = 0, maxY = 0, sumX = 0, sumY = 0
        for index in panelPixels[largest] {
            let x = Int(index) % width, y = Int(index) / width
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            sumX += x; sumY += y
        }
        let count = panelPixels[largest].count
        let centroid = CGPoint(x: CGFloat(sumX) / CGFloat(count), y: CGFloat(sumY) / CGFloat(count))
        return (anchor(for: largest, near: centroid), CGSize(width: maxX - minX, height: maxY - minY))
    }

    /// The colour each panel ends up with; later fills replace earlier ones.
    func resolvedColors(for fills: [PanelFill]) -> [Int: String] {
        var colors: [Int: String] = [:]
        for fill in fills {
            if let panel = panel(at: fill.point) { colors[panel] = fill.hex }
        }
        return colors
    }

    /// A transparent image with each filled panel painted in its colour.
    func image(colors: [Int: String]) -> CGImage? {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        coverage.withUnsafeBufferPointer { coverage in
            pixels.withUnsafeMutableBufferPointer { pixels in
                for (panel, hex) in colors where panel >= 0 && panel < panelPixels.count {
                    let value = UInt32(hex, radix: 16) ?? 0
                    let red = Int((value >> 16) & 255), green = Int((value >> 8) & 255), blue = Int(value & 255)
                    for index in panelPixels[panel] {
                        let pixel = Int(index)
                        let alpha = Int(coverage[pixel])
                        let offset = pixel * 4
                        pixels[offset] = UInt8(red * alpha / 255)
                        pixels[offset + 1] = UInt8(green * alpha / 255)
                        pixels[offset + 2] = UInt8(blue * alpha / 255)
                        pixels[offset + 3] = UInt8(alpha)
                    }
                }
            }
        }
        // The data provider owns its copy of the pixels, so the image outlives this buffer.
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
