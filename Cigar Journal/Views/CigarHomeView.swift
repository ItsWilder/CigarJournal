// CigarsHome


import SwiftUI
import SwiftData


let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

struct CigarsHome: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \CigarTemplate.date, order: .reverse) var cigars: [CigarTemplate]
    @AppStorage("hasSeededDemoCigars") private var hasSeededDemoCigars = false
    @State private var showAddCigar = false

    
    var body: some View {
        NavigationStack {
            Group {
                if cigars.isEmpty {
                    WelcomeView()
                        .padding(.top, -100)
                } else {
                    CigarListView(cigars: cigars, deleteCigar: deleteCigar)
                }
            }
            .navigationTitle("Cigar Journal")
            .navigationDestination(for: CigarTemplate.self) { cigar in
                if let index = cigars.firstIndex(of: cigar) {
                    CigarDetails(cigars: cigars, selectedIndex: index)
                }
            }
            .toolbar {
                ToolbarItems(
                    showAddCigar: $showAddCigar,
                    hasCigars: !cigars.isEmpty
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
                modelContext.delete(cigars[index])
            }
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
        
        Text("Build \(version) (\(build))")
            .font(.footnote)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical)
    }
}

// Cigar Row View
struct CigarRowView: View {
    let cigar: CigarTemplate
    
    var body: some View {
        NavigationLink(value: cigar) {
            HStack {
                CigarImageView(photo: cigar.photo)
                    .padding(.trailing, 1)
                
                VStack(alignment: .leading) {
                    Text(cigar.name)
                        .font(.headline)
                        .padding(.bottom, 2)
                    Text(cigar.date.formatted(date: .numeric, time: .omitted))
                        .font(.caption)
                        .fontWeight(.regular)
                        .foregroundColor(.accentColor)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(cigar.price == "~" ? "~" : "$\(cigar.price)")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .padding(.bottom, 4)
                    StarRating(rating: cigar.rating)
                        .font(.caption)
                }
            }
        }
    }
}

// Cigar Image View
struct CigarImageView: View {
    var photo: Data?

    private let outerSize: CGFloat = 84
    private let innerSize: CGFloat = 60
    private let outerCornerRadius: CGFloat = 16

    var body: some View {
        let inset = (outerSize - innerSize) / 2
        let innerCornerRadius = max(0, outerCornerRadius - inset)
        let outerShape = RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
        let innerShape = RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)

        ZStack {
            outerShape
                .fill(Color(.brown))
                .frame(width: outerSize, height: outerSize)
            
            if let imageData = photo,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: innerSize, height: innerSize)
                    .clipShape(innerShape)
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

    private var addButton: some View {
        Button("Add Cigar", systemImage: "plus") {
            showAddCigar.toggle()
        }
        .buttonStyle(.borderedProminent)
        .tint(Color("AccentColor"))
    }

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) {
                if hasCigars {
                    EditButton()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                addButton
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
