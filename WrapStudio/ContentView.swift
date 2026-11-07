import SwiftUI

struct ContentView: View {
    @StateObject private var library = DesignLibrary()
    @State private var path: [DesignRecord] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: DesignRecord.self) { record in
                    EditorView(record: record, store: library.store)
                }
        }
        .environmentObject(library)
        .tint(StudioStyle.accent)
        .task { await library.load() }
    }
}

#Preview { ContentView() }
