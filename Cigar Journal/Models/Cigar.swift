// CigarTemplate

import Foundation
import SwiftData

@Model
class CigarTemplate {
    var name: String
    var type: String
    var length: String
    var gauge: String
    var location: String
    var price: String
    var strength: String
    var rating: Int
    var notes: String
    var date: Date
    var photo: Data?
    
    init(name: String, type: String, length: String, gauge: String, location: String, price: String, strength: String, rating: Int, notes: String, date: Date,  photo: Data? = nil) {
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

extension CigarTemplate {
    
    static let cigarTypeOptions = ["Rothschild", "Robusto", "Petite Corona", "Corona", "Toro", "Lonsdale", "Churchill", "Lancero", "Double Corona", "Presidente", "Grande"]
    
    static let strengthOptions = ["Mild", "Medium", "Strong"]
}
