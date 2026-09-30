// CigarListView
// The Home (smoked cigars) and Humidor (cigars on hand) lists. A cigar can appear in
// both: smoked 3 times with 5 more in the humidor.

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum CigarShelf {
    case journal
    case humidor

    var title: String {
        switch self {
        case .journal: "Cigar Journal"
        case .humidor: "Humidor"
        }
    }

    func includes(_ cigar: CigarTemplate) -> Bool {
        switch self {
        case .journal: cigar.hasBeenSmoked
        case .humidor: cigar.humidorCount > 0
        }
    }
}

enum CigarSortOption: String, CaseIterable, Identifiable {
    case favorites = "Favorites"
    case alphabetical = "Alphabetical"
    case date = "Date"
    case price = "Price"
    case strength = "Strength"
    case rating = "Rating"

    var id: String { rawValue }

    func sorted(_ cigars: [CigarTemplate]) -> [CigarTemplate] {
        switch self {
        case .favorites:
            // Favorites first, then most recently smoked (never-smoked last), then name.
            cigars.sorted { a, b in
                if a.isFavorite != b.isFavorite { return a.isFavorite }
                switch (a.lastSmoked, b.lastSmoked) {
                case let (dateA?, dateB?) where dateA != dateB: return dateA > dateB
                case (.some, nil): return true
                case (nil, .some): return false
                default: return a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
            }
        case .alphabetical:
            cigars.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .date:
            cigars.sorted { ($0.lastSmoked ?? $0.date) > ($1.lastSmoked ?? $1.date) }
        case .price:
            cigars.sorted { ($0.priceValue ?? 0) > ($1.priceValue ?? 0) }
        case .strength:
            cigars.sorted { $0.strengthRank > $1.strengthRank }
        case .rating:
            cigars.sorted { ($0.averageRating ?? 0) > ($1.averageRating ?? 0) }
        }
    }
}

struct CigarListScreen: View {
    let shelf: CigarShelf

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CigarTemplate.date, order: .reverse) private var cigars: [CigarTemplate]

    @AppStorage("sortOption") private var sortOption: CigarSortOption = .date
    @AppStorage("lastBackupDate") private var lastBackupTimestamp: Double = 0

    @State private var navigation = CigarNavigation()
    @State private var showAddCigar = false
    @State private var editingCigar: CigarTemplate?
    @State private var smokingCigar: CigarTemplate?
    @State private var cigarPendingDelete: CigarTemplate?
    @State private var showingSettings = false
    @State private var hasAPIKey = KeychainStore.anthropicAPIKey != nil
    @State private var confirmingRemoveKey = false

    // Backup
    @State private var backupDocument: CigarBackupDocument?
    @State private var backupFilename = ""
    @State private var showingRestorePicker = false
    @State private var pendingRestore: [CigarBackup.Entry]?
    @State private var restoreFoundCount = 0
    @State private var backupErrorMessage: String?

    var body: some View {
        let visibleCigars = sortOption.sorted(cigars.filter(shelf.includes))

        NavigationStack(path: $navigation.path) {
            Group {
                if visibleCigars.isEmpty {
                    emptyState
                } else {
                    List(visibleCigars) { cigar in
                        NavigationLink(value: cigar) {
                            CigarRowView(cigar: cigar)
                        }
                        .swipeActions(edge: .leading) {
                            Button(cigar.hasBeenSmoked ? "Smoke Again" : "Smoke", systemImage: "flame") {
                                smokingCigar = cigar
                            }
                            .tint(.accent)
                            Button(cigar.isFavorite ? "Unfavorite" : "Favorite", systemImage: cigar.isFavorite ? "heart.slash" : "heart") {
                                cigar.isFavorite.toggle()
                            }
                            .tint(.red)
                        }
                        .swipeActions(edge: .trailing) {
                            removeButton(for: cigar)
                            Button("Edit", systemImage: "pencil") {
                                editingCigar = cigar
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(shelf.title)
            .navigationDestination(for: CigarTemplate.self) { cigar in
                CigarDetailView(cigar: cigar, navigation: navigation)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(shelf == .journal ? "Add Cigar" : "Add to Humidor", systemImage: "plus") {
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
            .sheet(isPresented: $showAddCigar, onDismiss: refreshAPIKeyState) {
                AddCigar(startInHumidor: shelf == .humidor)
            }
            .sheet(item: $editingCigar, onDismiss: refreshAPIKeyState) { cigar in
                AddCigar(editCigar: cigar)
            }
            // A key can also be added from Look Up Cigar inside the Add form.
            .onAppear(perform: refreshAPIKeyState)
            .sheet(item: $smokingCigar) { cigar in
                SmokeSheet(cigar: cigar)
            }
            .sheet(isPresented: $showingSettings, onDismiss: refreshAPIKeyState) {
                SettingsView()
            }
            .confirmationDialog("Remove the API key?", isPresented: $confirmingRemoveKey, titleVisibility: .visible) {
                Button("Remove API Key", role: .destructive) {
                    KeychainStore.delete(KeychainStore.anthropicAPIKeyAccount)
                    refreshAPIKeyState()
                }
            } message: {
                Text("Look Up Cigar won't be able to search the web until you add a key again.")
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
                Text("This deletes the cigar and all its smokes, including from iCloud on all your devices.")
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

    @ViewBuilder
    private var emptyState: some View {
        switch shelf {
        case .journal:
            ContentUnavailableView {
                Label("No Cigars Yet", systemImage: "list.bullet")
            } description: {
                Text("Tap + to add a cigar you've smoked.")
            }
        case .humidor:
            ContentUnavailableView {
                Label("Humidor Is Empty", systemImage: "archivebox")
            } description: {
                Text("Tap + to add cigars you haven't smoked yet.")
            }
        }
    }

    /// In the Humidor, a cigar you've already smoked is just taken out of the humidor;
    /// anything else is deleted (after confirming).
    @ViewBuilder
    private func removeButton(for cigar: CigarTemplate) -> some View {
        if shelf == .humidor && cigar.hasBeenSmoked {
            Button("Remove", systemImage: "archivebox", role: .destructive) {
                withAnimation {
                    cigar.humidorCount = 0
                }
            }
        } else {
            Button("Delete", systemImage: "trash", role: .destructive) {
                cigarPendingDelete = cigar
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

            if shelf == .journal {
                Section {
                    Button("Export Backup…", systemImage: "square.and.arrow.up", action: exportBackup)
                        .disabled(cigars.isEmpty)
                    Button("Restore Backup…", systemImage: "arrow.counterclockwise") {
                        showingRestorePicker = true
                    }
                    Text(lastBackupText)
                }

                Section {
                    if hasAPIKey {
                        Button("Remove API Key…", systemImage: "key.slash", role: .destructive) {
                            confirmingRemoveKey = true
                        }
                    } else {
                        Button("Add API Key…", systemImage: "key") {
                            showingSettings = true
                        }
                    }
                }

                Section {
                    Text("v\(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
                }
            }
        }
    }

    private func refreshAPIKeyState() {
        hasAPIKey = KeychainStore.anthropicAPIKey != nil
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
    /// Shows "Smoked" / "In Humidor" tags, for search results that mix both lists.
    var showsShelfTags = false

    private var metadataLine: String {
        [cigar.type, cigar.strength, cigar.displayPrice].compactMap { $0 }.joined(separator: "  •  ")
    }

    var body: some View {
        HStack(spacing: 12) {
            CigarPhotoView(photo: cigar.photo, maxPointSize: 84)
                .frame(width: 84, height: 84)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if cigar.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .shadow(color: .black.opacity(0.25), radius: 2)
                            .padding(6)
                            .accessibilityLabel("Favorite")
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(cigar.name)
                    .font(.headline)

                Text(metadataLine)
                    .font(.callout)
                    .foregroundStyle(.accent)

                if let average = cigar.averageRating {
                    StarRating(average: average)
                        .font(.caption)
                } else {
                    Text("Not smoked yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if showsShelfTags {
                    HStack(spacing: 6) {
                        if cigar.hasBeenSmoked { ShelfTag(title: "Smoked") }
                        if cigar.humidorCount > 0 { ShelfTag(title: "In Humidor") }
                    }
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 10) {
                if cigar.smokeCount > 1 {
                    Label("\(cigar.smokeCount)x", systemImage: "medal")
                        .accessibilityLabel("Smoked \(cigar.smokeCount) times")
                }
                if cigar.humidorCount > 0 {
                    Label("\(cigar.humidorCount)", systemImage: "archivebox")
                        .accessibilityLabel("\(cigar.humidorCount) in humidor")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.accent)
            .labelStyle(CompactLabelStyle())
        }
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

private struct ShelfTag: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.accent.opacity(0.12), in: .capsule)
            .foregroundStyle(.accent)
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "" }
    var buildNumber: String { infoDictionary?["CFBundleVersion"] as? String ?? "" }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: CigarTemplate.self, SmokeSession.self, configurations: config)
        container.mainContext.insert(CigarTemplate(name: "Casa Magna Colorado", type: "Robusto", length: "5.50", gauge: "52", location: "Local Shop", price: "9.87", strength: "Medium", rating: 5, notes: "Dark chocolate, nutmeg and wood.", date: .now))

        return CigarListScreen(shelf: .journal)
            .modelContainer(container)
    } catch {
        return Text("Failed to load preview: \(error.localizedDescription)")
    }
}
