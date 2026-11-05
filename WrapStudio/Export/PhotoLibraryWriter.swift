import Photos
import UniformTypeIdentifiers

/// Writes the validated PNG bytes directly, avoiding a JPEG conversion through UIImage.
struct PhotoLibraryWriter {
    var requestAccess: @MainActor () async -> Bool
    var savePNG: @MainActor (Data, String) async throws -> Void

    static let live = PhotoLibraryWriter(
        requestAccess: {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return status == .authorized || status == .limited
        },
        savePNG: { data, filename in
            // PhotoKit executes this callback on its own transaction queue. Explicit
            // Sendable isolation prevents inheriting the caller's MainActor executor.
            try await PHPhotoLibrary.shared().performChanges { @Sendable in
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = filename
                options.uniformTypeIdentifier = UTType.png.identifier
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: options)
            }
        }
    )
}
