import SwiftUI

@main
struct WrapStudioApp: App {
    init() {
        #if DEBUG
        // UI tests start from an empty library: `-resetLibrary`.
        if ProcessInfo.processInfo.arguments.contains("-resetLibrary") {
            let documents = URL.documentsDirectory
            for folder in ["Designs", "Stickers", "Wrap Studio Autosaves"] {
                try? FileManager.default.removeItem(at: documents.appending(path: folder))
            }
            UserDefaults.standard.removeObject(forKey: "recentColors")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
