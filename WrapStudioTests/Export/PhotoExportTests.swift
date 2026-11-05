import Testing
import UIKit
@testable import Tesla_Car_Wrap

@MainActor struct PhotoExportTests {
    private var wrap: ExportedWrap {
        ExportedWrap(image: UIImage(), pngData: Data([137, 80, 78, 71, 13, 10, 26, 10]),
                     fileURL: URL(filePath: "/tmp/m3-wrap.png"))
    }

    @Test func deniedPermissionDoesNotWrite() async {
        var wrote = false
        let model = PhotoExportModel(writer: PhotoLibraryWriter(requestAccess: { false }, savePNG: { _, _ in wrote = true }))
        await model.save(wrap)
        #expect(model.state == .denied)
        #expect(!wrote)
    }

    @Test func savesExactPNGAndPreventsDuplicates() async {
        var saved: [(Data, String)] = []
        let model = PhotoExportModel(writer: PhotoLibraryWriter(requestAccess: { true }, savePNG: { saved.append(($0, $1)) }))
        await model.save(wrap)
        await model.save(wrap)
        #expect(model.state == .saved)
        #expect(saved.count == 1)
        #expect(saved.first?.0 == wrap.pngData)
        #expect(saved.first?.1 == "m3-wrap.png")
    }

    @Test func failedWriteCanBeRetried() async {
        var attempts = 0
        let model = PhotoExportModel(writer: PhotoLibraryWriter(requestAccess: { true }, savePNG: { _, _ in
            attempts += 1
            if attempts == 1 { throw CocoaError(.fileWriteOutOfSpace) }
        }))
        await model.save(wrap)
        guard case .failed = model.state else { Issue.record("Expected save failure"); return }
        await model.save(wrap)
        #expect(model.state == .saved)
        #expect(attempts == 2)
    }
}
