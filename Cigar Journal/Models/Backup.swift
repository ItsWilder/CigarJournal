//
//  Backup.swift
//  Cigar Journal
//
//  Created by David Wilder on 5/3/25.
//

import Foundation

struct CigarBackup: Codable {
    var name: String
    var type: String?
    var notes: String?
    var rating: Int
    var date: Date
    var photoData: Data?
    var length: String?
    var gauge: String?
    var strength: String?
    var location: String?
    var price: Double?

    init(name: String, type: String?, notes: String?, rating: Int, date: Date, photoData: Data?, length: String?, gauge: String?, strength: String?, location: String?, price: Double?) {
        self.name = name
        self.type = type
        self.notes = notes
        self.rating = rating
        self.date = date
        self.photoData = photoData
        self.length = length
        self.gauge = gauge
        self.strength = strength
        self.location = location
        self.price = price
    }
}
