import SwiftUI

struct ExportPanel: View {
    let car: Car
    let designName: String
    let wrap: ExportedWrap
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var photos = PhotoExportModel()
    @State private var showingFileExporter = false
    @State private var status: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Ready for a new look.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Image(uiImage: wrap.image).resizable().scaledToFit()
                        .frame(maxHeight: 320).frame(maxWidth: .infinity)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("\(designName), your completed \(car.name) wrap")
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Ready for Paint Shop · \(wrap.dimensions) · \(wrap.fileSize)", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.green)
                        Text(wrap.fileURL.lastPathComponent)
                            .font(.footnote.monospaced()).foregroundStyle(.secondary)
                            .accessibilityLabel("File name \(wrap.fileURL.deletingPathExtension().lastPathComponent)")
                            .accessibilityIdentifier("exportFileName")
                    }

                    Button {
                        Task { await photos.save(wrap) }
                    } label: {
                        HStack {
                            if photos.state == .saving { ProgressView().tint(.white) }
                            Label(photos.state == .saved ? "Saved to Photos" : "Save PNG to Photos",
                                  systemImage: photos.state == .saved ? "checkmark.circle.fill" : "photo.badge.arrow.down")
                        }.font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(photos.state == .saving || photos.state == .saved)
                    .accessibilityIdentifier("saveToPhotos")
                    photoStatus

                    Button { showingFileExporter = true } label: { Label("Save to Files", systemImage: "folder").frame(maxWidth: .infinity) }
                        .font(.headline).frame(maxWidth: .infinity)
                        .buttonStyle(.bordered).controlSize(.large)
                        .accessibilityIdentifier("saveToFiles")
                    ShareLink(item: wrap.fileURL, preview: SharePreview(designName, image: Image(uiImage: wrap.image))) {
                        Label("Share PNG", systemImage: "square.and.arrow.up").font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    if let status { Text(status).font(.callout).foregroundStyle(.secondary) }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Bring it to Paint Shop", systemImage: "car.side").font(.headline)
                        Text("1. Save your PNG to Photos above.")
                        Text("2. In the Tesla app, open Creations → Wrap → Upload and choose your saved wrap from Photos.")
                        Text("Using a USB drive? Save to Files, then copy the PNG into a Wraps folder at the drive’s root.")
                        Text("In your vehicle, open Toybox → Paint Shop → Wraps. This changes the on-screen visualization.")
                        Text("Made with the \(car.fullName) template. Tesla shows up to 10 wraps from the app and 10 from USB; check that this body style matches your vehicle.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Link("Tesla’s template & setup guide", destination: URL(string: "https://github.com/teslamotors/custom-wraps")!)
                            .font(.footnote.weight(.semibold))
                    }
                    .font(.subheadline).padding(18)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
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

    @ViewBuilder private var photoStatus: some View {
        switch photos.state {
        case .saved:
            Text("Your PNG is in Photos. Open the Tesla app to upload it.")
                .font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("photoSaveConfirmation")
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Text("Allow Tesla Car Wrap to add photos in Settings, then try again. You can also save to Files or share the PNG.")
                Button("Open Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
            }.font(.callout)
        case .failed(let message):
            Text("Could not save to Photos: \(message)").font(.callout).foregroundStyle(.red)
        case .ready, .saving:
            EmptyView()
        }
    }
}
