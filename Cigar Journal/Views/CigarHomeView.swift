// CigarsHome


import SwiftUI
import SwiftData
import UniformTypeIdentifiers


let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

enum CigarSortOption: String, CaseIterable, Identifiable {
    case alphabetical = "Alphabetical"
    case date = "Date"
    case price = "Price"
    case strength = "Strength"
    case rating = "Rating"

    var id: String { rawValue }
}

struct CigarsHome: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \CigarTemplate.date, order: .reverse) var cigars: [CigarTemplate]
    @AppStorage("lastBackupDate") private var lastBackupTimestamp: Double = 0
    @State private var showAddCigar = false
    @State private var sortOption: CigarSortOption = .date
    @State private var backupDocument: CigarBackupDocument?
    @State private var backupFilename = ""
    @State private var showingRestorePicker = false
    @State private var pendingRestore: [CigarBackup.Entry]?
    @State private var restoreFoundCount = 0
    @State private var backupErrorMessage: String?

    
    var body: some View {
        NavigationStack {
            Group {
                if cigars.isEmpty {
                    WelcomeView()
                        .padding(.top, -100)
                } else {
                    CigarListView(cigars: sortedCigars, deleteCigar: deleteCigar)
                }
            }
            .navigationTitle("Cigar Journal")
            .navigationDestination(for: CigarTemplate.self) { cigar in
                if let index = sortedCigars.firstIndex(of: cigar) {
                    CigarDetails(cigars: sortedCigars, selectedIndex: index)
                }
            }
            .toolbar {
                ToolbarItems(
                    showAddCigar: $showAddCigar,
                    hasCigars: !cigars.isEmpty,
                    sortOption: $sortOption,
                    lastBackupDate: lastBackupTimestamp > 0 ? Date(timeIntervalSince1970: lastBackupTimestamp) : nil,
                    exportBackup: exportBackup,
                    restoreBackup: { showingRestorePicker = true }
                )
            }
            .sheet(isPresented: $showAddCigar) {
                AddCigar()
            }
            .fileExporter(
                isPresented: Binding(get: { backupDocument != nil }, set: { if !$0 { backupDocument = nil } }),
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
            .alert(
                "Restore Backup",
                isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                presenting: pendingRestore
            ) { entries in
                if !entries.isEmpty {
                    Button("Add \(entries.count) Cigars") {
                        CigarBackup.insert(entries, into: modelContext)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { entries in
                Text("Found \(restoreFoundCount) cigars, \(restoreFoundCount - entries.count) already in your journal. Restoring only adds missing cigars; nothing is changed or deleted.")
            }
            .alert(
                "Backup Failed",
                isPresented: Binding(get: { backupErrorMessage != nil }, set: { if !$0 { backupErrorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupErrorMessage ?? "")
            }
        }
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
    
    private func deleteCigar(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sortedCigars[index])
            }
        }
    }

    private var sortedCigars: [CigarTemplate] {
        switch sortOption {
        case .alphabetical:
            return cigars.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .date:
            return cigars.sorted { $0.date > $1.date }
        case .price:
            return cigars.sorted { (Double($0.price) ?? 0) > (Double($1.price) ?? 0) }
        case .strength:
            return cigars.sorted { strengthRank($0.strength) > strengthRank($1.strength) }
        case .rating:
            return cigars.sorted { $0.rating > $1.rating }
        }
    }

    private func strengthRank(_ strength: String) -> Int {
        switch strength.lowercased() {
        case "strong":
            return 3
        case "medium":
            return 2
        case "mild":
            return 1
        default:
            return 0
        }
    }
}

// Welcome View
struct WelcomeView: View {
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Icon and Welcome
            Image(systemName: "list.bullet")
                .font(.system(size: 60))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.brown, Color("AccentColor"))
                .symbolEffect(.bounce, value: animate)
                .onTapGesture { animate.toggle() }
            
            Text("Welcome!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
            
            Text("Tap the '+' button in the top right corner to add your first cigar.")
                .padding(.top, 1)
                .padding(.horizontal, 20)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .font(.footnote)

            .padding(.horizontal, 60)
            .padding(.top, 260)
        }
    }
}

// Cigar List View
struct CigarListView: View {
    let cigars: [CigarTemplate]
    let deleteCigar: (IndexSet) -> Void
    
    var body: some View {
        List {
            ForEach(cigars) { cigar in
                CigarRowView(cigar: cigar)
                    .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteCigar)
        }
        .listStyle(PlainListStyle())
    }
}

// Cigar Row View
struct CigarRowView: View {
    let cigar: CigarTemplate

    private var priceText: String {
        cigar.price == "~" ? "~" : "$\(cigar.price)"
    }

    private var metadataLine: String {
        "\(cigar.type)  •  \(cigar.strength)  •  \(priceText)"
    }
    
    var body: some View {
        NavigationLink(value: cigar) {
            HStack {
                CigarImageView(photo: cigar.photo)
                    .padding(.trailing, 1)
                
                VStack(alignment: .leading) {
                    Text(cigar.name)
                        .font(.headline)

                    Text(metadataLine)
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.accentColor)
                        .opacity(0.9)
                        .padding(.bottom, 4)

                    StarRating(rating: cigar.rating)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                Spacer()
            }
        }
    }
}

// Cigar Image View
struct CigarImageView: View {
    var photo: Data?

    private let tileSize: CGFloat = 84
    private let cornerRadius: CGFloat = 16

    var body: some View {
        let tileShape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            tileShape
                .fill(Color(.brown))
                .frame(width: tileSize, height: tileSize)
            
            if let imageData = photo,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: tileSize, height: tileSize)
                    .clipShape(tileShape)
            } else {
                Image(systemName: "photo.on.rectangle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(Color("AccentDarkColor"))
            }
        }
    }
}

// Toolbar Items
struct ToolbarItems: ToolbarContent {
    @Binding var showAddCigar: Bool
    let hasCigars: Bool
    @Binding var sortOption: CigarSortOption
    let lastBackupDate: Date?
    let exportBackup: () -> Void
    let restoreBackup: () -> Void

    private var addButton: some View {
        Button("Add Cigar", systemImage: "plus") {
            showAddCigar.toggle()
        }
        .buttonStyle(.borderedProminent)
        .tint(Color("AccentColor"))
    }

    private var overflowMenu: some View {
        Menu {
            Menu {
                Picker("Sort Option", selection: $sortOption) {
                    ForEach(CigarSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Sort By", systemImage: "arrow.up.arrow.down")
                    Text(sortOption.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button("Export Backup…", systemImage: "square.and.arrow.up", action: exportBackup)
                    .disabled(!hasCigars)
                Button("Restore Backup…", systemImage: "arrow.counterclockwise", action: restoreBackup)
                Text(lastBackupDate.map { "Last backup: \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "No backup yet")
            }
            Divider()
            Text("v\(version) (\(build))")
        } label: {
            Label("Options", systemImage: "ellipsis")
        }
    }

    var body: some ToolbarContent {
            ToolbarItem(placement: .topBarLeading) {
                if hasCigars {
                    EditButton()
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                addButton
                overflowMenu
            }
    }
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
