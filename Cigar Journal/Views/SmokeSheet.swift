// SmokeSheet
// Log a smoke (the first one, or another round of a cigar you've had before), and
// restock the humidor.

import SwiftData
import SwiftUI

struct SmokeSheet: View {
    let cigar: CigarTemplate

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var rating = 3
    @State private var notes = ""

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
                    if cigar.humidorCount > 0 {
                        Text("Takes one out of your humidor (\(cigar.humidorCount - 1) left after this).")
                    }
                }

                Section("Notes") {
                    TextField("How did it smoke?", text: $notes, axis: .vertical)
                        .lineLimit(5...)
                }
            }
            .navigationTitle(cigar.hasBeenSmoked ? "Smoke Again" : "Smoke")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        cigar.recordSmoke(date: date, rating: rating, notes: notes, in: modelContext)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
    }
}
