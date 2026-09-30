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
    case restock
    case storeMap(StorePlace)
    case photo

    var id: String {
        switch self {
        case .edit: "edit"
        case .smoke: "smoke"
        case .restock: "restock"
        case .storeMap(let place): "map-\(place.id)"
        case .photo: "photo"
        }
    }
}

struct CigarDetailView: View {
    let cigar: CigarTemplate

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingPanel = true
    @State private var detent = Self.peekDetent
    @State private var activeSheet: CigarDetailSheet?
    @State private var confirmingDelete = false

    static let peekDetent = PresentationDetent.fraction(0.45)

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

                    // Centered in the part of the screen the panel doesn't cover.
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
                    detent = Self.peekDetent
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
            .presentationDetents([Self.peekDetent, .large], selection: $detent)
            .presentationBackgroundInteraction(.enabled(upThrough: Self.peekDetent))
            .presentationDragIndicator(.visible)
            // Solid rather than the default see-through glass, so text stays readable
            // over busy photos.
            .presentationBackground(.background)
            .interactiveDismissDisabled()
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(cigar.name)
                    .font(.title.bold())

                keyFacts

                Divider()

                LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)], alignment: .leading, spacing: 16) {
                    DetailCell(title: "Store", systemImage: "storefront", value: cigar.displayLocation)
                    DetailCell(title: "Price", systemImage: "banknote", value: cigar.displayPrice)
                    DetailCell(title: "Rating", systemImage: "star.circle") {
                        if let average = cigar.averageRating {
                            StarRating(average: average)
                                .font(.subheadline)
                        } else {
                            Text("Not smoked yet")
                                .foregroundStyle(.secondary)
                        }
                    }
                    DetailCell(title: "Type", systemImage: "shippingbox", value: cigar.type)
                    DetailCell(title: "Wrapper", systemImage: "leaf", value: cigar.wrapper)
                    DetailCell(title: "Binder", systemImage: "square.stack.3d.up", value: cigar.binder)
                    DetailCell(title: "Filler", systemImage: "square.3.layers.3d", value: cigar.filler)
                    DetailCell(title: "Origin", systemImage: "globe.americas", value: cigar.origin)
                }

                if let place = cigar.storePlace {
                    StoreMapCard(place: place) {
                        activeSheet = .storeMap(place)
                    }
                }

                smokesSection
            }
            .padding(.horizontal)
            .padding(.top, 24)
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
            .padding(.bottom, 8)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .edit: AddCigar(editCigar: cigar)
            case .smoke: SmokeSheet(cigar: cigar)
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

    // MARK: Notes and smoke history

    @ViewBuilder
    private var smokesSection: some View {
        let smokes = cigar.smokes

        if smokes.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Smokes")
                    .font(.headline)
                ForEach(smokes) { smoke in
                    SmokeRow(smoke: smoke)
                        .contextMenu {
                            if let session = smoke.session {
                                Button("Delete This Smoke", systemImage: "trash", role: .destructive) {
                                    modelContext.delete(session)
                                }
                            }
                        }
                    if smoke.id != smokes.last?.id {
                        Divider()
                    }
                }
            }
        } else if let notes = cigar.latestNotes {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.headline)
                Text(notes)
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

private struct DetailCell<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content
                .foregroundStyle(.accent)
        }
    }
}

extension DetailCell where Content == Text {
    init(title: String, systemImage: String, value: String?) {
        self.init(title: title, systemImage: systemImage) {
            Text(value.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? "—")
        }
    }
}

private struct SmokeRow: View {
    let smoke: SmokeEntry

    var body: some View {
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
            }
        }
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
