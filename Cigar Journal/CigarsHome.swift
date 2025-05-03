// CigarsHome


import SwiftUI
import SwiftData

struct CigarsHome: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \CigarTemplate.date, order: .reverse) var cigars: [CigarTemplate]
    @State private var showAddCigar = false
    @State private var showBackupActionSheet = false
    
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
                CigarDetails(cigar: cigar)
            }
            .toolbar {
                ToolbarItems(
                    showAddCigar: $showAddCigar,
                    hasCigars: !cigars.isEmpty,
                    onBackupRestore: handleBackupRestore
                )
            }
            .confirmationDialog("Backup & Restore", isPresented: $showBackupActionSheet, titleVisibility: .visible) {
                Button("Backup to File") {
                    do {
                        let backups = cigars.map {
                            CigarBackup(
                                name: $0.name,
                                type: $0.type,
                                notes: $0.notes,
                                rating: $0.rating,
                                date: $0.date,
                                photoData: $0.photo,
                                length: $0.length,
                                gauge: $0.gauge,
                                strength: $0.strength,
                                location: $0.location,
                                price: Double($0.price) ?? 0.0
                            )
                        }
                        try BackupManager.saveToJSON(backups)
                    } catch {
                        print("Backup failed: \(error)")
                    }
                }
                
                Button("Restore from File") {
                    do {
                        // Remove all existing cigars
                        for cigar in cigars {
                            modelContext.delete(cigar)
                        }

                        // Insert restored entries
                        let backups = try BackupManager.loadFromJSON()
                        for backup in backups {
                            let restored = CigarTemplate(
                                name: backup.name,
                                shape: backup.type ?? "",
                                length: backup.length ?? "",
                                gauge: backup.gauge ?? "",
                                location: backup.location ?? "",
                                price: String(format: "%.2f", backup.price ?? 0.0),
                                strength: backup.strength ?? "",
                                rating: backup.rating,
                                notes: backup.notes ?? "",
                                date: backup.date,
                                photo: backup.photoData
                            )
                            modelContext.insert(restored)
                        }
                    } catch {
                        print("Restore failed: \(error)")
                    }
                }

                Button("Cancel", role: .cancel) {}
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
    
    private func handleBackupRestore() {
        showBackupActionSheet = true
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
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            Text("Build v\(appVersion)")
                .font(.caption)
                .fontWeight(.light)
                .foregroundColor(Color.gray)
        }
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
    let onBackupRestore: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if hasCigars {
                EditButton()
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: {
                onBackupRestore()
            }) {
                Image(systemName: "arrow.up.forward.and.arrow.down.backward.circle")
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
