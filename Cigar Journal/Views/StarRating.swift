// StarRating

import SwiftUI

struct StarRating: View {
    var rating: Int
    var starSpacing: CGFloat = 0
    var onRatingSelected: ((Int) -> Void)?

    private let starColor = Color(red: 1.0, green: 194 / 255, blue: 48 / 255)

    var body: some View {
        HStack(spacing: starSpacing) {
            ForEach(1...5, id: \.self) { number in
                let star = Image(systemName: number <= rating ? "star.fill" : "star")
                    .foregroundStyle(starColor)

                if let onRatingSelected {
                    Button {
                        onRatingSelected(number)
                    } label: {
                        star
                    }
                    .buttonStyle(.plain)
                } else {
                    star
                }
            }
        }
        .sensoryFeedback(.selection, trigger: rating) { _, _ in onRatingSelected != nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue("\(rating) of 5 stars")
        .accessibilityAdjustableAction { direction in
            guard let onRatingSelected else { return }
            switch direction {
            case .increment: onRatingSelected(min(rating + 1, 5))
            case .decrement: onRatingSelected(max(rating - 1, 1))
            @unknown default: break
            }
        }
    }
}

#Preview {
    StarRating(rating: 3)
}
