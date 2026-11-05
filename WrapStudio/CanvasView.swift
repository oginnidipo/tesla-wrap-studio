import SwiftUI

struct CanvasView: View {
    @StateObject private var session: EditorSession
    @State private var showingStickers = false
    @State private var showingClearConfirmation = false
    @State private var export: ExportedWrap?
    @Environment(\.scenePhase) private var scenePhase

    init(car: Car) {
        _session = StateObject(wrappedValue: EditorSession(car: car))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(session.saveStatus, systemImage: session.saveStatus == "All changes saved" ? "checkmark.circle" : "icloud")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("saveStatus")
                Spacer()
                Text(session.car.dimensions).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)

            PaintCanvas(session: session)
                .padding(.horizontal, 12)
                .accessibilityIdentifier("paintCanvas")

            Text(session.selectedStickerID == nil
                 ? "Draw with your finger or Apple Pencil."
                 : "Drag to move. Pinch to resize. Tap × to remove.")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal).padding(.vertical, 10)

            EditorControls(session: session, showingStickers: $showingStickers)
            Button(action: prepareExport) {
                Label("Export PNG", systemImage: "square.and.arrow.up")
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(!session.hasArtwork)
            .accessibilityIdentifier("exportPNG")
            .padding(.horizontal, 18).padding(.top, 6).padding(.bottom, 12)
            .background(.bar)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(session.car.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: session.undo) { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .disabled(!session.canUndo).accessibilityIdentifier("undo")
                Button(action: session.redo) { Label("Redo", systemImage: "arrow.uturn.forward") }
                    .disabled(!session.canRedo).accessibilityIdentifier("redo")
                Menu {
                    Button(role: .destructive) { showingClearConfirmation = true } label: { Label("Clear design", systemImage: "trash") }
                        .disabled(!session.hasArtwork)
                } label: { Label("More", systemImage: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showingStickers) { StickerSheet(session: session) }
        .sheet(item: $export) { wrap in ExportPanel(car: session.car, wrap: wrap) }
        .confirmationDialog("Clear this design?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button("Clear design", role: .destructive, action: session.clear)
        } message: { Text("This clears paint, fill, and stickers. You can undo it while this editor is open.") }
        .alert("Something needs attention", isPresented: Binding(
            get: { session.errorMessage != nil }, set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK") { session.errorMessage = nil }
        } message: { Text(session.errorMessage ?? "") }
        .task(id: scenePhase) {
            if scenePhase != .active { session.persistNow() }
        }
        .onDisappear(perform: session.persistNow)
    }

    private func prepareExport() {
        session.selectedStickerID = nil
        session.persistNow()
        do { export = try WrapRenderer.export(session: session) }
        catch { session.errorMessage = error.localizedDescription }
    }
}
