import PhotosUI
import SwiftUI

struct StickerSheet: View {
    @ObservedObject var session: EditorSession
    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem?
    @State private var names: [String] = []
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Make it personal.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Add a photo, a drawing, or a favorite character. Stickers stay inside the paintable body.")
                        .foregroundStyle(.secondary)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Import a photo", systemImage: "photo.badge.plus")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(isImporting)
                    if isImporting { ProgressView("Importing photo…").frame(maxWidth: .infinity) }
                    if let errorMessage { Text(errorMessage).font(.callout).foregroundStyle(.red) }
                    if names.isEmpty && !isImporting {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled").font(.largeTitle)
                            Text("Your sticker collection starts here.").font(.headline)
                            Text("Imported photos are kept on this device.").font(.footnote)
                        }
                        .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 16) {
                        ForEach(names, id: \.self) { name in
                            Button { session.addSticker(named: name); dismiss() } label: {
                                if let image = session.stickerLibrary.image(named: name) {
                                    Image(uiImage: image).resizable().scaledToFit()
                                        .frame(height: 100).frame(maxWidth: .infinity)
                                        .padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                                }
                            }.accessibilityLabel("Add saved photo sticker")
                        }
                    }
                }.padding(22)
            }
            .navigationTitle("Stickers").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { names = session.stickerLibrary.names() }
            .task(id: photoItem) { await importPhoto() }
        }
    }

    private func importPhoto() async {
        guard let photoItem else { return }
        isImporting = true
        errorMessage = nil
        defer { isImporting = false; self.photoItem = nil }
        do {
            guard let data = try await photoItem.loadTransferable(type: Data.self) else { throw StudioError.unreadableImage }
            try Task.checkCancellation()
            let name = try session.stickerLibrary.importPhoto(data)
            session.addSticker(named: name)
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
