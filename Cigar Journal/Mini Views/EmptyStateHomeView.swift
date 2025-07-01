//
//  EmptyStateHomeView.swift
//  Cigar Journal
//
//  Created by David Wilder on 7/1/25.
//

import SwiftUI

/// A view that is shown to new users with no cigars
struct EmptyStateHomeView: View {
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "list.bullet")
                .font(.system(size: 60))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.brown, Color("AccentColor"))
            
            Text("Welcome!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
            
            Text("Tap the '+' button in the top right\ncorner to add your first cigar.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer ()
        }
    }
}

#Preview {
    EmptyStateHomeView()
}
