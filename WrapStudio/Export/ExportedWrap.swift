import UIKit

struct ExportedWrap: Identifiable {
    let id = UUID()
    let image: UIImage
    let pngData: Data
    let fileURL: URL

    var dimensions: String { "\(Int(image.size.width)) × \(Int(image.size.height))" }
    var fileSize: String { ByteCountFormatter.string(fromByteCount: Int64(pngData.count), countStyle: .file) }
}
