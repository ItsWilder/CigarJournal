// CigarsHome


import SwiftUI
import SwiftData

struct CigarsHome: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \CigarTemplate.date, order: .reverse) var cigars: [CigarTemplate]
    @State private var showAddCigar = false
    
    var body: some View {
        NavigationStack {
            Group {
                if cigars.isEmpty {
                    WelcomeView()
                        .padding(.top, -100)
                } else {
                    CigarListView(cigars: cigars, deleteCigar: deleteCigar)
                        .padding(.top, 8.0)
                }
            }
            .navigationTitle("Cigar Journal")
            .navigationDestination(for: CigarTemplate.self) { cigar in
                CigarDetails(cigar: cigar)
            }
            .toolbar {
                ToolbarItems(showAddCigar: $showAddCigar, hasCigars: !cigars.isEmpty)
            }
            .sheet(isPresented: $showAddCigar) {
                AddCigar()
            }
        }
    }
    
    private func deleteCigar(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(cigars[index])
            }
        }
    }
}

// Welcome View
struct WelcomeView: View {
    @State private var animate = false
    
    private let warningMessages = [
        "Tobacco smoke can harm your children.",
        "Smoking causes cancer.",
        "Smoking causes heart disease and strokes.",
        "Smoking during pregnancy can harm your baby.",
        "Smoking can kill you.",
        "Tobacco smoke causes fatal lung disease in nonsmokers.",
        "Quitting smoking now greatly reduces serious risks to your health.",
        "Smoking causes COPD, a lung disease that can be fatal.",
        "Tobacco smoke can trigger severe asthma attacks.",
        "Smoking causes type 2 diabetes mellitus.",
        "Smoking reduces blood flow, which can cause erectile dysfunction."
    ]
    
    private var randomWarning: String {
        warningMessages.randomElement() ?? warningMessages[0]
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Icon and Welcome
            Image(systemName: animate ? "checkmark" : "list.bullet")
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
                .padding(.horizontal, 60)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Warning Section
            VStack {
                Text("WARNING:")
                    .padding(.top, 30)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                Text(randomWarning)
                    .padding(.top, 1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
                    .frame(height: 50)
            }
            
            // Help Information
            VStack {
                Text("If you or someone you know needs help to quit smoking the American Lung Association's proven tools, tips and support can help you or your loved one end your addiction to tobacco and begin a new, smokefree phase of your life.")
                
                Link("Visit American Lung Association",
                     destination: URL(string: "https://www.lung.org/quit-smoking")!)
                    .padding(.top, 4)
            }
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 60)
            .padding(.top, 60)
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
        Text("Beta Build v0.14")
            .font(.caption)
            .fontWeight(.light)
            .foregroundColor(Color.gray)
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
            .padding(.vertical, 6)
        }
    }
}

// Cigar Image View
struct CigarImageView: View {
    var photo: Data?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.brown))
                .frame(width: 60, height: 60)
            
            if let imageData = photo,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
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
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if hasCigars {
                EditButton()
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Add Cigar", systemImage: "plus") {
                showAddCigar.toggle()
            }
        }
    }
}

#Preview {
    CigarsHome()
}
