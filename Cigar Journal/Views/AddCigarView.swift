// AddCigar
// Add a new cigar, or edit an existing one when `editCigar` is set. A new cigar can be
// one you've smoked (goes to Home) or one you haven't yet (goes to the Humidor).

import SwiftData
import SwiftUI

struct AddCigar: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let editCigar: CigarTemplate?

    @State private var name: String
    @State private var type: String
    @State private var length: String
    @State private var gauge: String
    @State private var location: String
    @State private var price: String
    @State private var strength: String
    @State private var rating: Int
    @State private var notes: String
    @State private var date: Date
    @State private var photo: Data?
    @State private var storePlace: StorePlace?
    @State private var showingStorePicker = false
    @State private var expandedWheel: String?
    @State private var lookupRequest: LookupRequest?
    @State private var lookupSource: URL?
    @State private var wrapper: String
    @State private var binder: String
    @State private var filler: String
    @State private var origin: String
    @State private var notSmokedYet: Bool
    @State private var humidorCount: Int
    @State private var extraPhotos: [PendingPhoto]
    private let originalExtraPhotos: [CigarPhoto]

    init(editCigar: CigarTemplate? = nil, startInHumidor: Bool = false) {
        self.editCigar = editCigar

        _name = State(initialValue: editCigar?.name ?? "")
        _type = State(initialValue: editCigar?.type ?? "Robusto")
        _length = State(initialValue: CigarTemplate.normalizedLength(editCigar?.length ?? "6"))
        _gauge = State(initialValue: editCigar?.gauge ?? "50")
        _location = State(initialValue: editCigar?.displayLocation ?? "")
        _price = State(initialValue: editCigar?.displayPrice == nil ? "" : editCigar?.price ?? "")
        _strength = State(initialValue: editCigar?.strength ?? "Medium")
        _rating = State(initialValue: editCigar?.rating ?? 3)
        _notes = State(initialValue: editCigar?.notes ?? "")
        _date = State(initialValue: editCigar?.date ?? .now)
        _photo = State(initialValue: editCigar?.photo)
        _storePlace = State(initialValue: editCigar?.storePlace)
        _wrapper = State(initialValue: editCigar?.wrapper ?? "")
        _binder = State(initialValue: editCigar?.binder ?? "")
        _filler = State(initialValue: editCigar?.filler ?? "")
        _origin = State(initialValue: editCigar?.origin ?? "")
        _notSmokedYet = State(initialValue: editCigar.map { !$0.hasBeenSmoked } ?? startInHumidor)
        _humidorCount = State(initialValue: editCigar?.humidorCount ?? (startInHumidor ? 1 : 0))
        let existingPhotos = editCigar?.sortedExtraPhotos ?? []
        originalExtraPhotos = existingPhotos
        _extraPhotos = State(initialValue: existingPhotos.compactMap { record in
            record.data.map { PendingPhoto(data: $0, record: record) }
        })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CigarPhotoPicker(selectedPhoto: $photo)
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    PhotoStripEditor(photos: $extraPhotos)
                } header: {
                    Text("More Photos")
                } footer: {
                    Text("The big photo above is the cover. Photos you add when smoking also show up with that smoke.")
                }

                Section("Details") {
                    IconTextFieldRow(systemImage: "plus.circle", title: "Name", text: $name) {
                        Button("Look Up Cigar", systemImage: "magnifyingglass") {
                            // Snapshot the current name and photo; the sheet shouldn't read form state later.
                            lookupRequest = LookupRequest(query: trimmedName, photo: photo ?? extraPhotos.first?.data)
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                    if let lookupSource {
                        Link(destination: lookupSource) {
                            Label("Filled from \(lookupSource.host() ?? "the web")", systemImage: "link")
                                .font(.footnote)
                        }
                    }
                    IconTextFieldRow(systemImage: "storefront", title: "Store", text: $location) {
                        Button("Find Store on Map", systemImage: storePlace == nil ? "mappin.circle" : "mappin.circle.fill") {
                            showingStorePicker = true
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                    if let storePlace {
                        HStack {
                            Label(storePlace.address ?? "Location saved", systemImage: "mappin.and.ellipse")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Remove Location", systemImage: "xmark.circle.fill") {
                                self.storePlace = nil
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }
                    }
                    IconTextFieldRow(systemImage: "dollarsign.circle", title: "Price", text: $price, keyboardType: .decimalPad)
                    IconDateRow(systemImage: "calendar", title: dateTitle, date: $date)
                    if !notSmokedYet {
                        IconRatingRow(systemImage: "star", title: "Rating", rating: $rating)
                    }
                }

                Section {
                    // Only a new cigar can start out unsmoked; after that, use Smoke.
                    if editCigar == nil {
                        Toggle(isOn: $notSmokedYet.animation()) {
                            Label("I Haven't Smoked It Yet", systemImage: "archivebox")
                        }
                    }
                    Stepper(value: $humidorCount, in: (notSmokedYet ? 1 : 0)...99) {
                        Label("In Humidor: \(humidorCount)", systemImage: "archivebox.fill")
                    }
                } header: {
                    Text("Humidor")
                } footer: {
                    if notSmokedYet {
                        Text("It'll go in your Humidor. Tap Smoke on it when you light one up.")
                    }
                }

                Section("Size") {
                    IconWheelRow(
                        systemImage: "arrow.left.and.right",
                        title: "Length",
                        selection: $length,
                        options: CigarTemplate.lengthOptions,
                        unit: "\"",
                        isExpanded: wheelBinding("length")
                    )
                    IconWheelRow(
                        systemImage: "circle.dotted",
                        title: "Gauge",
                        selection: $gauge,
                        options: CigarTemplate.gaugeOptions,
                        isExpanded: wheelBinding("gauge")
                    )
                }

                Section("Features") {
                    IconPickerRow(systemImage: "chart.bar.xaxis", title: "Strength", selection: $strength, options: CigarTemplate.strengthOptions)
                    IconPickerRow(systemImage: "shippingbox", title: "Type", selection: $type, options: CigarTemplate.typeOptions)
                }

                Section("Tobacco") {
                    IconTextFieldRow(systemImage: "leaf", title: "Wrapper", text: $wrapper)
                    IconTextFieldRow(systemImage: "square.stack.3d.up", title: "Binder", text: $binder)
                    IconTextFieldRow(systemImage: "square.3.layers.3d", title: "Filler", text: $filler)
                    IconTextFieldRow(systemImage: "globe.americas", title: "Origin", text: $origin)
                }

                if !notSmokedYet {
                    Section {
                        TextField("How did it smoke?", text: $notes, axis: .vertical)
                            .lineLimit(6...)
                    } header: {
                        Text("Notes")
                    } footer: {
                        if (editCigar?.smokeCount ?? 0) > 1 {
                            Text("These are from your first smoke. Later smokes are listed on the cigar's page.")
                        }
                    }
                }
            }
            .onChange(of: notSmokedYet) { _, notSmoked in
                if notSmoked && humidorCount == 0 {
                    humidorCount = 1
                }
            }
            .onChange(of: location) { _, newValue in
                // Clearing the store name also clears its map location.
                if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    storePlace = nil
                }
            }
            .sheet(isPresented: $showingStorePicker) {
                StorePickerView(query: location) { place in
                    storePlace = place
                    location = place.name
                }
            }
            .sheet(item: $lookupRequest) { request in
                CigarLookupView(query: request.query, photo: request.photo, onSelect: apply)
            }
            .navigationTitle(editCigar == nil ? "Add Cigar" : "Edit Cigar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        saveCigar()
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private struct LookupRequest: Identifiable {
        let id = UUID()
        let query: String
        let photo: Data?
    }

    private var dateTitle: String {
        if notSmokedYet { return "Date Added" }
        return (editCigar?.smokeCount ?? 0) > 1 ? "First Smoked" : "Date"
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Only one wheel picker is open at a time.
    private func wheelBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expandedWheel == id },
            set: { expandedWheel = $0 ? id : nil }
        )
    }

    /// Fills in the details a lookup found, leaving the rest of the form as it was.
    private func apply(_ selection: CigarLookupSelection) {
        name = selection.name
        if let type = selection.type { self.type = type }
        if let length = selection.length { self.length = length }
        if let gauge = selection.gauge { self.gauge = gauge }
        if let strength = selection.strength { self.strength = strength }
        if let wrapper = selection.wrapper { self.wrapper = wrapper }
        if let binder = selection.binder { self.binder = binder }
        if let filler = selection.filler { self.filler = filler }
        if let origin = selection.origin { self.origin = origin }
        lookupSource = selection.sourceURL
    }

    private func saveCigar() {
        // The photo was already compressed when it was picked; storing it as-is
        // avoids losing JPEG quality on every edit.
        let hasStore = !location.trimmingCharacters(in: .whitespaces).isEmpty
        let storedLocation = hasStore ? location : CigarTemplate.emptyLocation
        let storedPlace = hasStore ? storePlace : nil
        let storedPrice = price.trimmingCharacters(in: .whitespaces).isEmpty ? CigarTemplate.emptyPrice : price

        if let cigar = editCigar {
            cigar.name = trimmedName
            cigar.type = type
            cigar.length = length
            cigar.gauge = gauge
            cigar.location = storedLocation
            cigar.price = storedPrice
            cigar.strength = strength
            cigar.rating = rating
            cigar.notes = notes
            cigar.date = date
            if cigar.photo != photo {
                cigar.photo = photo
            }
            cigar.storePlace = storedPlace
            applyNewFields(to: cigar)
            cigar.savePhotos(extraPhotos, original: originalExtraPhotos, in: modelContext)
        } else {
            let cigar = CigarTemplate(
                name: trimmedName,
                type: type,
                length: length,
                gauge: gauge,
                location: storedLocation,
                price: storedPrice,
                strength: strength,
                rating: rating,
                notes: notes,
                date: date,
                photo: photo
            )
            cigar.storePlace = storedPlace
            cigar.hasBeenSmoked = !notSmokedYet
            applyNewFields(to: cigar)
            modelContext.insert(cigar)
            cigar.savePhotos(extraPhotos, original: [], in: modelContext)
        }
    }

    private func applyNewFields(to cigar: CigarTemplate) {
        func cleaned(_ text: String) -> String? {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        cigar.wrapper = cleaned(wrapper)
        cigar.binder = cleaned(binder)
        cigar.filler = cleaned(filler)
        cigar.origin = cleaned(origin)
        cigar.humidorCount = humidorCount
    }
}

#Preview {
    AddCigar()
        .modelContainer(for: [CigarTemplate.self, SmokeSession.self, CigarPhoto.self], inMemory: true)
}
