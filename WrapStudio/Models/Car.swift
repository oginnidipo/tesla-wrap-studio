import SwiftUI

/// A body style with its own Tesla wrap template. Raw values name the bundled artwork
/// (`<raw>-template`, `-mask`, `-overlay`, `-car`) and are stored in saved designs,
/// so existing raw values must never change.
enum Car: String, CaseIterable, Identifiable, Codable {
    case m3Refresh = "m3-2024"
    case m3RefreshPerformance = "m3-2024p"
    case m3
    case myRefresh = "my-2025"
    case myRefreshPremium = "my-2025-premium"
    case myRefreshPerformance = "my-2025p"
    case myL = "my-l"
    case my
    case msRefresh = "ms-2021"
    case msPlaid = "ms-2025p"
    case mxRefresh = "mx-2021"
    case ct

    var id: String { rawValue }

    var family: VehicleFamily {
        switch self {
        case .m3, .m3Refresh, .m3RefreshPerformance: .model3
        case .my, .myRefresh, .myRefreshPremium, .myRefreshPerformance, .myL: .modelY
        case .msRefresh, .msPlaid: .modelS
        case .mxRefresh: .modelX
        case .ct: .cybertruck
        }
    }

    /// The model name, without the body style.
    var name: String { self == .myL ? "Model Y L" : family.name }

    /// The body style or trim that has its own template.
    var trim: String {
        switch self {
        case .m3Refresh: "2024+ Standard & Premium"
        case .m3RefreshPerformance: "2024+ Performance"
        case .m3: "2017–2023"
        case .myRefresh: "2025+ Standard"
        case .myRefreshPremium: "2025+ Premium"
        case .myRefreshPerformance: "2025+ Performance"
        case .myL: "2025+"
        case .my: "2020–2024"
        case .msRefresh: "2021+"
        case .msPlaid: "2025+ Plaid"
        case .mxRefresh: "2021+"
        case .ct: "All trims"
        }
    }

    var fullName: String { "\(name) · \(trim)" }

    /// How the body style is labelled when its model is already shown.
    var variantLabel: String { self == .myL ? "Model Y L" : trim }

    var template: String { "\(rawValue)-template" }
    var carImage: String { "\(rawValue)-car" }
    var maskImage: String { "\(rawValue)-mask" }
    var overlayImage: String { "\(rawValue)-overlay" }
    var templateSize: CGSize {
        CGSize(width: 1024, height: self == .ct ? 768 : 1024)
    }
    var dimensions: String { "\(Int(templateSize.width)) × \(Int(templateSize.height))" }

    /// Tesla templates lay out the left and right sides as mirror images. Model 3, Y, S
    /// and X mirror across a vertical axis; Cybertruck mirrors across a horizontal one.
    /// Each axis was measured from the mask (sum = 2 × axis position, in template pixels).
    var mirrorAxis: MirrorAxis {
        switch self {
        case .m3: .vertical(sum: 1026)
        case .m3Refresh: .vertical(sum: 1028)
        case .m3RefreshPerformance: .vertical(sum: 1027)
        case .my: .vertical(sum: 1023)
        case .myRefresh: .vertical(sum: 1027)
        case .myRefreshPremium: .vertical(sum: 1020)
        case .myRefreshPerformance: .vertical(sum: 1019)
        case .myL: .vertical(sum: 1030)
        case .msRefresh, .msPlaid, .mxRefresh: .vertical(sum: 1023)
        case .ct: .horizontal(sum: 767)
        }
    }

    /// The prototype stored one draft per original vehicle, named after the vehicle.
    var legacyFileName: String? {
        switch self {
        case .m3: "Model-3"
        case .my: "Model-Y"
        case .ct: "Cybertruck"
        default: nil
        }
    }
}

enum MirrorAxis: Equatable {
    case vertical(sum: CGFloat)
    case horizontal(sum: CGFloat)

    var transform: CGAffineTransform {
        switch self {
        case .vertical(let sum): CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: sum, ty: 0)
        case .horizontal(let sum): CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: sum)
        }
    }

    func mirror(_ point: CGPoint) -> CGPoint { point.applying(transform) }

    /// Rotation of a sticker after mirroring. A horizontal flip negates the angle; a
    /// vertical flip is a horizontal flip followed by a half turn.
    func mirroredRotation(_ angle: Double) -> Double {
        switch self {
        case .vertical: -angle
        case .horizontal: .pi - angle
        }
    }

    var isVertical: Bool { if case .vertical = self { true } else { false } }
}

enum VehicleFamily: String, CaseIterable, Identifiable {
    case model3, modelY, modelS, modelX, cybertruck

    var id: String { rawValue }
    var name: String {
        switch self {
        case .model3: "Model 3"
        case .modelY: "Model Y"
        case .modelS: "Model S"
        case .modelX: "Model X"
        case .cybertruck: "Cybertruck"
        }
    }

    /// Newest body style first.
    var cars: [Car] { Car.allCases.filter { $0.family == self } }
    var heroCar: Car { cars[0] }
}
