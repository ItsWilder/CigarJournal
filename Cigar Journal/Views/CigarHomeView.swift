// CigarsHome


import SwiftUI
import SwiftData


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
    @AppStorage("hasSeededDemoCigars") private var hasSeededDemoCigars = false
    @State private var showAddCigar = false
    @State private var sortOption: CigarSortOption = .date

    
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
                    sortOption: $sortOption
                )
            }
            .sheet(isPresented: $showAddCigar) {
                AddCigar()
            }
        }
        .task {
            seedDemoDataIfNeeded()
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
    
    private func seedDemoDataIfNeeded() {
        guard !hasSeededDemoCigars, cigars.isEmpty else { return }

        for cigar in CigarDemoData.templates() {
            modelContext.insert(cigar)
        }

        do {
            try modelContext.save()
            hasSeededDemoCigars = true
        } catch {
            print("Demo data seed failed: \(error)")
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
            Divider()
            Text("v\(version) (\(build))")
        } label: {
            Label("Options", systemImage: "ellipsis")
        }
    }

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) {
                if hasCigars {
                    EditButton()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                addButton
            }
            ToolbarItem(placement: .primaryAction) {
                overflowMenu
            }
        } else {
            ToolbarItem(placement: .navigationBarLeading) {
                if hasCigars {
                    EditButton()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                addButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                overflowMenu
            }
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CigarTemplate.self, configurations: config)
        let context = container.mainContext

        for cigar in CigarDemoData.templates() {
            context.insert(cigar)
        }

        return CigarsHome()
            .modelContainer(container)
    } catch {
        return Text("Failed to load preview: \(error.localizedDescription)")
    }
}
