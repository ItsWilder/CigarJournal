// Build v1.0

import OSLog
import SwiftData
import SwiftUI

@main
struct CigarsApp: App {
    private let sharedModelContainer = makeModelContainer()

    var body: some Scene {
        WindowGroup {
            CigarsHome()
        }
        .modelContainer(sharedModelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        let logger = Logger(subsystem: "ItsWilder.CigarJournal", category: "Storage")

        #if DEBUG
        // Launch with -InMemoryStore to test in the simulator without touching iCloud.
        if ProcessInfo.processInfo.arguments.contains("-InMemoryStore") {
            let memoryConfiguration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: CigarTemplate.self, configurations: memoryConfiguration)
            } catch {
                fatalError("Unable to create in-memory model container: \(error)")
            }
        }
        #endif

        let cloudConfiguration = ModelConfiguration(cloudKitDatabase: .automatic)

        do {
            return try ModelContainer(for: CigarTemplate.self, configurations: cloudConfiguration)
        } catch {
            logger.error("CloudKit model container init failed, falling back to local store: \(error)")
            let localConfiguration = ModelConfiguration(cloudKitDatabase: .none)

            do {
                return try ModelContainer(for: CigarTemplate.self, configurations: localConfiguration)
            } catch {
                fatalError("Unable to initialize SwiftData model container: \(error)")
            }
        }
    }
}
