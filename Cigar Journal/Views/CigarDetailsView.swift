// CigarDetails
// Swipe left and right through cigars in the same order and filter as the list.

import SwiftData
import SwiftUI

struct CigarDetails: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCigars: [CigarTemplate]

    let sortOption: CigarSortOption
    let searchText: String
    let zoomNamespace: Namespace.ID
    private let initialID: PersistentIdentifier

    @State private var selectedID: PersistentIdentifier?
    @State private var isShowingEditSheet = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingFullImage = false

    private let maxVisibleDots = 5

    init(initialCigar: CigarTemplate, sortOption: CigarSortOption, searchText: String, zoomNamespace: Namespace.ID) {
        self.sortOption = sortOption
        self.searchText = searchText
        self.zoomNamespace = zoomNamespace
        self.initialID = initialCigar.persistentModelID
        _selectedID = State(initialValue: initialCigar.persistentModelID)
    }

    var body: some View {
        let cigars = sortOption.visibleCigars(allCigars, matching: searchText)
        let selectedCigar = cigars.first { $0.persistentModelID == selectedID }

        TabView(selection: $selectedID) {
            ForEach(cigars) { cigar in
                CigarDetailPage(cigar: cigar) {
                    isShowingFullImage = true
                }
                .tag(Optional(cigar.persistentModelID))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTransition(.zoom(sourceID: initialID, in: zoomNamespace))
        // An overlay, not a safe-area inset, so the page scrolls underneath the glass dots.
        .overlay(alignment: .bottom) {
            if cigars.count > 1 {
                pageDots(for: cigars)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    isShowingEditSheet = true
                }
                .disabled(selectedCigar == nil)
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    isShowingDeleteConfirmation = true
                }
                .disabled(selectedCigar == nil)
                .confirmationDialog(
                    "Delete \(selectedCigar?.name ?? "Cigar")?",
                    isPresented: $isShowingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        delete(selectedCigar, from: cigars)
                    }
                } message: {
                    Text("This also removes it from iCloud on all your devices.")
                }
            }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            if let selectedCigar {
                AddCigar(editCigar: selectedCigar)
            }
        }
        .fullScreenCover(isPresented: $isShowingFullImage) {
            FullScreenPhoto(photo: selectedCigar?.photo)
        }
        .onChange(of: cigars.map(\.persistentModelID)) { _, ids in
            // The shown cigar disappeared (deleted elsewhere, or no longer matches the search).
            if let selectedID, !ids.contains(selectedID) {
                if let first = ids.first {
                    self.selectedID = first
                } else {
                    dismiss()
                }
            }
        }
    }

    private func delete(_ cigar: CigarTemplate?, from cigars: [CigarTemplate]) {
        guard let cigar, let index = cigars.firstIndex(of: cigar) else { return }
        let remaining = cigars.filter { $0 != cigar }

        if remaining.isEmpty {
            dismiss()
        } else {
            selectedID = remaining[min(index, remaining.count - 1)].persistentModelID
        }
        modelContext.delete(cigar)
    }

    private func pageDots(for cigars: [CigarTemplate]) -> some View {
        let selectedIndex = cigars.firstIndex { $0.persistentModelID == selectedID } ?? 0
        let visible = visibleDotIndices(count: cigars.count, selectedIndex: selectedIndex)

        return HStack(spacing: 8) {
            if let first = visible.first, first > 0 {
                edgeDot
            }
            ForEach(visible, id: \.self) { index in
                let isSelected = index == selectedIndex
                Circle()
                    .fill(isSelected ? Color.primary : Color.secondary.opacity(0.35))
                    .frame(width: isSelected ? 9 : 7, height: isSelected ? 9 : 7)
            }
            if let last = visible.last, last < cigars.count - 1 {
                edgeDot
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .padding(.bottom, 8)
        .accessibilityElement()
        .accessibilityLabel("Cigar \(selectedIndex + 1) of \(cigars.count)")
    }

    private var edgeDot: some View {
        Circle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 5, height: 5)
    }

    private func visibleDotIndices(count: Int, selectedIndex: Int) -> [Int] {
        guard count > maxVisibleDots else { return Array(0..<count) }
        let start = min(max(0, selectedIndex - maxVisibleDots / 2), count - maxVisibleDots)
        return Array(start..<(start + maxVisibleDots))
    }
}

// MARK: - Page

private struct CigarDetailPage: View {
    let cigar: CigarTemplate
    let showFullImage: () -> Void

    @State private var mapFocus: StorePlace?

    private var sizeLine: String {
        "\(cigar.type)  /  \(cigar.length)\" x \(cigar.gauge)  /  \(cigar.strength)"
    }

    private var purchaseLine: String? {
        let parts = [cigar.displayLocation, cigar.displayPrice].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: showFullImage) {
                    CigarPhotoView(photo: cigar.photo, maxPointSize: 500)
                        .frame(height: 300)
                }
                .buttonStyle(.plain)
                .allowsHitTesting(cigar.photo != nil)
                .accessibilityLabel("View photo full screen")

                VStack(alignment: .leading, spacing: 8) {
                    Text(cigar.name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.accent)

                    Text(cigar.date, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(sizeLine)
                        .font(.title3.weight(.semibold))
                        .padding(.top, 8)

                    if let purchaseLine {
                        Text(purchaseLine)
                            .fontWeight(.medium)
                    }

                    if let storePlace = cigar.storePlace {
                        StoreMapCard(place: storePlace) {
                            mapFocus = storePlace
                        }
                        .padding(.vertical, 4)
                    }

                    sectionHeader("Rating:")
                    StarRating(rating: cigar.rating)

                    if !cigar.notes.isEmpty {
                        sectionHeader("Notes:")
                        Text(cigar.notes)
                    }
                }
                .padding()
            }
        }
        // Leave room so the last lines can scroll up past the floating page dots.
        .contentMargins(.bottom, 72, for: .scrollContent)
        .sheet(item: $mapFocus) { place in
            StoresMapView(focus: place)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.accent)
            .padding(.top, 16)
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
    }
}

private struct DetailsPreviewHost: View {
    let cigar: CigarTemplate
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            CigarDetails(initialCigar: cigar, sortOption: .date, searchText: "", zoomNamespace: namespace)
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: CigarTemplate.self, configurations: config)
        let cigar = CigarTemplate(name: "Montecristo No. 2", type: "Torpedo", length: "6.125", gauge: "52", location: "Local Shop", price: "15", strength: "Strong", rating: 5, notes: "Classic Cuban flavor with rich earth tones and a spicy finish.", date: .now)
        container.mainContext.insert(cigar)

        return DetailsPreviewHost(cigar: cigar)
            .modelContainer(container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
