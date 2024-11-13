// StarRating v0.8
// Rewrite 11/9/24

import SwiftUI

struct StarRating: View {
    
    var rating: Int
    let starSpacing: CGFloat = 0  // adjust this value to control spacing
    
    var body: some View {
        
        HStack(spacing: starSpacing) {
            
            ForEach(1...5, id: \.self) { number in
                if number <= rating {
                    Image(systemName: "star.fill")
                        .foregroundColor(Color("AccentColor"))
                } else {
                    Image(systemName: "star")
                        .foregroundColor(Color("AccentColor"))
                }
            }
        }
    }
}

#Preview {
    StarRating(rating: 3)
}
