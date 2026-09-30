// CigarsHome

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum CigarSortOption: String, CaseIterable, Identifiable {
    case alphabetical = "Alphabetical"
    case date = "Date"
    case price = "Price"
    case strength = "Strength"
    case rating = "Rating"

    var id: String { rawValue }

    /// Filters by name, store or notes, then sorts. Shared by the list and the details pager
    /// so swiping through details follows the same order you see in the list.
    func visibleCigars(_ cigars: [CigarTemplate], matching searchText: String) -> [CigarTemplate] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = query.isEmpty ? cigars : cigars.filter {
            $0.name.localizedStandardContains(query)
                || $0.location.localizedStandardContains(query)
                || $0.notes.localizedStandardContains(query)
        }

        switch self {
        case .alphabetical:
            return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .date:
            return filtered.sorted { $0.date > $1.date }
        case .price:
            return filtered.sorted { ($0.priceValue ?? 0) > ($1.priceValue ?? 0) }
        case .strength:
            return filtered.sorted { $0.strengthRank > $1.strengthRank }
        case .rating:
            return filtered.sorted { $0.rating > $1.rating }
        }
    }
}

struct CigarsHome: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CigarTemplate.date, order: .reverse) private var cigars: [CigarTemplate]

    @AppStorage("sortOption") private var sortOption: CigarSortOption = .date
    @AppStorage("lastBackupDate") private var lastBackupTimestamp: Double = 0

    @State private var searchText = ""
    @State private var showAddCigar = false
    @State private var editingCigar: CigarTemplate?
    @State private var cigarPendingDelete: CigarTemplate?
    @Namespace private var zoomNamespace

    // Backup
    @State private var backupDocument: CigarBackupDocument?
    @State private var backupFilename = ""
    @State private var showingRestorePicker = false
    @State private var pendingRestore: [CigarBackup.Entry]?
    @State private var restoreFoundCount = 0
    @State private var backupErrorMessage: String?

    var body: some View {
        let visibleCigars = sortOption.visibleCigars(cigars, matching: searchText)

        NavigationStack {
            Group {
                if cigars.isEmpty {
                    ContentUnavailableView {
                        Label("No Cigars Yet", systemImage: "list.bullet")
                    } description: {
                        Text("Tap + to add your first cigar.")
                    }
                } else {
                    List(visibleCigars) { cigar in
                        NavigationLink(value: cigar) {
                            CigarRowView(cigar: cigar, zoomNamespace: zoomNamespace)
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                cigarPendingDelete = cigar
                            }
                            Button("Edit", systemImage: "pencil") {
                                editingCigar = cigar
                            }
                        }
                    }
                    .listStyle(.plain)
                    .overlay {
                        if visibleCigars.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        }
                    }
                }
            }
            .navigationTitle("Cigar Journal")
            .searchable(text: $searchText, prompt: "Name, store or notes")
            .navigationDestination(for: CigarTemplate.self) { cigar in
                CigarDetails(
                    initialCigar: cigar,
                    sortOption: sortOption,
                    searchText: searchText,
                    zoomNamespace: zoomNamespace
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Cigar", systemImage: "plus") {
                        showAddCigar = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accent)
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    overflowMenu
                }
            }
            .sheet(isPresented: $showAddCigar) {
                AddCigar()
            }
            .sheet(item: $editingCigar) { cigar in
                AddCigar(editCigar: cigar)
            }
            .confirmationDialog(
                "Delete \(cigarPendingDelete?.name ?? "Cigar")?",
                isPresented: isPresented($cigarPendingDelete),
                titleVisibility: .visible,
                presenting: cigarPendingDelete
            ) { cigar in
                Button("Delete", role: .destructive) {
                    withAnimation {
                        modelContext.delete(cigar)
                    }
                }
            } message: { _ in
                Text("This also removes it from iCloud on all your devices.")
            }
            .fileExporter(
                isPresented: isPresented($backupDocument),
                document: backupDocument,
                contentType: .json,
                defaultFilename: backupFilename
            ) { result in
                switch result {
                case .success:
                    lastBackupTimestamp = Date.now.timeIntervalSince1970
                case .failure(let error):
                    backupErrorMessage = error.localizedDescription
                }
            }
            .fileImporter(isPresented: $showingRestorePicker, allowedContentTypes: [.json]) { result in
                prepareRestore(from: result)
            }
            .alert("Restore Backup", isPresented: isPresented($pendingRestore), presenting: pendingRestore) { entries in
                if !entries.isEmpty {
                    Button("Add \(entries.count) Cigars") {
                        CigarBackup.insert(entries, into: modelContext)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { entries in
                Text("Found \(restoreFoundCount) cigars, \(restoreFoundCount - entries.count) already in your journal. Restoring only adds missing cigars; nothing is changed or deleted.")
            }
            .alert("Backup Failed", isPresented: isPresented($backupErrorMessage), presenting: backupErrorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    private var overflowMenu: some View {
        Menu("Options", systemImage: "ellipsis") {
            Picker(selection: $sortOption) {
                ForEach(CigarSortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            } label: {
                Label("Sort By", systemImage: "arrow.up.arrow.down")
                Text(sortOption.rawValue)
            }
            .pickerStyle(.menu)

            Section {
                Button("Export Backup…", systemImage: "square.and.arrow.up", action: exportBackup)
                    .disabled(cigars.isEmpty)
                Button("Restore Backup…", systemImage: "arrow.counterclockwise") {
                    showingRestorePicker = true
                }
                Text(lastBackupText)
            }

            Section {
                Text("v\(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
            }
        }
    }

    private var lastBackupText: String {
        guard lastBackupTimestamp > 0 else { return "No backup yet" }
        let date = Date(timeIntervalSince1970: lastBackupTimestamp)
        return "Last backup: \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    private func exportBackup() {
        do {
            let backup = CigarBackup(cigars: cigars)
            backupFilename = backup.suggestedFilename
            backupDocument = CigarBackupDocument(data: try backup.encoded())
        } catch {
            backupErrorMessage = error.localizedDescription
        }
    }

    private func prepareRestore(from result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            let backup = try CigarBackup(data: Data(contentsOf: url))
            restoreFoundCount = backup.cigars.count
            pendingRestore = backup.entriesMissing(from: cigars)
        } catch {
            backupErrorMessage = error.localizedDescription
        }
    }

    /// A Bool binding that's true while `value` is non-nil, and clears it when dismissed.
    private func isPresented<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue != nil },
            set: { if !$0 { value.wrappedValue = nil } }
        )
    }
}

// MARK: - Row

struct CigarRowView: View {
    let cigar: CigarTemplate
    let zoomNamespace: Namespace.ID

    private var metadataLine: String {
        [cigar.type, cigar.strength, cigar.displayPrice].compactMap(\.self).joined(separator: "  •  ")
    }

    var body: some View {
        HStack(spacing: 12) {
            CigarPhotoView(photo: cigar.photo, maxPointSize: 84)
                .frame(width: 84, height: 84)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
                .matchedTransitionSource(id: cigar.persistentModelID, in: zoomNamespace)

            VStack(alignment: .leading, spacing: 4) {
                Text(cigar.name)
                    .font(.headline)

                Text(metadataLine)
                    .font(.callout)
                    .foregroundStyle(.accent)

                StarRating(rating: cigar.rating)
                    .font(.caption)
            }
        }
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "" }
    var buildNumber: String { infoDictionary?["CFBundleVersion"] as? String ?? "" }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: CigarTemplate.self, configurations: config)
        container.mainContext.insert(CigarTemplate(name: "Casa Magna Colorado", type: "Robusto", length: "5.50", gauge: "52", location: "Local Shop", price: "9.87", strength: "Medium", rating: 5, notes: "Dark chocolate, nutmeg and wood.", date: .now))

        return CigarsHome()
            .modelContainer(container)
    } catch {
        return Text("Failed to load preview: \(error.localizedDescription)")
    }
}
