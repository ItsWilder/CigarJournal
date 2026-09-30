// CigarDetailView
// A full-screen photo with the cigar's details in a pull-up panel (a native sheet
// with detents). Favorite, edit, restock and delete live in the toolbar.

import SwiftData
import SwiftUI

/// Everything the details screen can present. They're presented from the panel,
/// since the panel is itself a sheet and only the top-most presenter can show another.
enum CigarDetailSheet: Identifiable {
    case edit
    case smoke
    case editSmoke(SmokeEntry)
    case restock
    case storeMap(StorePlace)
    case photo(AnyHashable)

    var id: String {
        switch self {
        case .edit: "edit"
        case .smoke: "smoke"
        case .editSmoke(let smoke): "smoke-\(smoke.id)"
        case .restock: "restock"
        case .storeMap(let place): "map-\(place.id)"
        case .photo(let photoID): "photo-\(photoID)"
        }
    }
}

struct CigarDetailView: View {
    let cigar: CigarTemplate
    /// The tab's navigation path, so the panel can close as soon as you go back.
    var navigation: CigarNavigation?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingPanel = true
    @State private var currentPhotoIndex: Int?
    @State private var activeSheet: CigarDetailSheet?
    @State private var confirmingDelete = false

    var body: some View {
        let gallery = cigar.gallery

        GeometryReader { proxy in
            if gallery.isEmpty {
                ZStack {
                    Color(.brown)
                        .onTapGesture {
                            activeSheet = .edit
                        }

                    // Near the top, in the part of the screen the panel doesn't cover.
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 64))
                        .foregroundStyle(.accentDark)
                        .position(x: proxy.size.width / 2, y: proxy.size.height * 0.3)
                        .allowsHitTesting(false)
                        .accessibilityLabel("Add photo")
                }
            } else {
                // Swipe sideways through every photo of this cigar.
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(gallery.indices, id: \.self) { index in
                            CigarPhotoView(photo: gallery[index].data, maxPointSize: 1200)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .contentShape(.rect)
                                .onTapGesture {
                                    activeSheet = .photo(gallery[index].id)
                                }
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentPhotoIndex)
                .scrollIndicators(.hidden)
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if gallery.count > 1 {
                ToolbarItem(placement: .topBarLeading) {
                    let index = min(currentPhotoIndex ?? 0, gallery.count - 1)
                    Button {
                        activeSheet = .photo(gallery[index].id)
                    } label: {
                        Text("\(index + 1) of \(gallery.count)")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityLabel("Photo \(index + 1) of \(gallery.count)")
                    .accessibilityHint("Opens the photo full screen")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(cigar.isFavorite ? "Unfavorite" : "Favorite", systemImage: cigar.isFavorite ? "heart.fill" : "heart") {
                    cigar.isFavorite.toggle()
                }
                .tint(cigar.isFavorite ? .red : nil)
                .symbolEffect(.bounce, value: cigar.isFavorite)
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Edit", systemImage: "square.and.pencil") {
                    activeSheet = .edit
                }
                Button("Add to Humidor", systemImage: "archivebox") {
                    activeSheet = .restock
                }
                Button("Delete", systemImage: "trash") {
                    confirmingDelete = true
                }
            }
        }
        .sheet(isPresented: $showingPanel) {
            CigarInfoPanel(
                cigar: cigar,
                activeSheet: $activeSheet,
                confirmingDelete: $confirmingDelete,
                onDelete: deleteCigar
            )
        }
        // Going back removes this cigar from the path right away; close the panel then,
        // rather than after the screen has finished leaving.
        .onChange(of: navigation?.path.contains(cigar) ?? true) { _, stillShown in
            if !stillShown {
                showingPanel = false
            }
        }
        .onDisappear {
            showingPanel = false
        }
    }

    private func deleteCigar() {
        showingPanel = false
        dismiss()
        // Delete after the screen is gone so nothing renders a deleted cigar.
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            modelContext.delete(cigar)
        }
    }
}

// MARK: - Panel

private struct CigarInfoPanel: View {
    let cigar: CigarTemplate
    @Binding var activeSheet: CigarDetailSheet?
    @Binding var confirmingDelete: Bool
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext

    /// Three stops: the summary, everything through the details grid, and full screen.
    private enum Stop { case summary, details, full }

    @State private var stop = Stop.summary
    @State private var summaryBottom: CGFloat = 170
    @State private var detailsBottom: CGFloat = 420
    @State private var buttonAreaHeight: CGFloat = 80

    private let topInset: CGFloat = 24
    private nonisolated static let contentSpace = "panelContent"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(cigar.name)
                        .font(.title.bold())
                    keyFacts
                }
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.contentSpace)).maxY } action: {
                    summaryBottom = $0
                }

                if !detailCells.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        Divider()
                        LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)], alignment: .leading, spacing: 16) {
                            ForEach(detailCells) { $0 }
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.contentSpace)).maxY } action: {
                        detailsBottom = $0
                    }
                }

                if let place = cigar.storePlace {
                    StoreMapCard(place: place) {
                        activeSheet = .storeMap(place)
                    }
                }

                smokesSection
            }
            .padding(.horizontal)
            .padding(.top, topInset)
            // Measure against the content (which scrolls with it), so detents don't move while scrolling.
            .coordinateSpace(.named(Self.contentSpace))
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                activeSheet = .smoke
            } label: {
                Text(cigar.hasBeenSmoked ? "Smoke Again" : "Smoke")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.accent)
            .padding(.horizontal)
            .padding(.vertical, 8)
            // Solid behind the button so the next section doesn't peek out beneath it.
            .background(.background)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                buttonAreaHeight = $0
            }
        }
        .presentationDetents(Set(detents), selection: stopBinding)
        .presentationBackgroundInteraction(.enabled(upThrough: detent(for: .details)))
        .presentationDragIndicator(.visible)
        // Solid rather than the default see-through glass, so text stays readable over photos.
        .presentationBackground(.background)
        .interactiveDismissDisabled()
        .onChange(of: confirmingDelete) { _, confirming in
            if confirming { stop = .summary }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .edit: AddCigar(editCigar: cigar)
            case .smoke: SmokeSheet(cigar: cigar)
            case .editSmoke(let smoke): SmokeSheet(cigar: cigar, editing: smoke)
            case .restock: RestockSheet(cigar: cigar)
            case .storeMap(let place): StoresMapView(focus: place)
            case .photo(let photoID): PhotoViewer(cigar: cigar, startAt: photoID)
            }
        }
        .confirmationDialog("Delete \(cigar.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("This deletes the cigar and all its smokes, including from iCloud on all your devices.")
        }
    }

    // MARK: Detents

    private var detents: [PresentationDetent] {
        detailCells.isEmpty ? [detent(for: .summary), .large] : [detent(for: .summary), detent(for: .details), .large]
    }

    /// Heights come from measuring the content, plus the drag indicator and the button.
    private func detent(for stop: Stop) -> PresentationDetent {
        switch stop {
        case .summary: .height(summaryBottom + buttonAreaHeight + 12)
        case .details: detailCells.isEmpty ? .large : .height(detailsBottom + buttonAreaHeight + 12)
        case .full: .large
        }
    }

    private var stopBinding: Binding<PresentationDetent> {
        Binding(
            get: { detent(for: stop) },
            set: { newValue in
                stop = [Stop.summary, .details, .full].first { detent(for: $0) == newValue } ?? .summary
            }
        )
    }

    // MARK: Key facts

    private var keyFacts: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 12) {
            KeyFact(title: "Strength", systemImage: "chart.bar.fill", value: cigar.strength)
            KeyFact(title: "Size", systemImage: "arrow.left.and.right", value: "\(cigar.length) x \(cigar.gauge)")
            KeyFact(title: "Last Smoked", systemImage: "calendar", value: lastSmokedText)
            if cigar.humidorCount > 0 {
                KeyFact(title: "Humidor", systemImage: "archivebox.fill", value: "\(cigar.humidorCount)")
            }
            if cigar.smokeCount > 1 {
                Label("Smoked \(cigar.smokeCount)x", systemImage: "medal")
                    .foregroundStyle(.accent)
            }
        }
        .font(.body)
    }

    private var lastSmokedText: String {
        if let lastSmoked = cigar.lastSmoked {
            return lastSmoked.formatted(date: .numeric, time: .omitted)
        }
        return cigar.humidorCount > 0 ? "In Humidor" : "Not yet"
    }

    // MARK: Details grid (blank fields are left out)

    private var detailCells: [DetailCell] {
        var cells: [DetailCell] = []
        func add(_ title: String, _ icon: String, _ value: String?) {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
            cells.append(DetailCell(title: title, systemImage: icon, value: .text(value)))
        }
        add("Store", "storefront", cigar.displayLocation)
        add("Price", "banknote", cigar.displayPrice)
        if let average = cigar.averageRating {
            cells.append(DetailCell(title: "Rating", systemImage: "star.circle", value: .stars(average)))
        }
        add("Type", "shippingbox", cigar.type)
        add("Wrapper", "leaf", cigar.wrapper)
        add("Binder", "square.stack.3d.up", cigar.binder)
        add("Filler", "square.3.layers.3d", cigar.filler)
        add("Origin", "globe.americas", cigar.origin)
        return cells
    }

    // MARK: Notes and smoke history

    @ViewBuilder
    private var smokesSection: some View {
        let smokes = cigar.smokes

        if smokes.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Smokes")
                    .font(.headline)
                ForEach(smokes) { smoke in
                    SmokeRow(
                        smoke: smoke,
                        photos: cigar.photos(for: smoke),
                        onEdit: { activeSheet = .editSmoke(smoke) },
                        onPhoto: { activeSheet = .photo($0) }
                    )
                    if smoke.id != smokes.last?.id {
                        Divider()
                    }
                }
            }
        } else if let smoke = smokes.first, !smoke.notes.isEmpty || !cigar.photos(for: smoke).isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    activeSheet = .editSmoke(smoke)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        if !smoke.notes.isEmpty {
                            Text(smoke.notes)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Edit notes")

                let photos = cigar.photos(for: smoke)
                if !photos.isEmpty {
                    PhotoThumbnailRow(photos: photos) { activeSheet = .photo($0) }
                }
            }
        }
    }
}

private struct KeyFact: View {
    let title: String
    let systemImage: String
    let value: String

    var body: some View {
        Label {
            Text("\(Text("\(title): ").foregroundStyle(.accent))\(Text(value).fontWeight(.semibold))")
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.accent)
        }
    }
}

private struct DetailCell: View, Identifiable {
    enum Value {
        case text(String)
        case stars(Double)
    }

    let title: String
    let systemImage: String
    let value: Value

    var id: String { title }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            switch value {
            case .text(let text):
                Text(text)
                    .foregroundStyle(.accent)
            case .stars(let average):
                StarRating(average: average)
                    .font(.subheadline)
            }
        }
    }
}

private struct SmokeRow: View {
    let smoke: SmokeEntry
    let photos: [CigarPhoto]
    let onEdit: () -> Void
    let onPhoto: (AnyHashable) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onEdit) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(smoke.date, format: .dateTime.month().day().year())
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            StarRating(rating: smoke.rating)
                                .font(.caption)
                        }
                        if !smoke.notes.isEmpty {
                            Text(smoke.notes)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit this smoke")

            if !photos.isEmpty {
                PhotoThumbnailRow(photos: photos, onPhoto: onPhoto)
            }
        }
    }
}

/// Small thumbnails of a smoke's photos; tap one to open it full screen.
private struct PhotoThumbnailRow: View {
    let photos: [CigarPhoto]
    let onPhoto: (AnyHashable) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(photos) { photo in
                    Button {
                        onPhoto(photo.persistentModelID)
                    } label: {
                        CigarPhotoView(photo: photo.data, maxPointSize: 56)
                            .frame(width: 56, height: 56)
                            .clipShape(.rect(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Photo")
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Full screen photos

/// Full-screen photos you can swipe through, each with pinch and double-tap zoom.
private struct PhotoViewer: View {
    let cigar: CigarTemplate
    /// Kept in state (not re-read from the cigar) so making a different photo the key
    /// doesn't reshuffle what you're looking at.
    @State private var photos: [GalleryPhoto]

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int?

    init(cigar: CigarTemplate, startAt photoID: AnyHashable) {
        self.cigar = cigar
        let photos = cigar.gallery
        _photos = State(initialValue: photos)
        _currentIndex = State(initialValue: photos.firstIndex { $0.id == photoID } ?? 0)
    }

    private var current: GalleryPhoto? {
        photos.isEmpty ? nil : photos[min(currentIndex ?? 0, photos.count - 1)]
    }

    private var currentIsKey: Bool {
        current.map { $0.id == cigar.gallery.first?.id } ?? false
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(photos.indices, id: \.self) { index in
                        ZoomablePhoto(data: photos[index].data)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentIndex)
            .scrollIndicators(.hidden)
        }
        .background(.black)
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            HStack {
                if photos.count > 1 {
                    let index = min(currentIndex ?? 0, photos.count - 1)
                    Text("\(index + 1) of \(photos.count)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .glassEffect(.regular, in: .capsule)
                }
                Spacer()
                if photos.count > 1, let current {
                    Button(currentIsKey ? "Key Photo" : "Make Key Photo", systemImage: currentIsKey ? "key.fill" : "key") {
                        cigar.makeKeyPhoto(current.record)
                    }
                    .buttonStyle(.glass)
                    .disabled(currentIsKey)
                }
                Button("Close", systemImage: "xmark", role: .close) {
                    dismiss()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
            }
            .padding()
        }
        .presentationDetents([.large])
    }
}

private struct ZoomablePhoto: View {
    let data: Data

    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        CigarPhotoView(photo: data, maxPointSize: 1800, contentMode: .fit, background: .black)
            .scaleEffect(zoom * pinch)
            .gesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { value in zoom = min(max(zoom * value.magnification, 1), 5) }
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy) { zoom = zoom > 1 ? 1 : 2.5 }
            }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: CigarTemplate.self, SmokeSession.self, CigarPhoto.self, configurations: config)
        let cigar = CigarTemplate(name: "La Flor Dominicana 1994", type: "Toro", length: "6.00", gauge: "52", location: "Smoke on the Water", price: "11", strength: "Medium", rating: 4, notes: "A great cigar. Mild and easy going.", date: .now)
        cigar.wrapper = "Maduro"
        cigar.origin = "Dominican"
        cigar.humidorCount = 5
        container.mainContext.insert(cigar)

        return NavigationStack {
            CigarDetailView(cigar: cigar)
        }
        .modelContainer(container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
