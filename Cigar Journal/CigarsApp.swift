
// TEST - Build v0.14

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

