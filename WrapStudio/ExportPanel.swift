import SwiftUI

struct ExportPanel: View {
    let car: Car
    let wrap: ExportedWrap
    @Environment(\.dismiss) private var dismiss
    @State private var showingFileExporter = false
    @State private var status: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Ready for a new look.").font(.largeTitle.bold()).fontDesign(.rounded)
                    Image(uiImage: wrap.image).resizable().scaledToFit()
                        .frame(maxHeight: 320).frame(maxWidth: .infinity)
                        .background(.white, in: .rect(cornerRadius: 16))
                        .accessibilityLabel("Your completed \(car.name) wrap")
                    Label("PNG · \(wrap.dimensions) · \(wrap.fileSize)", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.green)

                    Button("Save to Files", systemImage: "folder") { showingFileExporter = true }
                        .font(.headline).frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .accessibilityIdentifier("saveToFiles")
                    ShareLink(item: wrap.fileURL, preview: SharePreview("My \(car.name) wrap", image: Image(uiImage: wrap.image))) {
                        Label("Share PNG", systemImage: "square.and.arrow.up").font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    if let status { Text(status).font(.callout).foregroundStyle(.secondary) }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Bring it to Paint Shop", systemImage: "car.side").font(.headline)
                        Text("In the Tesla app, open Creations → Wrap → Upload. Or put the PNG in a Wraps folder on your USB drive.")
                        Text("In your vehicle, open Toybox → Paint Shop → Wraps. This changes the on-screen visualization.")
                        Text("\(car.templateNote). Check that this template matches your vehicle’s body style.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Link("Tesla’s template & setup guide", destination: URL(string: "https://github.com/teslamotors/custom-wraps")!)
                            .font(.footnote.weight(.semibold))
                    }
                    .font(.subheadline).padding(18)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
                }.padding(22).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Export wrap").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileExporter(isPresented: $showingFileExporter, document: PNGDocument(data: wrap.pngData),
                          contentType: .png, defaultFilename: wrap.fileURL.deletingPathExtension().lastPathComponent) { result in
                switch result {
                case .success: status = "Your PNG was saved to Files."
                case .failure(let error):
                    if (error as NSError).code != NSUserCancelledError { status = "Could not save: \(error.localizedDescription)" }
                }
            }
        }
    }
}
