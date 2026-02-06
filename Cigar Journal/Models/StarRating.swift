// StarRating

import SwiftUI

struct StarRating: View {
    
    var rating: Int
    let starSpacing: CGFloat = 0  // adjust this value to control spacing
    private let starColor = Color(red: 1.0, green: 194 / 255, blue: 48 / 255)
    
    var body: some View {
        
        HStack(spacing: starSpacing) {
            
            ForEach(1...5, id: \.self) { number in
                if number <= rating {
                    Image(systemName: "star.fill")
                        .foregroundColor(starColor)
                } else {
                    Image(systemName: "star")
                        .foregroundColor(starColor)
                }
            }
        }
    }
}

#Preview {
    StarRating(rating: 3)
}
