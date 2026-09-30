// StoresMapView
// Every store you've bought cigars from, on one map. Opens focused on one store;
// tap a pin to see which cigars came from there and open it in Apple Maps.

import MapKit
import SwiftData
import SwiftUI

struct StoresMapView: View {
    /// The store to center on and select first.
    let focus: StorePlace

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CigarTemplate.date, order: .reverse) private var cigars: [CigarTemplate]

    @State private var position: MapCameraPosition
    @State private var selectedKey: String?

    init(focus: StorePlace) {
        self.focus = focus
        _position = State(initialValue: .region(MKCoordinateRegion(center: focus.coordinate, latitudinalMeters: 5_000, longitudinalMeters: 5_000)))
        _selectedKey = State(initialValue: StoreGroup.key(for: focus))
    }

    var body: some View {
        let groups = StoreGroup.groups(from: cigars)
        let selected = groups.first { $0.key == selectedKey }

        NavigationStack {
            Map(position: $position, selection: $selectedKey) {
                ForEach(groups) { group in
                    Marker(group.place.name, systemImage: "storefront", coordinate: group.place.coordinate)
                        .tint(.accent)
                        .tag(group.key)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .safeAreaInset(edge: .bottom) {
                if let selected {
                    StoreSummaryCard(group: selected)
                        .padding()
                }
            }
            .navigationTitle(groups.count == 1 ? "1 Store" : "\(groups.count) Stores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Show All") {
                        withAnimation {
                            position = .automatic
                        }
                    }
                    .disabled(groups.count < 2)
                }
            }
        }
    }
}

/// One store and the cigars bought there.
private struct StoreGroup: Identifiable {
    let key: String
    let place: StorePlace
    let cigars: [CigarTemplate]

    var id: String { key }

    /// Same Apple Maps place, or the same spot if a place ID is missing.
    static func key(for place: StorePlace) -> String {
        place.placeID ?? String(format: "%.4f,%.4f", place.latitude, place.longitude)
    }

    static func groups(from cigars: [CigarTemplate]) -> [StoreGroup] {
        var order: [String] = []
        var byKey: [String: (place: StorePlace, cigars: [CigarTemplate])] = [:]
        for cigar in cigars {
            guard let place = cigar.storePlace else { continue }
            let key = key(for: place)
            if byKey[key] == nil {
                order.append(key)
                byKey[key] = (place, [])
            }
            byKey[key]?.cigars.append(cigar)
        }
        return order.compactMap { key in
            byKey[key].map { StoreGroup(key: key, place: $0.place, cigars: $0.cigars) }
        }
    }
}

private struct StoreSummaryCard: View {
    let group: StoreGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.place.name)
                        .font(.headline)
                    if let address = group.place.address {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Open in Maps", systemImage: "arrow.up.forward.app") {
                    Task {
                        _ = await group.place.mapItem().openInMaps()
                    }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glassProminent)
                .tint(.accent)
            }

            Text(group.cigars.count == 1 ? "1 cigar from here" : "\(group.cigars.count) cigars from here")
                .font(.subheadline.weight(.semibold))
            Text(group.cigars.prefix(4).map(\.name).joined(separator: " · ") + (group.cigars.count > 4 ? " …" : ""))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}
