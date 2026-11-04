import SwiftUI

enum Car: String, CaseIterable, Identifiable, Codable {
    case m3, my, ct

    var id: String { rawValue }
    var name: String {
        switch self {
        case .m3: "Model 3"
        case .my: "Model Y"
        case .ct: "Cybertruck"
        }
    }
    var template: String { "\(rawValue)-template" }
    var carImage: String { "\(rawValue)-car" }
    var maskImage: String { "\(rawValue)-mask" }
    var overlayImage: String { "\(rawValue)-overlay" }
    var templateSize: CGSize {
        CGSize(width: 1024, height: self == .ct ? 768 : 1024)
    }
    var dimensions: String { "1024 × \(Int(templateSize.height))" }
    var templateNote: String { self == .ct ? "Cybertruck template" : "Original body template" }
    var legacyFileName: String { name.replacingOccurrences(of: " ", with: "-") }
}
