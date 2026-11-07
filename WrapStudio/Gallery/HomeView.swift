import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var library: DesignLibrary
    @Binding var path: [DesignRecord]
    @State private var renaming: DesignRecord?
    @State private var renameText = ""
    @State private var deleting: DesignRecord?
    @State private var showingCatalog = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header
                if !library.hasLoaded {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 60)
                } else if library.records.isEmpty {
                    VehicleCatalog(title: "CHOOSE YOUR CANVAS", onSelect: open)
                } else {
                    designs
                    VehicleCatalog(title: "START A NEW WRAP", onSelect: open)
                }
                footer
            }
            .padding(.horizontal, 20).padding(.vertical, 22)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingCatalog) {
            NavigationStack {
                ScrollView {
                    VehicleCatalog(title: "CHOOSE YOUR VEHICLE") { car in
                        showingCatalog = false
                        open(car)
                    }
                    .padding(20)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("New wrap").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingCatalog = false } } }
            }
        }
        .alert("Rename design", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Save") {
                if let renaming { library.rename(renaming, to: renameText) }
                renaming = nil
            }
        }
        .confirmationDialog("Delete this design?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { record in
            Button("Delete “\(record.name)”", role: .destructive) { library.delete(record) }
        } message: { _ in Text("This can’t be undone. PNGs you already exported are not affected.") }
        .alert("Something needs attention", isPresented: Binding(
            get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } }
        )) {
            Button("OK") { library.errorMessage = nil }
        } message: { Text(library.errorMessage ?? "") }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Label("WRAP STUDIO", systemImage: "paintpalette.fill")
                    .font(.caption.weight(.heavy)).tracking(2).foregroundStyle(StudioStyle.accent)
                Text(library.records.isEmpty ? "Your Tesla.\nYour signature." : "Your wraps")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                if library.records.isEmpty {
                    Text("Paint, fill panels, add photos and lettering, then upload it to your Tesla.")
                        .font(.body).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            if !library.records.isEmpty {
                Button { showingCatalog = true } label: {
                    Label("New wrap", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                .accessibilityIdentifier("newWrap")
            }
        }
        .padding(.top, 8)
    }

    private var designs: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 158, maximum: 260), spacing: 14)], spacing: 14) {
            ForEach(library.records) { record in
                DesignCard(record: record, thumbnail: library.thumbnails[record.id]) {
                    path.append(record)
                } rename: {
                    renameText = record.name
                    renaming = record
                } duplicate: {
                    library.duplicate(record)
                } delete: {
                    deleting = record
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Saved on this device. No account, no tracking.", systemImage: "lock.shield")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Wraps change your Tesla’s on-screen vehicle visualization. Pick the body style that matches your vehicle.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func open(_ car: Car) {
        guard let record = library.create(car: car) else { return }
        Haptics.tap()
        path.append(record)
    }
}

private struct DesignCard: View {
    let record: DesignRecord
    let thumbnail: UIImage?
    let open: () -> Void
    let rename: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Color.white
                    if let thumbnail {
                        Image(uiImage: thumbnail).resizable().scaledToFit().padding(6)
                    } else {
                        Image(uiImage: UIImage(named: record.car.template) ?? UIImage())
                            .resizable().scaledToFit().padding(6).opacity(0.5)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.06)) }

                VStack(alignment: .leading, spacing: 3) {
                    Text(record.name).font(.headline).lineLimit(1)
                    Text(record.car.fullName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text("Edited \(record.modifiedAt.formatted(.relative(presentation: .named)))")
                        .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
                .padding(.horizontal, 4)
            }
            .padding(10)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(record.name), \(record.car.fullName)")
        .accessibilityHint("Opens the design")
        .accessibilityIdentifier("design-\(record.name)")
        .contextMenu { menuItems }
        .overlay(alignment: .topTrailing) {
            Menu { menuItems } label: {
                Image(systemName: "ellipsis")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    .background(.regularMaterial, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(record.name)")
            .padding(10)
        }
    }

    @ViewBuilder private var menuItems: some View {
        Button(action: rename) { Label("Rename", systemImage: "pencil") }
        Button(action: duplicate) { Label("Duplicate", systemImage: "plus.square.on.square") }
        Button(role: .destructive, action: delete) { Label("Delete", systemImage: "trash") }
    }
}
