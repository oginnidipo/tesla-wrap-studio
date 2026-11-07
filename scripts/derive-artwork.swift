// Derives a vehicle's paint mask and overlay from Tesla's official wrap template.
//
//   swiftc -O scripts/derive-artwork.swift -o /tmp/derive-artwork
//   /tmp/derive-artwork template.png <id>-mask.png <id>-overlay.png [reference-mask reference-overlay]
//
// Templates come from https://github.com/teslamotors/custom-wraps: transparent outside the
// body, opaque white inside each panel, dark outlines between them.
//   - Mask: the opaque light pixels (panel interiors), minus specks under 64 pixels.
//   - Overlay: interiors transparent, everything else composited over white, except the
//     anti-aliased outline pixels that face a panel, which stay translucent so paint
//     blends into the outline.
// Passing the bundled mask and overlay as references prints how many pixels differ; on the
// three original vehicles the masks differ only in single edge pixels.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func load(_ path: String) -> (Int, Int, [UInt8]) {
    let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
    let w = img.width, h = img.height
    var px = [UInt8](repeating: 0, count: w*h*4)
    let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return (w, h, px)
}
func loadGray(_ path: String) -> [UInt8] {
    let (w, h, px) = load(path)
    return (0..<(w*h)).map { px[$0*4] }
}
func write(_ px: [UInt8], w: Int, h: Int, gray: Bool, to path: String) {
    var data = px
    let ctx: CGContext
    if gray {
        ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    } else {
        ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }
    let img = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

let args = Array(CommandLine.arguments.dropFirst())
let (w, h, t) = load(args[0])
let n = w*h
// Interior = opaque, light pixels. Drop tiny specks (< 64 px components).
var interior = [Bool](repeating: false, count: n)
for i in 0..<n {
    let a = t[i*4+3]; let lum = (Int(t[i*4]) + Int(t[i*4+1]) + Int(t[i*4+2])) / 3
    interior[i] = a == 255 && lum > 215
}
var seen = [Bool](repeating: false, count: n)
var stack: [Int] = []
var removed = 0
for i in 0..<n where interior[i] && !seen[i] {
    var comp: [Int] = []
    seen[i] = true; stack.append(i)
    while let p = stack.popLast() {
        comp.append(p)
        let x = p % w, y = p / w
        for (dx, dy) in [(1,0),(-1,0),(0,1),(0,-1)] {
            let nx = x+dx, ny = y+dy
            guard nx >= 0, ny >= 0, nx < w, ny < h else { continue }
            let q = ny*w+nx
            if interior[q] && !seen[q] { seen[q] = true; stack.append(q) }
        }
    }
    if comp.count < 64 { for p in comp { interior[p] = false }; removed += comp.count }
}
let mask = interior.map { $0 ? UInt8(255) : 0 }
// Overlay: interior transparent; background white; line pixels kept, and their
// anti-aliased edges facing a panel stay translucent so paint shows through.
var overlay = [UInt8](repeating: 0, count: n*4)
for i in 0..<n {
    if interior[i] { continue }
    let a = Int(t[i*4+3])
    let x = i % w, y = i / w
    var touchesInterior = false
    if a > 0 && a < 255 {
        outer: for dy in -1...1 { for dx in -1...1 {
            let nx = x+dx, ny = y+dy
            if nx >= 0, ny >= 0, nx < w, ny < h, interior[ny*w+nx] { touchesInterior = true; break outer }
        } }
    }
    if touchesInterior {
        for c in 0..<4 { overlay[i*4+c] = t[i*4+c] }
    } else {
        // premultiplied composite over white
        for c in 0..<3 { overlay[i*4+c] = UInt8(min(255, Int(t[i*4+c]) + (255 - a))) }
        overlay[i*4+3] = 255
    }
}
write(mask, w: w, h: h, gray: true, to: args[1])
write(overlay, w: w, h: h, gray: false, to: args[2])
let maskCount = interior.filter { $0 }.count
var report = "\((args[0] as NSString).deletingLastPathComponent.split(separator: "/").last ?? "") \(w)x\(h) mask=\(maskCount) removedSpecks=\(removed)"
if args.count >= 5 {
    let ref = loadGray(args[3])
    var diff = 0
    for i in 0..<n where (ref[i] > 127) != interior[i] { diff += 1 }
    let (_, _, ro) = load(args[4])
    var odiff = 0
    for i in 0..<n {
        let da = abs(Int(ro[i*4+3]) - Int(overlay[i*4+3]))
        let dc = abs(Int(ro[i*4]) - Int(overlay[i*4]))
        if da > 8 || dc > 8 { odiff += 1 }
    }
    report += " maskDiff=\(diff) overlayDiff=\(odiff)"
}
print(report)
