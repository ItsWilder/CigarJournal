// CigarTemplate
//
// ⚠️ This class is the CloudKit schema. Don't rename the class or any stored
// property, and don't change their types, or existing iCloud data will stop
// showing up. New properties must be optional (or have a default) so older
// records still load. Add computed helpers in the extensions below instead.

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

    // Where the cigar was bought, picked from Apple Maps. `location` keeps the store name.
    var storePlaceID: String?
    var storeLatitude: Double?
    var storeLongitude: Double?
    var storeAddress: String?

    // 2.0: tobacco, favorites, humidor and repeat smokes.
    var wrapper: String?
    var binder: String?
    var filler: String?
    var origin: String?
    var isFavorite: Bool = false
    /// How many of this cigar are in the humidor right now.
    var humidorCount: Int = 0
    /// False for a cigar bought for the humidor and not smoked yet. Existing cigars
    /// default to true: their `date`, `rating` and `notes` are their first smoke.
    var hasBeenSmoked: Bool = true
    /// Every smoke after the first (the first lives in `date`, `rating` and `notes`).
    @Relationship(deleteRule: .cascade, inverse: \SmokeSession.cigar)
    var smokeSessions: [SmokeSession]? = []

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
    nonisolated static let typeOptions = [
        "Petite Corona", "Half Corona", "Corona", "Rothschild", "Robusto", "Toro", "Gordo",
        "Lonsdale", "Churchill", "Lancero", "Double Corona", "Presidente", "Grande",
        "Torpedo", "Belicoso", "Perfecto"
    ]
    nonisolated static let strengthOptions = ["Mild", "Medium", "Strong"]
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

    /// The store's map location, or nil for cigars logged with just a store name.
    var storePlace: StorePlace? {
        get {
            guard let storeLatitude, let storeLongitude else { return nil }
            return StorePlace(
                name: displayLocation ?? "Store",
                placeID: storePlaceID,
                latitude: storeLatitude,
                longitude: storeLongitude,
                address: storeAddress
            )
        }
        set {
            storePlaceID = newValue?.placeID
            storeLatitude = newValue?.latitude
            storeLongitude = newValue?.longitude
            storeAddress = newValue?.address
        }
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

// MARK: - Smokes

/// A repeat smoke of a cigar already in the journal.
@Model
class SmokeSession {
    var date: Date = Date()
    var rating: Int = 3
    var notes: String = ""
    var cigar: CigarTemplate?

    init(date: Date, rating: Int, notes: String) {
        self.date = date
        self.rating = rating
        self.notes = notes
    }
}

/// One smoke, whether it's the cigar's first (stored on the cigar) or a later session.
nonisolated struct SmokeEntry: Identifiable {
    let id: AnyHashable
    let date: Date
    let rating: Int
    let notes: String
    /// Nil for the first smoke.
    let session: SmokeSession?
}

extension CigarTemplate {
    /// Every smoke, newest first.
    var smokes: [SmokeEntry] {
        guard hasBeenSmoked else { return [] }
        let first = SmokeEntry(id: "first", date: date, rating: rating, notes: notes, session: nil)
        let later = (smokeSessions ?? []).map {
            SmokeEntry(id: $0.persistentModelID, date: $0.date, rating: $0.rating, notes: $0.notes, session: $0)
        }
        return ([first] + later).sorted { $0.date > $1.date }
    }

    var smokeCount: Int {
        hasBeenSmoked ? 1 + (smokeSessions?.count ?? 0) : 0
    }

    var lastSmoked: Date? {
        smokes.first?.date
    }

    /// Average rating across every smoke, or nil if it hasn't been smoked.
    var averageRating: Double? {
        let ratings = smokes.map(\.rating)
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }

    /// Notes from the most recent smoke that has any.
    var latestNotes: String? {
        smokes.first { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?.notes
    }

    /// Records a smoke: the first one fills the cigar itself, later ones become sessions.
    /// Takes one out of the humidor if there are any.
    func recordSmoke(date: Date, rating: Int, notes: String, in context: ModelContext) {
        if hasBeenSmoked {
            let session = SmokeSession(date: date, rating: rating, notes: notes)
            context.insert(session)
            session.cigar = self
        } else {
            hasBeenSmoked = true
            self.date = date
            self.rating = rating
            self.notes = notes
        }
        if humidorCount > 0 {
            humidorCount -= 1
        }
    }
}

// MARK: - Store location

/// A store picked from Apple Maps. `placeID` lets Maps reopen the exact place card;
/// the coordinates and address are a fallback if Apple ever retires that ID.
struct StorePlace: Identifiable, Equatable, Sendable {
    var id: String { placeID ?? "\(latitude),\(longitude)" }
    var name: String
    var placeID: String?
    var latitude: Double
    var longitude: Double
    var address: String?
}
