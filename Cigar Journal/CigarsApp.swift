
// TEST - Build v0.13

import SwiftUI
import SwiftData

@main
struct CigarsApp: App {
    var body: some Scene {
        WindowGroup {
            CigarsHome()
        }
        .modelContainer(for: CigarTemplate.self)
    }
}

