import SwiftUI

enum Car: String, CaseIterable, Identifiable {
    case m3 = "Model 3", my = "Model Y", ct = "Cybertruck"
    var id: String { rawValue }
    var template: String { ["m3": "m3-template", "my": "my-template", "ct": "ct-template"][rawValue] ?? "m3-template" }
    var carImage: String { ["m3": "m3-car", "my": "my-car", "ct": "ct-car"][rawValue] ?? "m3-car" }
    var maskImage: String { ["m3": "m3-mask", "my": "my-mask", "ct": "ct-mask"][rawValue] ?? "m3-mask" }
    var overlayImage: String { ["m3": "m3-overlay", "my": "my-overlay", "ct": "ct-overlay"][rawValue] ?? "m3-overlay" }
    var tplSize: CGSize { self == .ct ? CGSize(width: 1024, height: 768) : CGSize(width: 1024, height: 1024) }
    var emoji: String { self == .m3 ? "🚗" : self == .my ? "🚙" : "🛻" }
}

struct ContentView: View {
    @State private var car: Car?
    var body: some View {
        if let car {
            CanvasView(car: car, onClose: { withAnimation(.spring()) { self.car = nil } })
        } else {
            CarPicker(car: $car).transition(.opacity)
        }
    }
}

struct CarPicker: View {
    @Binding var car: Car?
    var body: some View {
        VStack(spacing: 26) {
            Text("Tesla Car Wrap 🎨").font(.system(size: 46, weight: .heavy, design: .rounded))
            Text("Pick your Tesla!").font(.title2).foregroundColor(.secondary)
            Spacer()
            ForEach(Car.allCases) { c in
                Button { withAnimation(.spring()) { car = c } } label: {
                    HStack(spacing: 18) {
                        Image(c.carImage).resizable().scaledToFit()
                            .frame(height: 120).shadow(radius: 3)
                        Text(c.rawValue).font(.title2.bold()).foregroundColor(.primary)
                        Spacer()
                        Text(c.emoji).font(.largeTitle)
                    }.padding(22)
                    .background(RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.white).shadow(color: .black.opacity(0.08), radius: 8, y: 3))
                }.buttonStyle(.plain)
            }
            Spacer()
            Text("Paint it · Save it · Your real Tesla can wear it! 🚗✨")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
