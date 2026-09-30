// RootTabView
// Home and Humidor tabs, plus the system search tab.

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                CigarListScreen(shelf: .journal)
            }
            Tab("Humidor", systemImage: "archivebox") {
                CigarListScreen(shelf: .humidor)
            }
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchTabView()
            }
        }
    }
}

/// Each tab's navigation path. The details screen watches it so its panel can close
/// the moment you go back, instead of lingering until the screen is gone.
@Observable
final class CigarNavigation {
    var path: [CigarTemplate] = []
}
