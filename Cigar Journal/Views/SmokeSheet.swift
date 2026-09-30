// SmokeSheet
// Log a smoke (the first one, or another round of a cigar you've had before), edit
// one you've already logged, and restock the humidor.

import SwiftData
import SwiftUI

struct SmokeSheet: View {
    let cigar: CigarTemplate
    /// The smoke being edited, or nil to log a new one.
    let editing: SmokeEntry?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var rating: Int
    @State private var notes: String
    @State private var confirmingDelete = false
    @State private var photos: [PendingPhoto]
    private let originalPhotos: [CigarPhoto]

    init(cigar: CigarTemplate, editing: SmokeEntry? = nil) {
        self.cigar = cigar
        self.editing = editing
        _date = State(initialValue: editing?.date ?? .now)
        _rating = State(initialValue: editing?.rating ?? 3)
        _notes = State(initialValue: editing?.notes ?? "")
        let existing = editing.map { cigar.photos(for: $0) } ?? []
        originalPhotos = existing
        _photos = State(initialValue: existing.compactMap { record in
            record.data.map { PendingPhoto(data: $0, record: record) }
        })
    }

    private var title: String {
        if editing != nil { return "Edit Smoke" }
        return cigar.hasBeenSmoked ? "Smoke Again" : "Smoke"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("Rating")
                        Spacer()
                        StarRating(rating: rating, starSpacing: 4) { rating = $0 }
                    }
                } footer: {
                    if editing == nil && cigar.humidorCount > 0 {
                        Text("Takes one out of your humidor (\(cigar.humidorCount - 1) left after this).")
                    }
                }

                Section("Notes") {
                    TextField("How did it smoke?", text: $notes, axis: .vertical)
                        .lineLimit(5...)
                }

                Section("Photos") {
                    PhotoStripEditor(photos: $photos)
                }

                // The first smoke is the cigar itself; delete the cigar to remove it.
                if editing?.session != nil {
                    Section {
                        Button("Delete This Smoke", role: .destructive) {
                            confirmingDelete = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        save()
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Delete this smoke?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let session = editing?.session {
                        modelContext.delete(session)
                    }
                    dismiss()
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.background)
    }

    private func save() {
        switch editing {
        case nil:
            let session = cigar.recordSmoke(date: date, rating: rating, notes: notes, in: modelContext)
            cigar.savePhotos(photos, original: [], session: session, firstSmoke: session == nil, in: modelContext)
        case let entry? where entry.session != nil:
            entry.session?.date = date
            entry.session?.rating = rating
            entry.session?.notes = notes
            cigar.savePhotos(photos, original: originalPhotos, session: entry.session, in: modelContext)
        case .some:
            // The first smoke lives on the cigar itself.
            cigar.date = date
            cigar.rating = rating
            cigar.notes = notes
            cigar.savePhotos(photos, original: originalPhotos, firstSmoke: true, in: modelContext)
        }
    }
}

struct RestockSheet: View {
    let cigar: CigarTemplate

    @Environment(\.dismiss) private var dismiss
    @State private var quantity = 1

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Add \(quantity)", value: $quantity, in: 1...99)
                } footer: {
                    Text("You'll have \(cigar.humidorCount + quantity) in your humidor.")
                }
            }
            .navigationTitle("Add to Humidor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        cigar.humidorCount += quantity
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(220)])
        .presentationBackground(.background)
    }
}
