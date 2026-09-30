// StarRating
// Five stars. Shows averages to the nearest half star; tappable when given a handler.

import SwiftUI

struct StarRating: View {
    var rating: Double
    var starSpacing: CGFloat = 0
    var onRatingSelected: ((Int) -> Void)?

    private let starColor = Color(red: 1.0, green: 194 / 255, blue: 48 / 255)

    init(rating: Int, starSpacing: CGFloat = 0, onRatingSelected: ((Int) -> Void)? = nil) {
        self.rating = Double(rating)
        self.starSpacing = starSpacing
        self.onRatingSelected = onRatingSelected
    }

    /// An average rating, e.g. 3.7, shown as 3½ stars.
    init(average: Double, starSpacing: CGFloat = 0) {
        self.rating = average
        self.starSpacing = starSpacing
    }

    var body: some View {
        HStack(spacing: starSpacing) {
            ForEach(1...5, id: \.self) { number in
                let star = Image(systemName: symbol(for: number))
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
        .accessibilityValue("\(rating.formatted(.number.precision(.fractionLength(0...1)))) of 5 stars")
        .accessibilityAdjustableAction { direction in
            guard let onRatingSelected else { return }
            let current = Int(rating.rounded())
            switch direction {
            case .increment: onRatingSelected(min(current + 1, 5))
            case .decrement: onRatingSelected(max(current - 1, 1))
            @unknown default: break
            }
        }
    }

    private func symbol(for number: Int) -> String {
        let halves = (rating * 2).rounded() / 2
        if Double(number) <= halves { return "star.fill" }
        if Double(number) - 0.5 == halves { return "star.leadinghalf.filled" }
        return "star"
    }
}

#Preview {
    VStack {
        StarRating(rating: 3)
        StarRating(average: 3.7)
    }
}
