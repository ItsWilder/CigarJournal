// CigarsApp v0.2
// Rewrite 11/9/24

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

