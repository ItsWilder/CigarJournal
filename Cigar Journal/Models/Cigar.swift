// CigarTemplate
//
// ⚠️ This class is the CloudKit schema. Don't rename the class or any stored
// property, and don't change their types, or existing iCloud data will stop
// showing up. Add computed helpers in the extension below instead.

import Foundation
import SwiftData

@Model
class CigarTemplate {
    var name: String = ""
    var type: String = "Robusto"
    var length: String = "6"
    var gauge: String = "50"
    var location: String = "~"
    var price: String = "0.00"
    var strength: String = "Medium"
    var rating: Int = 3
    var notes: String = ""
    var date: Date = Date()
    var photo: Data?

    init(name: String, type: String, length: String, gauge: String, location: String, price: String, strength: String, rating: Int, notes: String, date: Date, photo: Data? = nil) {
        self.name = name
        self.type = type
        self.length = length
        self.gauge = gauge
        self.location = location
        self.price = price
        self.strength = strength
        self.rating = rating
        self.notes = notes
        self.date = date
        self.photo = photo
    }
}

// MARK: - Options and display helpers

extension CigarTemplate {
    static let typeOptions = [
        "Petite Corona", "Half Corona", "Corona", "Rothschild", "Robusto", "Toro", "Gordo",
        "Lonsdale", "Churchill", "Lancero", "Double Corona", "Presidente", "Grande",
        "Torpedo", "Belicoso", "Perfecto"
    ]
    static let strengthOptions = ["Mild", "Medium", "Strong"]
    static let lengthOptions = stride(from: 3.0, through: 9.0, by: 0.125).map(formatLength)
    static let gaugeOptions = Array(26...70).map(String.init)

    /// Placeholders the app writes when a field is left blank.
    static let emptyLocation = "~"
    static let emptyPrice = "0.00"

    var priceValue: Double? {
        Double(price.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: ""))
    }

    /// "$9.87", or nil when no price was entered.
    var displayPrice: String? {
        guard let priceValue, priceValue > 0 else { return nil }
        return priceValue.formatted(.currency(code: "USD"))
    }

    /// The store name, or nil when none was entered.
    var displayLocation: String? {
        let trimmed = location.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed == Self.emptyLocation ? nil : trimmed
    }

    var strengthRank: Int {
        switch strength.lowercased() {
        case "strong", "full": 3
        case "medium": 2
        case "mild": 1
        default: 0
        }
    }

    // MARK: Length

    /// Formats inches the way lengths are stored: "6.00", "6.25", "6.125".
    nonisolated static func formatLength(_ inches: Double) -> String {
        var text = String(format: "%.3f", inches)
        if text.hasSuffix("0") { text.removeLast() }
        return text
    }

    /// Parses "6", "6.125", "6 1/8", "6-1/8" or "6⅛\"" into inches.
    nonisolated static func parseLength(_ raw: String) -> Double? {
        let fractions: [Character: Double] = ["⅛": 0.125, "¼": 0.25, "⅜": 0.375, "½": 0.5, "⅝": 0.625, "¾": 0.75, "⅞": 0.875]
        var text = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
        var extra = 0.0
        if let last = text.last, let value = fractions[last] {
            extra = value
            text.removeLast()
        }

        let parts = text.split(whereSeparator: { $0 == " " || $0 == "-" })
        if parts.count == 2, let whole = Double(parts[0]) {
            let fraction = parts[1].split(separator: "/")
            if fraction.count == 2, let top = Double(fraction[0]), let bottom = Double(fraction[1]), bottom > 0 {
                return whole + top / bottom
            }
            return nil
        }
        if text.isEmpty { return extra > 0 ? extra : nil }
        return Double(text).map { $0 + extra }
    }

    /// Snaps a stored length to the picker's 1/8" steps. Unparseable values are kept as-is
    /// so editing an old entry never silently changes its length.
    nonisolated static func normalizedLength(_ raw: String) -> String {
        guard let inches = parseLength(raw) else { return raw.isEmpty ? "6.00" : raw }
        return formatLength((inches * 8).rounded() / 8)
    }
}
