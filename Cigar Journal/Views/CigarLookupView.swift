// CigarLookupView
// Find a cigar by whatever part of its name you remember, then tap the right one to
// fill in the form. Matches from your own journal show instantly; a web search
// returns real lines and sizes to choose from.

import SwiftData
import SwiftUI

/// The details a lookup can fill in. Nil fields leave the form unchanged.
struct CigarLookupSelection {
    var name: String
    var type: String?
    var length: String?
    var gauge: String?
    var strength: String?
    var sourceURL: URL?
}

struct CigarLookupView: View {
    let onSelect: (CigarLookupSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CigarTemplate.date, order: .reverse) private var journal: [CigarTemplate]

    @State private var query: String
    @State private var webState: WebState = .idle
    @State private var showingSettings = false
    @FocusState private var isQueryFocused: Bool

    private enum WebState {
        case idle
        case loading
        case loaded(CigarLookupResult)
        case failed(String)
    }

    init(query: String, onSelect: @escaping (CigarLookupSelection) -> Void) {
        self.onSelect = onSelect
        _query = State(initialValue: query)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Brand, line or full name", text: $query)
                            .focused($isQueryFocused)
                            .submitLabel(.search)
                            .onSubmit(searchWeb)
                        Button("Search", action: searchWeb)
                            .buttonStyle(.borderedProminent)
                            .disabled(trimmedQuery.isEmpty || isLoading)
                    }
                } footer: {
                    Text("Try a brand like \"Acid\" or a full name like \"H. Upmann Vintage Cameroon\".")
                }

                if !journalMatches.isEmpty {
                    Section("From Your Journal") {
                        ForEach(journalMatches) { cigar in
                            Button {
                                select(CigarLookupSelection(
                                    name: cigar.name,
                                    type: cigar.type,
                                    length: CigarTemplate.normalizedLength(cigar.length),
                                    gauge: cigar.gauge,
                                    strength: cigar.strength
                                ))
                            } label: {
                                ResultRow(
                                    title: cigar.name,
                                    detail: "\(cigar.type)  •  \(cigar.length)\" x \(cigar.gauge)  •  \(cigar.strength)"
                                )
                            }
                        }
                    }
                }

                webSections
            }
            .navigationTitle("Look Up Cigar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onAppear {
                isQueryFocused = trimmedQuery.isEmpty
            }
        }
    }

    // MARK: Web results

    @ViewBuilder
    private var webSections: some View {
        switch webState {
        case .idle:
            EmptyView()

        case .loading:
            Section("From the Web") {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Searching cigar sites…")
                        .foregroundStyle(.secondary)
                }
            }

        case .failed(let message):
            Section("From the Web") {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                if KeychainStore.anthropicAPIKey == nil {
                    Button("Add API Key…") {
                        showingSettings = true
                    }
                }
            }

        case .loaded(let result):
            if result.candidates.isEmpty {
                Section("From the Web") {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text(result.note.isEmpty ? "Try a more specific name." : result.note)
                    )
                }
            } else {
                ForEach(groupedByLine(result.candidates), id: \.line) { group in
                    Section {
                        ForEach(group.candidates) { candidate in
                            Button {
                                select(candidate)
                            } label: {
                                ResultRow(
                                    title: candidate.name,
                                    detail: [candidate.shape, candidate.sizeText, candidate.strength]
                                        .compactMap { $0 }
                                        .joined(separator: "  •  "),
                                    source: candidate.sourceURL?.host()
                                )
                            }
                        }
                    } header: {
                        Text(group.line)
                    } footer: {
                        if group.line == groupedByLine(result.candidates).first?.line, !result.note.isEmpty {
                            Text(result.note)
                        }
                    }
                }
            }
        }
    }

    // MARK: Actions

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isLoading: Bool {
        if case .loading = webState { true } else { false }
    }

    /// Past entries whose name contains the query, one per name.
    private var journalMatches: [CigarTemplate] {
        guard !trimmedQuery.isEmpty else { return [] }
        var seen = Set<String>()
        return journal.filter { cigar in
            cigar.name.localizedStandardContains(trimmedQuery) && seen.insert(cigar.name.lowercased()).inserted
        }
        .prefix(5)
        .map(\.self)
    }

    private func searchWeb() {
        guard !trimmedQuery.isEmpty, !isLoading else { return }
        isQueryFocused = false
        webState = .loading

        let searchText = trimmedQuery
        Task {
            do {
                webState = .loaded(try await CigarLookupService().lookUp(searchText))
            } catch {
                webState = .failed(error.localizedDescription)
            }
        }
    }

    private func select(_ candidate: CigarLookupCandidate) {
        select(CigarLookupSelection(
            name: candidate.name,
            type: candidate.shape,
            length: candidate.lengthInches.map { CigarTemplate.normalizedLength(CigarTemplate.formatLength($0)) },
            gauge: candidate.ringGauge.map(String.init),
            strength: candidate.strength,
            sourceURL: candidate.sourceURL
        ))
    }

    private func select(_ selection: CigarLookupSelection) {
        onSelect(selection)
        dismiss()
    }

    private func groupedByLine(_ candidates: [CigarLookupCandidate]) -> [(line: String, candidates: [CigarLookupCandidate])] {
        var order: [String] = []
        var groups: [String: [CigarLookupCandidate]] = [:]
        for candidate in candidates {
            if groups[candidate.line] == nil { order.append(candidate.line) }
            groups[candidate.line, default: []].append(candidate)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }
}

private struct ResultRow: View {
    let title: String
    let detail: String
    var source: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            if !detail.isEmpty {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.accent)
            }
            if let source {
                Text(source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

#Preview {
    CigarLookupView(query: "Acid") { _ in }
        .modelContainer(for: CigarTemplate.self, inMemory: true)
}
