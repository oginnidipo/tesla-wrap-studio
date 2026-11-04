import SwiftUI

struct ExportPanel: View {
    let car: Car
    let image: UIImage?
    @Binding var savedFiles: [String]
    @Environment(\.dismiss) var dismiss

    static func savedDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("My Wraps", isDirectory: true)
    }
    static func savedFileNames() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: savedDir().path))?.sorted().reversed() ?? []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(height: 280).shadow(radius: 6)
                    Text("\(Int(car.tplSize.width)) × \(Int(car.tplSize.height))px — Tesla ready ✅")
                        .font(.headline).foregroundColor(.green)
                    HStack(spacing: 14) {
                        Button {
                            let dir = Self.savedDir()
                            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                            let name = "\(car.rawValue.replacingOccurrences(of: " ", with: "-"))-\(Int(Date().timeIntervalSince1970)).png"
                            if let data = image.pngData(), ((try? data.write(to: dir.appendingPathComponent(name))) != nil) {
                                savedFiles = Self.savedFileNames()
                            }
                        } label: {
                            Label("Save to Files", systemImage: "square.and.arrow.down.fill")
                                .font(.headline).foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 10)
                                .background(Capsule().fill(Color.orange))
                        }
                        ShareLink(item: Image(uiImage: image), preview: SharePreview("My \(car.rawValue) wrap")) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.headline).foregroundColor(.orange).padding(.horizontal, 16).padding(.vertical, 10)
                                .background(Capsule().stroke(Color.orange, lineWidth: 2))
                        }
                    }
                    Text("Then: **Tesla app → Creations → Wrap → Upload**\nor drop the PNG on a USB stick in a folder called **Wraps**")
                        .font(.footnote).foregroundColor(.secondary).multilineTextAlignment(.center)
                } else {
                    Text("Draw on the car first! 🖍️").font(.title3)
                        .padding(.top, 120)
                }
                if !savedFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My saved wraps").font(.caption.bold()).foregroundColor(.secondary)
                        ForEach(savedFiles.prefix(5), id: \.self) { Text("• \($0)").font(.caption).lineLimit(1) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                }
                Spacer()
            }.padding(22)
            .navigationTitle("My Wrap ✨").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
