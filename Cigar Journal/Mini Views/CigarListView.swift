//
//  CigarListView.swift
//  Cigar Journal
//
//  Created by David Wilder on 7/1/25.
//

import SwiftUI

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
    }
}

#Preview {
    CigarListView(cigars: SampleData.cigars) { _ in }
}
