// CigarsHome


import SwiftUI
import SwiftData


let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

struct CigarsHome: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \CigarTemplate.date, order: .reverse) var cigars: [CigarTemplate]
    @State private var showAddCigar = false
    @State private var showBackupActionSheet = false
    @State private var showBackupSuccess = false

    
    var body: some View {
        NavigationStack {
            Group {
                if cigars.isEmpty {
                    EmptyStateHomeView()
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
                        showBackupSuccess = true
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
        .alert("Backup complete!", isPresented: $showBackupSuccess) {
            Button("OK", role: .cancel) {}
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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CigarTemplate.self, configurations: config)

    for cigar in SampleData.cigars {
        container.mainContext.insert(cigar)
    }

    return CigarsHome()
        .modelContainer(container)
}
