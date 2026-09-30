// SearchTabView
// Searches every cigar, smoked or in the humidor, by name, store, tobacco or notes.

import SwiftData
import SwiftUI

struct SearchTabView: View {
    @Query(sort: \CigarTemplate.date, order: .reverse) private var cigars: [CigarTemplate]
    @State private var query = ""

    var body: some View {
        let results = matches

        NavigationStack {
            List(results) { cigar in
                NavigationLink(value: cigar) {
                    CigarRowView(cigar: cigar, showsShelfTags: true)
                }
            }
            .listStyle(.plain)
            .overlay {
                if trimmedQuery.isEmpty {
                    ContentUnavailableView(
                        "Search Your Cigars",
                        systemImage: "magnifyingglass",
                        description: Text("Find cigars you've smoked or have in the humidor by name, store, wrapper, origin or notes.")
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: trimmedQuery)
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: CigarTemplate.self) { cigar in
                CigarDetailView(cigar: cigar)
            }
        }
        .searchable(text: $query, prompt: "Name, store, wrapper, notes…")
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matches: [CigarTemplate] {
        let text = trimmedQuery
        guard !text.isEmpty else { return [] }
        return cigars.filter { cigar in
            let fields = [cigar.name, cigar.location, cigar.type, cigar.notes, cigar.wrapper, cigar.binder, cigar.filler, cigar.origin]
                + (cigar.smokeSessions ?? []).map(\.notes)
            return fields.contains { $0?.localizedStandardContains(text) == true }
        }
    }
}
