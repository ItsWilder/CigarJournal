//
//  SampleData.swift
//  Cigar Journal
//
//  Created by David Wilder on 7/1/25.
//

import SwiftUI
import SwiftData

/// An array of sample data cigars for use in all previews
struct SampleData {
    static let cigars: [CigarTemplate] = [
        CigarTemplate(name: "Avo XO Notturno (Tubo)",
                      shape: "Petite Corona",
                      length: "5",
                      gauge: "42",
                      location: "JR Cigars",
                      price: "10.90",
                      strength: "Medium",
                      rating: 4,
                      notes: "Surprisingly polished despite its rough appearance. The smoke is warm and nutty, with subtle layers of honeyed tea, orange peel, and just a touch of caramel sweetness. Definitely more refined than expected—smooth and easygoing. Great choice for a relaxing evening.",
                      date: Calendar.current.date(byAdding: .day, value: -1, to: Date.now)!,
                      photo: nil),
        CigarTemplate(name: "Quesada 50th Anniversary",
                      shape: "Robusto",
                      length: "5",
                      gauge: "50",
                      location: "Famous Smoke Shop",
                      price: "12.50",
                      strength: "Medium",
                      rating: 3,
                      notes: "Rich and complex with notes of espresso, cedar, and dark chocolate. The draw is excellent and the burn is even throughout. A celebratory cigar that lives up to its name.",
                      date: Calendar.current.date(byAdding: .day, value: -2, to: Date.now)!,
                      photo: nil),
        CigarTemplate(name: "Casa Magna Colorado",
                      shape: "Toro",
                      length: "6",
                      gauge: "52",
                      location: "Cigar International",
                      price: "11.00",
                      strength: "Strong",
                      rating: 1,
                      notes: "Bold and spicy with a deep earthiness. Flavors of pepper, leather, and a hint of sweetness make this a satisfying smoke for seasoned aficionados.",
                      date: Calendar.current.date(byAdding: .day, value: -3, to: Date.now)!,
                      photo: nil),
        CigarTemplate(name: "A. Flores 1975 Gran Reserva",
                      shape: "Churchill",
                      length: "7",
                      gauge: "48",
                      location: "Local Humidor",
                      price: "9.75",
                      strength: "Medium",
                      rating: 4,
                      notes: "Smooth and creamy with notes of cedar, nuts, and a touch of cocoa. A well-balanced cigar that is great for any time of day.",
                      date: Calendar.current.date(byAdding: .day, value: -4, to: Date.now)!,
                      photo: nil),
        CigarTemplate(name: "Herrera Esteli Brazilian Maduro",
                      shape: "Robusto",
                      length: "5",
                      gauge: "50",
                      location: "Online Retailer",
                      price: "13.00",
                      strength: "Medium",
                      rating: 2,
                      notes: "Rich and flavorful with a dark chocolate sweetness balanced by spicy pepper and coffee notes. A complex smoke with a long finish.",
                      date: Calendar.current.date(byAdding: .day, value: -5, to: Date.now)!,
                      photo: nil),
        CigarTemplate(name: "Rocky Patel A.L.R.",
                      shape: "Toro",
                      length: "6",
                      gauge: "54",
                      location: "Cigar Shop",
                      price: "14.25",
                      strength: "Mild",
                      rating: 5,
                      notes: "Powerful and robust with flavors of espresso, leather, and black pepper. A bold choice for those who enjoy a full-bodied cigar.",
                      date: Calendar.current.date(byAdding: .day, value: -6, to: Date.now)!,
                      photo: nil)
    ]
}

extension SampleData {
    static let cigar = cigars[0]
}


