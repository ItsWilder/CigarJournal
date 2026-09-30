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
