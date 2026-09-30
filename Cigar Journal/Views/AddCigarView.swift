// AddCigar
// Add a new cigar, or edit an existing one when `editCigar` is set.

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
    @State private var expandedWheel: String?

    init(editCigar: CigarTemplate? = nil) {
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
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CigarPhotoPicker(selectedPhoto: $photo)
                        .listRowInsets(EdgeInsets())
                }

                Section("Details") {
                    IconTextFieldRow(systemImage: "plus.circle", title: "Name", text: $name)
                    IconTextFieldRow(systemImage: "storefront", title: "Store", text: $location)
                    IconTextFieldRow(systemImage: "dollarsign.circle", title: "Price", text: $price, keyboardType: .decimalPad)
                    IconDateRow(systemImage: "calendar", title: "Date", date: $date)
                    IconRatingRow(systemImage: "star", title: "Rating", rating: $rating)
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

                Section("Notes") {
                    TextField("How did it smoke?", text: $notes, axis: .vertical)
                        .lineLimit(6...)
                }
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

    private func saveCigar() {
        // The photo was already compressed when it was picked; storing it as-is
        // avoids losing JPEG quality on every edit.
        let storedLocation = location.trimmingCharacters(in: .whitespaces).isEmpty ? CigarTemplate.emptyLocation : location
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
        } else {
            modelContext.insert(CigarTemplate(
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
            ))
        }
    }
}

#Preview {
    AddCigar()
        .modelContainer(for: CigarTemplate.self, inMemory: true)
}
