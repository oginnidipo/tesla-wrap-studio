import SwiftUI

struct EditorView: View {
    @StateObject private var session: EditorSession
    @EnvironmentObject private var library: DesignLibrary
    @State private var showingStickers = false
    @State private var showingText = false
    @State private var showingClearConfirmation = false
    @State private var showingRename = false
    @State private var renameText = ""
    @State private var export: ExportedWrap?
    @Environment(\.scenePhase) private var scenePhase

    init(record: DesignRecord, store: DesignStore) {
        _session = StateObject(wrappedValue: EditorSession(record: record, store: store))
    }

    var body: some View {
        GeometryReader { geometry in
            // Landscape iPhone and iPad keep the canvas large and move controls to the side.
            if geometry.size.width > geometry.size.height * 1.1 && geometry.size.width >= 640 {
                HStack(spacing: 0) {
                    canvasColumn
                    Divider().ignoresSafeArea()
                    VStack(spacing: 0) {
                        ScrollView { controls }
                        exportButton
                    }
                    .frame(width: min(400, geometry.size.width * 0.42))
                    .background(.bar)
                }
            } else {
                VStack(spacing: 0) {
                    canvasColumn
                    VStack(spacing: 0) {
                        controls
                        exportButton
                    }
                    .background(.bar)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingStickers) { StickerSheet(session: session) }
        .sheet(isPresented: $showingText) { TextStickerSheet(session: session) }
        .sheet(item: $export) { wrap in ExportPanel(car: session.car, designName: session.record.name, wrap: wrap) }
        .confirmationDialog("Clear this design?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button("Clear design", role: .destructive, action: session.clear)
        } message: { Text("This clears paint, fills, and stickers. You can undo it while this editor is open.") }
        .alert("Rename design", isPresented: $showingRename) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") { session.rename(to: renameText) }
        } message: { Text("This name is also used for the PNG you upload to your Tesla.") }
        .alert("Something needs attention", isPresented: Binding(
            get: { session.errorMessage != nil }, set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK") { session.errorMessage = nil }
        } message: { Text(session.errorMessage ?? "") }
        .onAppear {
            let library = library
            session.onRecordChange = { [weak library] record in library?.update(record) }
            session.onThumbnailChange = { [weak library] id, png in library?.updateThumbnail(png, for: id) }
        }
        .task(id: scenePhase) {
            if scenePhase != .active { session.close() }
        }
        .onDisappear {
            session.close()
            library.editorClosed(session.record, hasArtwork: session.hasArtwork)
        }
    }

    // MARK: Canvas

    private var canvasColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label(session.saveState.title, systemImage: session.saveState.symbol)
                    .font(.caption).foregroundStyle(session.saveState == .failed ? .red : .secondary)
                    .accessibilityIdentifier("saveStatus")
                Spacer()
                Text(session.car.dimensions).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                mirrorToggle
            }
            .padding(.horizontal, 18).padding(.vertical, 8)

            PaintCanvas(session: session)
                .padding(.horizontal, 12)
                .accessibilityIdentifier("paintCanvas")
                .overlay(alignment: .top) {
                    if let notice = session.notice {
                        Text(notice)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                            .padding(.top, 10)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .accessibilityIdentifier("notice")
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: session.notice)

            Text(hint)
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal).padding(.vertical, 8)
                .frame(maxWidth: .infinity)
        }
    }

    private var mirrorToggle: some View {
        Button {
            session.isMirroring.toggle()
            Haptics.select()
        } label: {
            Label("Mirror", systemImage: session.car.mirrorAxis.isVertical
                  ? "arrow.left.and.right.righttriangle.left.righttriangle.right"
                  : "arrow.up.and.down.righttriangle.up.righttriangle.down")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .foregroundStyle(session.isMirroring ? Color.white : Color.primary)
                .background(session.isMirroring ? StudioStyle.accent : Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel("Mirror both sides")
        .accessibilityAddTraits(session.isMirroring ? .isSelected : [])
        .accessibilityIdentifier("mirrorToggle")
    }

    private var hint: String {
        if session.selectedStickerID != nil { return "Drag to move. Pinch to resize. Twist to rotate." }
        switch session.tool {
        case .fill:
            return session.isMirroring ? "Tap a panel to fill it and its twin. Tap again to clear."
                                       : "Tap a panel to fill it. Tap again to clear."
        case .eraser:
            return "Erase paint strokes. Fills and stickers stay put."
        case .pen, .marker:
            return session.isMirroring ? "Each stroke is mirrored to the other side."
                                       : "Draw with your finger or Apple Pencil."
        }
    }

    // MARK: Controls

    private var controls: some View {
        EditorControls(session: session, showingStickers: $showingStickers, showingText: $showingText)
    }

    private var exportButton: some View {
        Button(action: prepareExport) {
            Label("Export PNG", systemImage: "square.and.arrow.up")
                .font(.headline).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent).controlSize(.large)
        .disabled(!session.hasArtwork)
        .keyboardShortcut("e", modifiers: .command)
        .accessibilityIdentifier("exportPNG")
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12)
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Button {
                renameText = session.record.name
                showingRename = true
            } label: {
                VStack(spacing: 1) {
                    Text(session.record.name).font(.headline).lineLimit(1)
                    Text(session.car.fullName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                .foregroundStyle(Color.primary)
            }
            .accessibilityLabel("\(session.record.name), \(session.car.fullName)")
            .accessibilityHint("Rename this design")
            .accessibilityIdentifier("designTitle")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: session.undo) { Label("Undo", systemImage: "arrow.uturn.backward") }
                .disabled(!session.canUndo)
                .keyboardShortcut("z", modifiers: .command)
                .accessibilityIdentifier("undo")
            Button(action: session.redo) { Label("Redo", systemImage: "arrow.uturn.forward") }
                .disabled(!session.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .accessibilityIdentifier("redo")
            Menu {
                Button {
                    renameText = session.record.name
                    showingRename = true
                } label: { Label("Rename", systemImage: "pencil") }
                Button(role: .destructive) { showingClearConfirmation = true } label: { Label("Clear design", systemImage: "trash") }
                    .disabled(!session.hasArtwork)
            } label: { Label("More", systemImage: "ellipsis.circle") }
        }
    }

    private func prepareExport() {
        session.selectedStickerID = nil
        session.persistNow()
        do { export = try WrapRenderer.export(session: session) }
        catch { session.errorMessage = error.localizedDescription }
    }
}
