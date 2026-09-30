// CigarLookupView
// Find a cigar by whatever part of its name you remember, then tap the right one to
// fill in the form. Matches from your own journal show instantly; a web search
// returns real lines and sizes to choose from. If the cigar has a photo, it's sent
// along to help identify the line and pick the size.

import SwiftData
import SwiftUI

/// The details a lookup can fill in. Nil fields leave the form unchanged.
struct CigarLookupSelection {
    var name: String
    var type: String?
    var length: String?
    var gauge: String?
    var strength: String?
    var wrapper: String?
    var binder: String?
    var filler: String?
    var origin: String?
    var sourceURL: URL?
}

struct CigarLookupView: View {
    let photo: Data?
    let onSelect: (CigarLookupSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CigarTemplate.date, order: .reverse) private var journal: [CigarTemplate]

    @State private var query: String
    @State private var webState: WebState = .idle
    @State private var showingSettings = false
    @State private var usePhoto: Bool
    @FocusState private var isQueryFocused: Bool

    private enum WebState {
        case idle
        case loading
        case loaded(CigarLookupResult)
        case failed(String)
    }

    init(query: String, photo: Data? = nil, onSelect: @escaping (CigarLookupSelection) -> Void) {
        self.photo = photo
        self.onSelect = onSelect
        _query = State(initialValue: query)
        _usePhoto = State(initialValue: photo != nil)
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
                            .disabled(!canSearch)
                    }

                    if let photo {
                        Toggle(isOn: $usePhoto) {
                            HStack(spacing: 12) {
                                CigarPhotoView(photo: photo, maxPointSize: 44)
                                    .frame(width: 44, height: 44)
                                    .clipShape(.rect(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Use Photo")
                                    Text("Helps pick the line and size")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } footer: {
                    if usePhoto && photo != nil {
                        Text("Type what you know, or leave it blank to search from the photo alone. The photo is only sent when you tap Search.")
                    } else {
                        Text("Try a brand like \"Acid\" or a full name like \"H. Upmann Vintage Cameroon\".")
                    }
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
                                    source: candidate.sourceURL?.host(),
                                    matchesPhoto: candidate.matchesPhoto
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

    /// A name, or the photo on its own, is enough to search.
    private var canSearch: Bool {
        !isLoading && (!trimmedQuery.isEmpty || (usePhoto && photo != nil))
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
        guard canSearch else { return }
        isQueryFocused = false
        webState = .loading

        let searchText = trimmedQuery
        let searchPhoto = usePhoto ? photo : nil
        Task {
            do {
                webState = .loaded(try await CigarLookupService().lookUp(searchText, photo: searchPhoto))
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
    var matchesPhoto = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                if matchesPhoto {
                    Label("Fits photo", systemImage: "camera.viewfinder")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.accent)
                }
            }
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
