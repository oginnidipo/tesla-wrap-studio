import SwiftUI

/// Every supported vehicle, grouped by model, with a button for each body style.
struct VehicleCatalog: View {
    let title: String
    let onSelect: (Car) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.caption.weight(.bold)).tracking(1.5)
                Spacer()
                Text("\(Car.allCases.count) body styles").font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 14)], spacing: 14) {
                ForEach(VehicleFamily.allCases) { family in
                    FamilyCard(family: family, onSelect: onSelect)
                }
            }
        }
    }
}

private struct FamilyCard: View {
    let family: VehicleFamily
    let onSelect: (Car) -> Void
    @ScaledMetric(relativeTo: .title) private var imageHeight = 118

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(family.name).font(.title2.bold())
                    Text(family.cars.count == 1 ? "1 template" : "\(family.cars.count) body styles")
                        .font(.caption).foregroundStyle(.white.opacity(0.65))
                }
                .padding(.leading, 20)
                Spacer(minLength: 8)
                Image(uiImage: UIImage(named: family.heroCar.carImage) ?? UIImage())
                    .resizable().scaledToFill()
                    .frame(width: 170, height: imageHeight)
                    .clipped()
                    // Each photo has a slightly different backdrop; fade it into the card.
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.3)],
                                         startPoint: .leading, endPoint: .trailing))
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.18),
                                                 .init(color: .black, location: 0.82), .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom))
                    .accessibilityHidden(true)
            }
            FlowLayout(spacing: 8) {
                ForEach(family.cars) { car in
                    Button { onSelect(car) } label: {
                        HStack(spacing: 5) {
                            Text(car.variantLabel).font(.footnote.weight(.semibold))
                            Image(systemName: "arrow.up.right").font(.caption2.weight(.bold))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(.white.opacity(0.14), in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Design a \(car.fullName) wrap.")
                    .accessibilityIdentifier("car-\(car.rawValue)")
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
        .foregroundStyle(.white)
        .background(Color(white: 0.075))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// Wraps its children onto as many rows as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(width: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, layout.frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: min(size.width, width), height: size.height)))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (frames, CGSize(width: min(widest, width), height: y + rowHeight))
    }
}
