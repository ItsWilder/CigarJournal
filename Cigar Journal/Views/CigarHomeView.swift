// CigarsHome


import SwiftUI
import SwiftData

struct CigarsHome: View {
    
    @Environment(\.modelContext) var modelContext
    @Query(sort: \CigarTemplate.date, order: .reverse) var cigars: [CigarTemplate]
    @State private var showAddCigar = false
    @State private var showBackupActionSheet = false
    
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    if !cigars.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Cigar", systemImage: "plus") {
                        showAddCigar.toggle()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        #if targetEnvironment(simulator)
                        Button("Delete All Cigars", role: .destructive) {
                            deleteAllCigars()
                        }
                        Button("Install Sample Cigars") {
                            installSampleCigars()
                        }
                        #endif
                        Text("Version \(version) (\(build))")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical)
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button(action: {
//                        handleBackupRestore()
//                    }) {
//                        Image(systemName: "arrow.up.forward.and.arrow.down.backward.circle")
//                    }
//                }

            }
            .sheet(isPresented: $showAddCigar) {
                AddCigar()
            }
//            .confirmationDialog("Backup & Restore", isPresented: $showBackupActionSheet, titleVisibility: .visible) {
//                Button("Backup to File") {
//                    do {
//                        let backups = cigars.map {
//                            CigarBackup(
//                                name: $0.name,
//                                type: $0.type,
//                                notes: $0.notes,
//                                rating: $0.rating,
//                                date: $0.date,
//                                photoData: $0.photo,
//                                length: $0.length,
//                                gauge: $0.gauge,
//                                strength: $0.strength,
//                                location: $0.location,
//                                price: Double($0.price) ?? 0.0
//                            )
//                        }
//                        try BackupManager.saveToJSON(backups)
//                        showBackupSuccess = true
//                    } catch {
//                        print("Backup failed: \(error)")
//                    }
//                }
//                
//                Button("Restore from File") {
//                    do {
//                        // Remove all existing cigars
//                        for cigar in cigars {
//                            modelContext.delete(cigar)
//                        }
//
//                        // Insert restored entries
//                        let backups = try BackupManager.loadFromJSON()
//                        for backup in backups {
//                            let restored = CigarTemplate(
//                                name: backup.name,
//                                shape: backup.type ?? "",
//                                length: backup.length ?? "",
//                                gauge: backup.gauge ?? "",
//                                location: backup.location ?? "",
//                                price: String(format: "%.2f", backup.price ?? 0.0),
//                                strength: backup.strength ?? "",
//                                rating: backup.rating,
//                                notes: backup.notes ?? "",
//                                date: backup.date,
//                                photo: backup.photoData
//                            )
//                            modelContext.insert(restored)
//                        }
//                    } catch {
//                        print("Restore failed: \(error)")
//                    }
//                }
//                Button("Cancel", role: .cancel) {}
//            }
//            .alert("Backup complete!", isPresented: $showBackupSuccess) {
//                Button("OK", role: .cancel) {}
//            }
        }
    }
    
    private func deleteAllCigars() {
        withAnimation {
            for cigar in cigars {
                modelContext.delete(cigar)
            }
        }
    }

    private func installSampleCigars() {
        withAnimation {
            for cigar in SampleData.cigars {
                modelContext.insert(cigar)
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
    
//    private func handleBackupRestore() {
//        showBackupActionSheet = true
//    }
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
