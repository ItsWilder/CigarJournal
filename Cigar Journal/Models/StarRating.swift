// StarRating

import SwiftUI

struct StarRating: View {
    
    var rating: Int
    var starSpacing: CGFloat = 0
    var isInteractive: Bool = false
    var onRatingSelected: ((Int) -> Void)?
    private let starColor = Color(red: 1.0, green: 194 / 255, blue: 48 / 255)
    
    var body: some View {
        HStack(spacing: starSpacing) {
            ForEach(1...5, id: \.self) { number in
                if isInteractive {
                    Button {
                        onRatingSelected?(number)
                    } label: {
                        Image(systemName: number <= rating ? "star.fill" : "star")
                            .foregroundColor(starColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Set rating to \(number)")
                } else {
                    Image(systemName: number <= rating ? "star.fill" : "star")
                        .foregroundColor(starColor)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rating")
        .accessibilityValue("\(rating) of 5 stars")
    }
}

#Preview {
    StarRating(rating: 3)
}
