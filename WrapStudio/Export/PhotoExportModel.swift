import Combine
import Foundation

@MainActor final class PhotoExportModel: ObservableObject {
    enum State: Equatable {
        case ready, saving, saved, denied, failed(String)
    }

    @Published private(set) var state = State.ready
    private let writer: PhotoLibraryWriter

    init(writer: PhotoLibraryWriter = .live) { self.writer = writer }

    func save(_ wrap: ExportedWrap) async {
        guard state != .saving, state != .saved else { return }
        state = .saving
        guard await writer.requestAccess() else {
            state = .denied
            return
        }
        do {
            try await writer.savePNG(wrap.pngData, wrap.fileURL.lastPathComponent)
            state = .saved
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
