
// Build v1.0

import SwiftUI
import SwiftData

@main
struct CigarsApp: App {
    private var sharedModelContainer: ModelContainer = {
        let cloudConfiguration = ModelConfiguration(cloudKitDatabase: .automatic)

        do {
            return try ModelContainer(for: CigarTemplate.self, configurations: cloudConfiguration)
        } catch {
            print("CloudKit model container init failed, falling back to local store: \(error)")
            let localConfiguration = ModelConfiguration(cloudKitDatabase: .none)

            do {
                return try ModelContainer(for: CigarTemplate.self, configurations: localConfiguration)
            } catch {
                fatalError("Unable to initialize SwiftData model container: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            CigarsHome()
        }
        .modelContainer(sharedModelContainer)
    }
}
