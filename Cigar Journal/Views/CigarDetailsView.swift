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
    case photo

    var id: String {
        switch self {
        case .edit: "edit"
        case .smoke: "smoke"
        case .editSmoke(let smoke): "smoke-\(smoke.id)"
        case .restock: "restock"
        case .storeMap(let place): "map-\(place.id)"
        case .photo: "photo"
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
    @State private var activeSheet: CigarDetailSheet?
    @State private var confirmingDelete = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if cigar.photo != nil {
                    CigarPhotoView(photo: cigar.photo, maxPointSize: 1200)
                        .onTapGesture {
                            activeSheet = .photo
                        }
                } else {
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
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
            case .photo: FullScreenPhoto(photo: cigar.photo)
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
                    Button {
                        activeSheet = .editSmoke(smoke)
                    } label: {
                        SmokeRow(smoke: smoke)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit this smoke")
                    if smoke.id != smokes.last?.id {
                        Divider()
                    }
                }
            }
        } else if let smoke = smokes.first, !smoke.notes.isEmpty {
            Button {
                activeSheet = .editSmoke(smoke)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                    Text(smoke.notes)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit notes")
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

    var body: some View {
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
}

// MARK: - Full screen photo

private struct FullScreenPhoto: View {
    let photo: Data?

    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        CigarPhotoView(photo: photo, maxPointSize: 1800, contentMode: .fit, background: .black)
            .scaleEffect(zoom * pinch)
            .gesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { value in zoom = min(max(zoom * value.magnification, 1), 5) }
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy) { zoom = zoom > 1 ? 1 : 2.5 }
            }
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                Button(role: .close) {
                    dismiss()
                }
                .buttonStyle(.glass)
                .padding()
            }
            .presentationDetents([.large])
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: CigarTemplate.self, SmokeSession.self, configurations: config)
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
