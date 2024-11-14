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
    
    init(name: String, shape: String, length: String, gauge: String, location: String, price: String, strength: String, rating: Int, notes: String, date: Date,  photo: Data? = nil) {
        self.name = name
        self.type = shape
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
