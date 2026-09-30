// StorePickerView
// Search Apple Maps for the shop where a cigar was bought. Stores already saved on
// other cigars are suggested first; Apple Maps results near you come after.

import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct StorePickerView: View {
    let onSelect: (StorePlace) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CigarTemplate.date, order: .reverse) private var cigars: [CigarTemplate]

    @State private var query: String
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var userLocation: CLLocation?
    @State private var locationSession: CLServiceSession?

    init(query: String, onSelect: @escaping (StorePlace) -> Void) {
        self.onSelect = onSelect
        _query = State(initialValue: query)
    }

    var body: some View {
        NavigationStack {
            let saved = savedStores
            let savedIDs = Set(saved.compactMap(\.placeID))
            let mapResults = results.filter { item in
                item.identifier.map { !savedIDs.contains($0.rawValue) } ?? true
            }

            List {
                if !saved.isEmpty {
                    Section(trimmedQuery.isEmpty ? "Your Recent Stores" : "Your Stores") {
                        ForEach(saved) { place in
                            Button {
                                onSelect(place)
                                dismiss()
                            } label: {
                                StoreResultRow(
                                    name: place.name,
                                    address: place.address,
                                    location: CLLocation(latitude: place.latitude, longitude: place.longitude),
                                    userLocation: userLocation
                                )
                            }
                        }
                    }
                }

                if !mapResults.isEmpty {
                    Section(saved.isEmpty ? "" : "Apple Maps") {
                        ForEach(mapResults, id: \.self) { item in
                            Button {
                                if let place = StorePlace(mapItem: item) {
                                    onSelect(place)
                                }
                                dismiss()
                            } label: {
                                StoreResultRow(
                                    name: item.name ?? "Unknown",
                                    address: item.singleLineAddress,
                                    location: item.location,
                                    userLocation: userLocation
                                )
                            }
                        }
                    }
                }
            }
            .overlay {
                if !saved.isEmpty {
                    EmptyView()
                } else if isSearching && results.isEmpty {
                    ProgressView()
                } else if results.isEmpty {
                    ContentUnavailableView(
                        trimmedQuery.isEmpty ? "Find the Store" : "No Stores Found",
                        systemImage: "storefront",
                        description: Text(trimmedQuery.isEmpty ? "Search for the shop by name, like \"JR Cigars\"." : "Try the shop's name plus the town.")
                    )
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Store name")
            .navigationTitle("Store Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
            }
            .task {
                await findUserLocation()
            }
            .task(id: SearchKey(query: trimmedQuery, hasLocation: userLocation != nil)) {
                // Wait for a pause in typing before searching.
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                await search()
            }
        }
    }

    private struct SearchKey: Equatable {
        let query: String
        let hasLocation: Bool
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Map locations already saved on other cigars whose store name matches the query,
    /// exact matches first. With no query, the most recently used stores.
    private var savedStores: [StorePlace] {
        var seen = Set<String>()
        let places = cigars.compactMap(\.storePlace).filter { seen.insert($0.id).inserted }

        let wanted = Self.normalized(trimmedQuery)
        guard !wanted.isEmpty else { return Array(places.prefix(5)) }

        let matches = places.filter { place in
            let name = Self.normalized(place.name)
            return name.contains(wanted) || wanted.contains(name)
        }
        return matches.filter { Self.normalized($0.name) == wanted }
            + matches.filter { Self.normalized($0.name) != wanted }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func search() async {
        guard !trimmedQuery.isEmpty else {
            results = []
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedQuery
        request.resultTypes = .pointOfInterest
        if let userLocation {
            request.region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 80_000, longitudinalMeters: 80_000)
        }

        isSearching = true
        defer { isSearching = false }

        guard let response = try? await MKLocalSearch(request: request).start() else {
            results = []
            return
        }
        if let userLocation {
            results = response.mapItems.sorted { $0.location.distance(from: userLocation) < $1.location.distance(from: userLocation) }
        } else {
            results = response.mapItems
        }
    }

    /// Asks for "While Using" location access (first time only) and grabs one location fix.
    private func findUserLocation() async {
        locationSession = CLServiceSession(authorization: .whenInUse)
        defer { locationSession = nil }

        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let location = update.location {
                    userLocation = location
                    return
                }
                if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                    return
                }
            }
        } catch {
            // No location: results just aren't sorted by distance.
        }
    }
}

private struct StoreResultRow: View {
    let name: String
    let address: String?
    let location: CLLocation
    let userLocation: CLLocation?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let address {
                    Text(address)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let userLocation {
                let meters = location.distance(from: userLocation)
                Text(Measurement(value: meters, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road)))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
    }
}

// MARK: - MapKit bridging

extension MKMapItem {
    var singleLineAddress: String? {
        let address = address?.shortAddress ?? address?.fullAddress
        return address?.replacingOccurrences(of: "\n", with: ", ")
    }
}

extension StorePlace {
    init?(mapItem: MKMapItem) {
        guard let name = mapItem.name else { return nil }
        self.init(
            name: name,
            placeID: mapItem.identifier?.rawValue,
            latitude: mapItem.location.coordinate.latitude,
            longitude: mapItem.location.coordinate.longitude,
            address: mapItem.singleLineAddress
        )
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// The exact Apple Maps place when possible, otherwise a pin at the saved coordinates.
    func mapItem() async -> MKMapItem {
        if let placeID, let identifier = MKMapItem.Identifier(rawValue: placeID),
           let item = try? await MKMapItemRequest(mapItemIdentifier: identifier).mapItem {
            return item
        }
        let item = MKMapItem(
            location: CLLocation(latitude: latitude, longitude: longitude),
            address: address.flatMap { MKAddress(fullAddress: $0, shortAddress: nil) }
        )
        item.name = name
        return item
    }
}

// MARK: - Map card for the details screen

struct StoreMapCard: View {
    let place: StorePlace
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                Map(initialPosition: .region(MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 600, longitudinalMeters: 600)), interactionModes: []) {
                    Marker(place.name, systemImage: "storefront", coordinate: place.coordinate)
                        .tint(.accent)
                }
                .frame(height: 140)
                .allowsHitTesting(false)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .font(.headline)
                        if let address = place.address {
                            Text(address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "map")
                        .foregroundStyle(.accent)
                }
                .padding(12)
            }
            .background(.background.secondary)
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show \(place.name) on the store map")
    }
}
