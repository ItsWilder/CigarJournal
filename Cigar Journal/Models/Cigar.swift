// CigarTemplate

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
